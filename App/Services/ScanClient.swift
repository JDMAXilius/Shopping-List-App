import Foundation

// The app holds no AI credentials (ARCHITECTURE §7). This is the only caller of the
// scan-receipt Edge Function, which verifies the caller's JWT and owns the Anthropic key.
protocol ScanBackend: Sendable {
    func scan(image: Data, mediaType: ScanMediaType, shopHint: String?) async -> ScanOutcome
}

// The four types the function accepts; anything else comes back 400 invalid_body.
enum ScanMediaType: String, Sendable {
    case jpeg = "image/jpeg"
    case png = "image/png"
    case webp = "image/webp"
    case gif = "image/gif"
}

enum ScanConfidence: String, Sendable, Decodable {
    case sure
    case notSure = "not_sure"
    case noMatch = "no_match"
}

struct ScanLine: Sendable, Equatable, Decodable {
    let rawText: String
    let amountMinor: Int
    let quantity: Double
    let confidence: ScanConfidence
    let matchHint: String?

    private enum CodingKeys: String, CodingKey {
        case rawText = "raw_text"
        case amountMinor = "amount_minor"
        case quantity
        case confidence
        case matchHint = "match_hint"
    }
}

struct ScanReceipt: Sendable, Equatable, Decodable {
    let lines: [ScanLine]
    let shopName: String?
    let totalMinor: Int?
    let currency: String
    let purchasedAt: Date?
    let isPlus: Bool
    let scansUsed: Int

    private enum CodingKeys: String, CodingKey {
        case lines
        case shopName = "shop_name"
        case totalMinor = "total_minor"
        case currency
        case purchasedAt = "purchased_at"
        case isPlus = "is_plus"
        case scansUsed = "scans_used"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lines = try container.decode([ScanLine].self, forKey: .lines)
        shopName = try container.decodeIfPresent(String.self, forKey: .shopName)
        totalMinor = try container.decodeIfPresent(Int.self, forKey: .totalMinor)
        currency = try container.decode(String.self, forKey: .currency)
        isPlus = try container.decode(Bool.self, forKey: .isPlus)
        scansUsed = try container.decode(Int.self, forKey: .scansUsed)
        // The date is whatever the model read off the paper: a string we cannot parse becomes
        // nil, never a guessed date.
        purchasedAt = try container.decodeIfPresent(String.self, forKey: .purchasedAt)
            .flatMap(ScanReceipt.printedDate(from:))
    }

    private static func printedDate(from text: String) -> Date? {
        let shapes: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate],
        ]
        let formatter = ISO8601DateFormatter()
        for options in shapes {
            formatter.formatOptions = options
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

// One case per status the function documents; nothing collapses two different truths into one.
enum ScanOutcome: Sendable, Equatable {
    case scanned(ScanReceipt)
    // 402: the paywall trigger. scans_used is nil only if the function omitted it.
    case quotaExhausted(scansUsed: Int?)
    case unauthenticated                     // 401 — no session, or the JWT was rejected
    case ownerAccountRequired                // 403 — guest/anonymous session, or not an owner
    case rejected                            // 400 / 405 — our request was malformed: our bug
    case imageTooLarge(maxBytes: Int)        // 413, or refused here before the upload
    case rateLimited                         // 429 — 10 scans/hour
    case unreadableImage                     // 422 — the model could not parse this photo
    case upstreamFailure                     // 502, or a 200 body we cannot decode
    // No answer at all: offline, timeout, cancelled. The user did nothing wrong, and whether the
    // server consumed a scan before the connection died is unknown from here.
    case notReachable
    case unexpected(status: Int)
}

struct ScanClient: ScanBackend {
    // MAX_IMAGE_BYTES in supabase/functions/scan-receipt/index.ts, measured the same way it is
    // there — against the base64 length — so an oversized photo is refused before it uploads.
    static let maxImageBytes = 8 * 1024 * 1024

    private let endpoint: URL
    private let apiKey: String
    private let session: URLSession
    private let accessToken: @Sendable () async -> String?

    // apiKey is the Supabase anon (publishable) key the gateway expects alongside the user JWT.
    // It is injected, never literal here, and it is not an AI credential.
    init(endpoint: URL, apiKey: String, session: URLSession = .shared,
         accessToken: @escaping @Sendable () async -> String?) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
        self.accessToken = accessToken
    }

    func scan(image: Data, mediaType: ScanMediaType, shopHint: String?) async -> ScanOutcome {
        let base64 = image.base64EncodedString()
        guard base64.count * 3 / 4 <= Self.maxImageBytes else {
            return .imageTooLarge(maxBytes: Self.maxImageBytes)
        }
        guard let token = await accessToken(), !token.isEmpty else { return .unauthenticated }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        let body = RequestBody(imageBase64: base64, mediaType: mediaType.rawValue, shopHint: shopHint)
        guard let encoded = try? JSONEncoder().encode(body) else { return .rejected }
        request.httpBody = encoded

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .upstreamFailure }
            return outcome(status: http.statusCode, data: data)
        } catch {
            return .notReachable
        }
    }

    private func outcome(status: Int, data: Data) -> ScanOutcome {
        switch status {
        case 200:
            guard let receipt = try? JSONDecoder().decode(ScanReceipt.self, from: data) else {
                return .upstreamFailure
            }
            return .scanned(receipt)
        case 400, 405: return .rejected
        case 401: return .unauthenticated
        case 402: return .quotaExhausted(scansUsed: Self.errorBody(data)?.scansUsed)
        case 403: return .ownerAccountRequired
        case 413: return .imageTooLarge(maxBytes: Self.errorBody(data)?.maxBytes ?? Self.maxImageBytes)
        case 422: return .unreadableImage
        case 429: return .rateLimited
        case 502: return .upstreamFailure
        default: return .unexpected(status: status)
        }
    }

    private static func errorBody(_ data: Data) -> ErrorBody? {
        try? JSONDecoder().decode(ErrorBody.self, from: data)
    }

    private struct RequestBody: Encodable {
        let imageBase64: String
        let mediaType: String
        let shopHint: String?

        private enum CodingKeys: String, CodingKey {
            case imageBase64 = "image_base64"
            case mediaType = "media_type"
            case shopHint = "shop_hint"
        }
    }

    private struct ErrorBody: Decodable {
        let error: String
        let scansUsed: Int?
        let maxBytes: Int?

        private enum CodingKeys: String, CodingKey {
            case error
            case scansUsed = "scans_used"
            case maxBytes = "max_bytes"
        }
    }
}
