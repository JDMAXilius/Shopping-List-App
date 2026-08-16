import Foundation
import XCTest

@testable import Bagged

final class ScanClientTests: XCTestCase {
    private let endpoint = URL(string: "https://example.supabase.co/functions/v1/scan-receipt")!

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    private func makeClient(token: String? = "jwt-abc") -> ScanClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return ScanClient(endpoint: endpoint, apiKey: "anon-key",
                          session: URLSession(configuration: configuration),
                          accessToken: { token })
    }

    private func stub(_ status: Int, _ json: String) {
        StubURLProtocol.stub = StubURLProtocol.Stub(status: status, body: Data(json.utf8))
    }

    private let successBody = """
        {"lines":[{"raw_text":"TJ ORG BABY SPNC","amount_minor":299,"quantity":1,
        "confidence":"not_sure","match_hint":"baby spinach"},
        {"raw_text":"MILK 1L","amount_minor":189,"quantity":2,"confidence":"sure"}],
        "shop_name":"Trader Joe's","total_minor":488,"currency":"USD",
        "purchased_at":"2026-08-14T18:03:00Z","is_plus":false,"scans_used":1}
        """

    // MARK: - The request we put on the wire

    func testRequestMirrorsTheFunctionsInputContract() async throws {
        stub(200, successBody)
        _ = await makeClient().scan(image: Data([0xFF, 0xD8, 0xFF]), mediaType: .jpeg, shopHint: "Trader Joe's")

        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.value(forHTTPHeaderField: "authorization"), "Bearer jwt-abc")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

        let body = try XCTUnwrap(StubURLProtocol.bodies.first)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["image_base64"] as? String, Data([0xFF, 0xD8, 0xFF]).base64EncodedString())
        XCTAssertEqual(json["media_type"] as? String, "image/jpeg")
        XCTAssertEqual(json["shop_hint"] as? String, "Trader Joe's")
    }

    func testALongShopNameIsCutToTheLimitInsteadOfCostingTheReceipt() async throws {
        stub(200, successBody)
        let name = "Whole Foods Market — 1234 Something Blvd, Suite 200, San Francisco CA 94110, "
            + "by the parking structure"
        XCTAssertGreaterThan(name.utf16.count, ScanClient.maxShopHintUnits)
        _ = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: name)

        let body = try XCTUnwrap(StubURLProtocol.bodies.first)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let sent = try XCTUnwrap(json["shop_hint"] as? String)
        // The function 400s on shop_hint.length > 100, and a 400 fails the whole scan — every
        // scan, forever, for a user whose shop is named like this.
        XCTAssertLessThanOrEqual(sent.utf16.count, ScanClient.maxShopHintUnits)
        XCTAssertTrue(name.hasPrefix(sent), "what is sent is the start of the real name")

        XCTAssertEqual(ScanClient.fittedHint("Trader Joe's"), "Trader Joe's", "a short name is untouched")
        XCTAssertNil(ScanClient.fittedHint("   "), "and a blank hint is no hint")
        let emoji = String(repeating: "🛒", count: 80)
        XCTAssertLessThanOrEqual(try XCTUnwrap(ScanClient.fittedHint(emoji)).utf16.count,
                                 ScanClient.maxShopHintUnits,
                                 "counted the way JavaScript counts it")
    }

    func testNoShopHintOmitsTheKey() async throws {
        stub(200, successBody)
        _ = await makeClient().scan(image: Data([0x01]), mediaType: .png, shopHint: nil)

        let body = try XCTUnwrap(StubURLProtocol.bodies.first)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["shop_hint"])
        XCTAssertEqual(json["media_type"] as? String, "image/png")
    }

    // MARK: - The 200 body

    func testSuccessDecodesEveryDocumentedField() async throws {
        stub(200, successBody)
        let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)

        guard case .scanned(let receipt) = outcome else { return XCTFail("expected .scanned, got \(outcome)") }
        XCTAssertEqual(receipt.lines.count, 2)
        XCTAssertEqual(receipt.lines[0].rawText, "TJ ORG BABY SPNC")
        XCTAssertEqual(receipt.lines[0].amountMinor, 299)
        XCTAssertEqual(receipt.lines[0].quantity, 1)
        XCTAssertEqual(receipt.lines[0].confidence, .notSure)
        XCTAssertEqual(receipt.lines[0].matchHint, "baby spinach")
        XCTAssertEqual(receipt.lines[1].confidence, .sure)
        XCTAssertNil(receipt.lines[1].matchHint)
        XCTAssertEqual(receipt.shopName, "Trader Joe's")
        XCTAssertEqual(receipt.totalMinor, 488)
        XCTAssertEqual(receipt.currency, "USD")
        XCTAssertEqual(receipt.isPlus, false)
        XCTAssertEqual(receipt.scansUsed, 1)
        XCTAssertEqual(receipt.purchasedAt, ISO8601DateFormatter().date(from: "2026-08-14T18:03:00Z"))
    }

    func testNullOptionalsDecodeAsNilNotAsDefaults() async throws {
        stub(200, """
            {"lines":[],"shop_name":null,"total_minor":null,"currency":"BRL",
            "purchased_at":null,"is_plus":true,"scans_used":3}
            """)
        let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)

        guard case .scanned(let receipt) = outcome else { return XCTFail("expected .scanned, got \(outcome)") }
        XCTAssertTrue(receipt.lines.isEmpty)
        XCTAssertNil(receipt.shopName)
        XCTAssertNil(receipt.totalMinor)
        XCTAssertNil(receipt.purchasedAt)
        XCTAssertTrue(receipt.isPlus)
    }

    func testADateOnlyStringParsesAndAnUnreadableOneBecomesNil() async throws {
        stub(200, """
            {"lines":[],"currency":"USD","purchased_at":"2026-08-14","is_plus":false,"scans_used":0}
            """)
        guard case .scanned(let dated) = await makeClient()
            .scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil) else { return XCTFail("expected .scanned") }
        XCTAssertNotNil(dated.purchasedAt)

        StubURLProtocol.reset()
        stub(200, """
            {"lines":[],"currency":"USD","purchased_at":"08/14/26","is_plus":false,"scans_used":0}
            """)
        guard case .scanned(let guessy) = await makeClient()
            .scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil) else { return XCTFail("expected .scanned") }
        XCTAssertNil(guessy.purchasedAt)
    }

    // A 200 whose lines don't match the schema is the server misbehaving, not a bad photo — and
    // no line is silently dropped. The scan ran, so we do not claim the quota went untouched.
    func testUndecodableSuccessBodyIsUpstreamFailureClaimingNothingAboutTheQuota() async throws {
        stub(200, #"{"lines":[{"raw_text":"MILK"}],"currency":"USD","is_plus":false,"scans_used":1}"#)
        let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
        XCTAssertEqual(outcome, .upstreamFailure(freeScan: .unreported))
    }

    // MARK: - Every documented status, one distinct outcome

    func testQuotaExhaustedCarriesScansUsedForThePaywall() async throws {
        stub(402, #"{"error":"quota_exhausted","scans_used":3}"#)
        let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
        XCTAssertEqual(outcome, .quotaExhausted(scansUsed: 3))
    }

    func testQuotaExhaustedWithoutACountReportsNilRatherThanGuessing() async throws {
        stub(402, #"{"error":"quota_exhausted"}"#)
        let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
        XCTAssertEqual(outcome, .quotaExhausted(scansUsed: nil))
    }

    func testEachStatusMapsToItsOwnOutcome() async throws {
        let cases: [(Int, String, ScanOutcome)] = [
            (400, #"{"error":"invalid_body"}"#, .rejected),
            (401, #"{"error":"unauthenticated"}"#, .unauthenticated),
            (403, #"{"error":"sign_in_required"}"#, .signInRequired),
            (403, #"{"error":"kitchen_required"}"#, .kitchenRequired),
            (405, #"{"error":"method_not_allowed"}"#, .rejected),
            (413, #"{"error":"image_too_large","max_bytes":8388608}"#, .imageTooLarge(maxBytes: 8_388_608)),
            (422, #"{"error":"unparseable_image","free_scan_charged":false}"#,
             .unreadableImage(freeScan: .refunded)),
            (429, #"{"error":"rate_limited"}"#, .rateLimited),
            (502, #"{"error":"upstream","free_scan_charged":false}"#,
             .upstreamFailure(freeScan: .refunded)),
            (418, "", .unexpected(status: 418)),
        ]
        for (status, body, expected) in cases {
            StubURLProtocol.reset()
            stub(status, body)
            let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
            XCTAssertEqual(outcome, expected, "status \(status) \(body)")
        }
    }

    // MARK: - The two 403s are two different missing steps

    // One string for both used to send a signed-in owner who has no kitchen to a sign-in screen
    // she could do nothing with. The strings are the routing, so they are pinned literally.
    func testTheTwo403sRouteToDifferentScreens() async throws {
        stub(403, #"{"error":"sign_in_required"}"#)
        let anonymous = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
        XCTAssertEqual(anonymous, .signInRequired)

        StubURLProtocol.reset()
        stub(403, #"{"error":"kitchen_required"}"#)
        let ownerless = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
        XCTAssertEqual(ownerless, .kitchenRequired)
        XCTAssertNotEqual(anonymous, ownerless)
    }

    func testA403NamingNeitherStepIsNotRoutedToAGuessedOne() async throws {
        for body in [#"{"error":"owner_account_required"}"#, ""] {
            StubURLProtocol.reset()
            stub(403, body)
            let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
            XCTAssertEqual(outcome, .unexpected(status: 403), "body \(body)")
        }
    }

    // MARK: - What the failure cost

    func testFreeScanChargedIsCarriedOnBothOutcomesThatCanReportIt() async throws {
        let cases: [(Int, String, FreeScanEffect)] = [
            (422, #"{"error":"unparseable_image","free_scan_charged":true}"#, .charged),
            (422, #"{"error":"unparseable_image","free_scan_charged":false}"#, .refunded),
            (502, #"{"error":"upstream","free_scan_charged":true}"#, .charged),
            (502, #"{"error":"upstream","free_scan_charged":false}"#, .refunded),
        ]
        for (status, body, expected) in cases {
            StubURLProtocol.reset()
            stub(status, body)
            let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
            let actual: FreeScanEffect?
            switch outcome {
            case .unreadableImage(let effect), .upstreamFailure(let effect): actual = effect
            default: actual = nil
            }
            XCTAssertEqual(actual, expected, "status \(status) \(body)")
        }
    }

    // An early 502 never reached the quota; a refunded one did and gave it back. Both cost the
    // user nothing, and the app still must not say the same sentence about them.
    func testAbsentFreeScanChargedIsNotTheSameAnswerAsFalse() async throws {
        stub(502, #"{"error":"upstream"}"#)
        let early = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
        XCTAssertEqual(early, .upstreamFailure(freeScan: .notReached))
        XCTAssertNotEqual(early, .upstreamFailure(freeScan: .refunded))
    }

    // A gateway page or an empty body is not our envelope, so its silence is not the contract's
    // silence: it says nothing about the quota rather than "never touched".
    func testABodyThatIsNotOursReportsNothingAboutTheQuota() async throws {
        for body in ["", "<html>502 Bad Gateway</html>", "{}"] {
            StubURLProtocol.reset()
            stub(502, body)
            let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
            XCTAssertEqual(outcome, .upstreamFailure(freeScan: .unreported), "body \(body)")

            StubURLProtocol.reset()
            stub(422, body)
            let unreadable = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
            XCTAssertEqual(unreadable, .unreadableImage(freeScan: .unreported), "body \(body)")
        }
    }

    // Every 422 is the same instruction to a capture screen — retake it — whatever the body says
    // or fails to say, so the case alone is actionable and no payload is assumed to be there.
    func testAny422ReadsAsAnImageWeCannotUseWithoutInspectingTheBody() async throws {
        let bodies = [#"{"error":"unparseable_image","free_scan_charged":false}"#,
                      #"{"error":"empty_receipt","free_scan_charged":false}"#, "{}", ""]
        for body in bodies {
            StubURLProtocol.reset()
            stub(422, body)
            let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
            guard case .unreadableImage = outcome else {
                return XCTFail("expected .unreadableImage for \(body), got \(outcome)")
            }
        }
    }

    // MARK: - Refusals that never leave the phone

    func testOversizedImageIsRefusedBeforeUpload() async throws {
        stub(200, successBody)
        let image = Data(repeating: 0x01, count: ScanClient.maxImageBytes + 1)
        let outcome = await makeClient().scan(image: image, mediaType: .jpeg, shopHint: nil)

        XCTAssertEqual(outcome, .imageTooLarge(maxBytes: ScanClient.maxImageBytes))
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testNoSessionIsUnauthenticatedWithoutARequest() async throws {
        stub(200, successBody)
        let outcome = await makeClient(token: nil).scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)

        XCTAssertEqual(outcome, .unauthenticated)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    // A connection that dies after the request lands leaves the scan genuinely spent with no way
    // to know it here, so this outcome carries no free-scan claim at all — the app re-reads it.
    func testTransportFailureIsNotTheUsersFaultAndClaimsNothingAboutTheScan() async throws {
        StubURLProtocol.failure = URLError(.notConnectedToInternet)
        let outcome = await makeClient().scan(image: Data([0x01]), mediaType: .jpeg, shopHint: nil)
        XCTAssertEqual(outcome, .notReachable)
    }

    // MARK: - The fake

    func testFakeRecordsCallsAndDrainsItsScript() async throws {
        let fake = FakeScanBackend(outcomes: [.unreadableImage(freeScan: .refunded)])
        let first = await fake.scan(image: Data([0x01]), mediaType: .png, shopHint: "Aldi")
        let second = await fake.scan(image: Data([0x02]), mediaType: .jpeg, shopHint: nil)

        XCTAssertEqual(first, .unreadableImage(freeScan: .refunded))
        XCTAssertEqual(second, .notReachable)
        let calls = await fake.calls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].shopHint, "Aldi")
        XCTAssertEqual(calls[1].mediaType, .jpeg)
    }
}

final class StubURLProtocol: URLProtocol {
    struct Stub {
        let status: Int
        let body: Data
    }

    // Test-only globals: URLProtocol is instantiated by URLSession, so there is nowhere else to
    // hang the script. One test at a time touches them.
    nonisolated(unsafe) static var stub: Stub?
    nonisolated(unsafe) static var failure: Error?
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var bodies: [Data] = []

    static func reset() {
        stub = nil
        failure = nil
        requests = []
        bodies = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        Self.bodies.append(Self.body(of: request))
        if let failure = Self.failure {
            client?.urlProtocol(self, didFailWithError: failure)
            return
        }
        let stub = Self.stub ?? Stub(status: 500, body: Data())
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: stub.status,
                                             httpVersion: "HTTP/1.1", headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    // URLSession hands the body over as a stream, not as httpBody.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(contentsOf: buffer[0 ..< read])
        }
        return data
    }
}
