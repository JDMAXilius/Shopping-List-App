import Foundation
import XCTest

@testable import Bagged

@MainActor
final class ProductLookupTests: XCTestCase {
    private let code = "3017620422003"

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        LateURLProtocol.reset()
    }

    private func makeLookup(_ transport: AnyClass = StubURLProtocol.self) -> ProductLookup {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [transport]
        return ProductLookup(session: URLSession(configuration: configuration))
    }

    private func stub(_ status: Int, _ json: String) {
        StubURLProtocol.stub = StubURLProtocol.Stub(status: status, body: Data(json.utf8))
    }

    private func found(_ name: String) -> String {
        #"{"code":"\#(code)","product":{"product_name":"\#(name)"},"status":1,"#
            + #""status_verbose":"product found"}"#
    }

    private func makeDefaults(_ name: String = UUID().uuidString) throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(name)"))
    }

    // MARK: - Being a good guest of someone else's free service

    func testTheRequestSaysWhoWeAreAndAsksForTheOneFieldWeUse() async throws {
        stub(200, found("Nutella"))
        _ = await makeLookup().name(for: code)

        let request = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "one request per unknown code, no retry")
        XCTAssertEqual(request.httpMethod, "GET")
        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(url.host(), "world.openfoodfacts.org")
        XCTAssertTrue(url.path().contains(code), "the code is the key: \(url.path())")
        XCTAssertEqual(url.query(), "fields=product_name")

        // Open Food Facts blocks generic agents, and asks reusers to identify themselves.
        let agent = try XCTUnwrap(request.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertTrue(agent.hasPrefix("Bagged/"), agent)
        XCTAssertTrue(agent.contains("https://bagged.app"), agent)
        XCTAssertFalse(request.httpShouldHandleCookies)
        XCTAssertEqual(ProductLookup.timeout, 2)
        XCTAssertEqual(request.timeoutInterval, ProductLookup.timeout)
    }

    // MARK: - Only a barcode, and only ever a barcode

    // Vision reads Code 128 as well as the EAN family, and a Code 128 payload is whatever the
    // printer put in it — a shelf label, a parcel number, a URL. None of it is a product, and
    // none of it may be handed to a third party.
    func testAnythingThatIsNotAProductCodeNeverLeavesThePhone() async {
        let payloads = ["", "1234567", "123456789012345", "ABC-12345678", "0071234567890 ",
                        "https://example.com/t?id=12345678", "٠١٢٣٤٥٦٧٨٩", "12 345 678"]
        for payload in payloads {
            StubURLProtocol.reset()
            stub(200, found("Nutella"))
            let name = await makeLookup().name(for: payload)

            XCTAssertNil(name, payload)
            XCTAssertTrue(StubURLProtocol.requests.isEmpty, "\(payload) was sent somewhere")
            XCTAssertNil(ProductLookup.url(for: payload), payload)
            XCTAssertFalse(ProductLookup.isProductCode(payload), payload)
        }
        for accepted in ["12345670", "071234567890", "3017620422003", "10071234567890"] {
            XCTAssertTrue(ProductLookup.isProductCode(accepted), accepted)
        }
    }

    // MARK: - A name arrives, or nothing does

    func testAKnownCodeSuggestsTheNameItCameBackWith() async {
        stub(200, found("Semi-skimmed milk"))
        let name = await makeLookup().name(for: code)
        XCTAssertEqual(name, "Semi-skimmed milk")
    }

    // The lookup is an enhancement and never a dependency: every one of these is the same
    // silence, and the screen it feeds is the screen that shipped without it.
    func testEveryFailureIsTheSameSilence() async {
        let answers: [(Int, String)] = [
            (404, #"{"status":0,"status_verbose":"product not found"}"#),
            (200, #"{"status":0,"product":{"product_name":"Nutella"}}"#),
            (200, #"{"status":1,"product":{"product_name":null}}"#),
            (200, #"{"status":1,"product":{"product_name":"   "}}"#),
            (200, #"{"status":1,"product":{}}"#),
            (200, #"{"status":1}"#),
            (200, #"{"status":1,"product":[]}"#),
            (200, #"{"status":1,"product":{"product_name":42}}"#),
            (200, "[]"),
            (200, "<html>hello</html>"),
            (200, ""),
            (429, #"{"status":0}"#),
            (500, ""),
        ]
        for (status, body) in answers {
            StubURLProtocol.reset()
            stub(status, body)
            let name = await makeLookup().name(for: code)
            XCTAssertNil(name, "status \(status) body \(body)")
        }
    }

    func testOfflineAndTimedOutAreSilentToo() async {
        for failure in [URLError(.notConnectedToInternet), URLError(.timedOut),
                        URLError(.cancelled)] {
            StubURLProtocol.reset()
            StubURLProtocol.failure = failure
            let name = await makeLookup().name(for: code)
            XCTAssertNil(name, "\(failure)")
        }
    }

    // MARK: - A returned name is untrusted third-party text

    func testAHostileNameIsRefusedRatherThanShown() {
        // Format characters can reorder a line on screen; control characters can break it apart.
        XCTAssertEqual(ProductLookup.suggestedName("Ni\u{202E}vea\u{0007} milk", code: code),
                       "Nivea milk")
        XCTAssertEqual(ProductLookup.suggestedName("Oat\ndrink\t 1L", code: code), "Oat drink 1L")
        XCTAssertEqual(ProductLookup.suggestedName("  Butter  ", code: code), "Butter")
        // It arrives in an arbitrary language, and that is fine — it is still just a name.
        XCTAssertEqual(ProductLookup.suggestedName("Leite meio gordo", code: code),
                       "Leite meio gordo")

        XCTAssertNil(ProductLookup.suggestedName(nil, code: code))
        XCTAssertNil(ProductLookup.suggestedName("", code: code))
        XCTAssertNil(ProductLookup.suggestedName("\u{200B}\u{202A}", code: code))
        // A cut name is a name nobody wrote, so an essay is refused instead of truncated.
        XCTAssertNil(ProductLookup.suggestedName(String(repeating: "a", count: 5_000), code: code))
        XCTAssertNil(ProductLookup.suggestedName(String(repeating: "milk ", count: 40), code: code))
        XCTAssertNotNil(ProductLookup.suggestedName(
            String(repeating: "a", count: ProductLookup.maxNameCharacters), code: code))
        XCTAssertNil(ProductLookup.suggestedName(
            String(repeating: "a", count: ProductLookup.maxNameCharacters + 1), code: code))
        // The digits of a code are not a product name — the rule this screen already lives by.
        XCTAssertNil(ProductLookup.suggestedName(code, code: code))
    }

    func testAHugeNameOnTheWireNeverReachesTheScreen() async {
        stub(200, #"{"status":1,"product":{"product_name":"\#(String(repeating: "x", count: 20_000))"}}"#)
        let name = await makeLookup().name(for: code)
        XCTAssertNil(name)
    }

    // MARK: - The switch, and what it switches off

    func testTheSettingIsOneKeyThatDefaultsOn() throws {
        let defaults = try makeDefaults()
        XCTAssertTrue(ProductLookup.isEnabled(defaults), "absent means on")
        defaults.set(false, forKey: ProductLookup.settingKey)
        XCTAssertFalse(ProductLookup.isEnabled(defaults))
        defaults.set(true, forKey: ProductLookup.settingKey)
        XCTAssertTrue(ProductLookup.isEnabled(defaults))
    }

    func testSwitchedOffNoCodeLeavesThePhoneAtAll() async throws {
        let defaults = try makeDefaults()
        defaults.set(false, forKey: ProductLookup.settingKey)
        stub(200, found("Nutella"))
        let suggestion = ProductSuggestion(lookup: makeLookup(), defaults: defaults)

        await suggestion.ask(about: code)

        XCTAssertFalse(suggestion.isEnabled)
        XCTAssertNil(suggestion.name)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    // MARK: - The suggestion, as the screen holds it

    func testAFailedLookupLeavesTheScreenExactlyAsItIsToday() async throws {
        StubURLProtocol.failure = URLError(.notConnectedToInternet)
        let suggestion = ProductSuggestion(lookup: makeLookup(), defaults: try makeDefaults())

        await suggestion.ask(about: code)

        // Nothing extra is drawn, so what the user sees is the screen that shipped without this.
        XCTAssertNil(suggestion.name)
        XCTAssertEqual(suggestion.code, code)
    }

    func testACodeIsAskedAboutOnceAndTheMemoryDiesWithTheFlow() async throws {
        let suite = UUID().uuidString
        let defaults = try makeDefaults(suite)
        stub(200, found("Nutella"))
        let suggestion = ProductSuggestion(lookup: makeLookup(), defaults: defaults)

        await suggestion.ask(about: code)
        await suggestion.ask(about: code)

        XCTAssertEqual(suggestion.name, "Nutella")
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "the second scan asks nobody")

        // A new flow starts with nothing, because nothing was ever written down: no file, no
        // table, no defaults key. That is the whole ODbL firewall.
        let next = ProductSuggestion(lookup: makeLookup(), defaults: defaults)
        await next.ask(about: code)
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        XCTAssertTrue(defaults.persistentDomain(forName: "bagged.tests.\(suite)")?.isEmpty ?? true,
                      "a looked-up name is written to nothing, not even a defaults key")
    }

    func testAnAnswerToACodeTheUserHasLeftIsDiscarded() async throws {
        LateURLProtocol.body = Data(found("Nutella").utf8)
        let suggestion = ProductSuggestion(lookup: makeLookup(LateURLProtocol.self),
                                           defaults: try makeDefaults())

        let inFlight = Task { await suggestion.ask(about: code) }
        while suggestion.code == nil { await Task.yield() }
        suggestion.clear()
        await inFlight.value

        // One packet's name under another packet's code would teach the kitchen a lie.
        XCTAssertNil(suggestion.name)
        XCTAssertNil(suggestion.code)
    }
}

/// The one thing `StubURLProtocol` cannot do: answer late enough that a test can move the user
/// on while the request is still in flight. Blocking here delays only this request's own thread.
final class LateURLProtocol: URLProtocol {
    nonisolated(unsafe) static var body = Data()

    static func reset() { body = Data() }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Thread.sleep(forTimeInterval: 0.2)
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                             headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
