import Core
import Foundation

/// Where this build's Supabase project lives. The anon (publishable) key is the only credential
/// the app ever holds — it is not an authorization decision, RLS is (ARCHITECTURE §7).
public struct SupabaseConfig: Sendable {
    public let projectURL: URL
    public let anonKey: String

    public init(projectURL: URL, anonKey: String) {
        self.projectURL = projectURL
        self.anonKey = anonKey
    }

    public var restURL: URL { projectURL.appendingPathComponent("rest/v1") }
    public var authURL: URL { projectURL.appendingPathComponent("auth/v1") }
    public var functionsURL: URL { projectURL.appendingPathComponent("functions/v1") }
}

/// One request, one answer, both plain values — so the transport can be driven by a fake server
/// in tests and so nothing non-Sendable (URLResponse) crosses an actor boundary.
public struct SupabaseRequest: Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Foundation.Data?

    public init(method: String, url: URL, headers: [String: String],
                body: Foundation.Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct SupabaseResponse: Sendable {
    public let status: Int
    public let body: Foundation.Data

    public init(status: Int, body: Foundation.Data) {
        self.status = status
        self.body = body
    }
}

public protocol SupabaseHTTP: Sendable {
    func send(_ request: SupabaseRequest) async throws -> SupabaseResponse
}

/// Distinct because the caller's answer differs: a retry fixes `unreachable` and `server`,
/// nothing fixes `rejected` — RLS refused the write and it will refuse the next one too.
public enum SupabaseTransportError: Error, Sendable, Equatable {
    case unauthenticated
    case rejected(status: Int, code: String?)
    case server(status: Int)
    case unreachable
    case malformedResponse
}

public struct URLSessionHTTP: SupabaseHTTP {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 20) {
        self.session = session
        self.timeout = timeout
    }

    public func send(_ request: SupabaseRequest) async throws -> SupabaseResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = timeout
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw SupabaseTransportError.malformedResponse
            }
            return SupabaseResponse(status: http.statusCode, body: data)
        } catch let error as SupabaseTransportError {
            throw error
        } catch {
            // Offline, timeout, cancelled: the engine's backoff owns what happens next.
            throw SupabaseTransportError.unreachable
        }
    }
}

/// The real transport (ARCHITECTURE §8: nothing above this layer knows Supabase exists).
///
/// Two calls, both of them the ones `supabase/migrations` documents:
/// - push → `rpc/push_ops`, which is `ON CONFLICT (id) DO NOTHING`. A re-delivered batch is
///   therefore a 200 with a smaller count, NOT a 409 — re-delivery is the normal case, so
///   the count is not read at all. A bare `POST /rest/v1/op` would 409 the whole batch.
/// - pull → `op?kitchen_id=eq.&seq=gt.&order=seq.asc`, the cursor read `op_assign_seq` was
///   written for. The cursor only ever advances to the seq of a row this answer actually
///   carried, so a page boundary — or another kitchen drawing from the same sequence —
///   cannot skip an op.
public struct SupabaseTransport: SyncTransport {
    /// One RPC per batch; a partial failure re-sends everything, which push_ops absorbs.
    static let pushBatchSize = 200
    static let pageSize = 500
    /// A backlog longer than this drains over several kicks rather than one huge response.
    static let maxPagesPerPull = 20

    private let config: SupabaseConfig
    private let http: any SupabaseHTTP
    private let accessToken: @Sendable () async -> String?

    /// No credential lives here: the token is fetched per request from whoever owns the session.
    public init(config: SupabaseConfig, http: any SupabaseHTTP = URLSessionHTTP(),
                accessToken: @escaping @Sendable () async -> String?) {
        self.config = config
        self.http = http
        self.accessToken = accessToken
    }

    public func push(_ ops: [Op]) async throws {
        guard !ops.isEmpty else { return }
        var index = 0
        while index < ops.count {
            let end = min(index + Self.pushBatchSize, ops.count)
            try await pushBatch(Array(ops[index..<end]))
            index = end
        }
    }

    private func pushBatch(_ ops: [Op]) async throws {
        let body = try OpCoding.encoder().encode(PushBody(ops: ops))
        let url = config.restURL.appendingPathComponent("rpc/push_ops")
        let response = try await send(method: "POST", url: url, body: body)
        // 0 inserted is success: every op in the batch was already on the server.
        guard response.status == 200 || response.status == 204 else {
            throw Self.failure(response)
        }
    }

    public func pull(after cursor: Int64,
                     kitchenID: KitchenID) async throws -> (ops: [Op], cursor: Int64) {
        var advanced = cursor
        var ops: [Op] = []
        for _ in 0..<Self.maxPagesPerPull {
            let rows = try await page(after: advanced, kitchenID: kitchenID)
            guard let last = rows.last else { break }
            ops.append(contentsOf: rows.map(\.op))
            advanced = last.seq
            if rows.count < Self.pageSize { break }
        }
        return (ops, advanced)
    }

    private func page(after cursor: Int64, kitchenID: KitchenID) async throws -> [SeqRow] {
        let url = config.restURL.appendingPathComponent("op")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SupabaseTransportError.malformedResponse
        }
        components.queryItems = [
            URLQueryItem(name: "select",
                         value: "id,kitchen_id,device_id,clock,wall_clock,type,payload,seq"),
            URLQueryItem(name: "kitchen_id",
                         value: "eq.\(kitchenID.rawValue.uuidString.lowercased())"),
            URLQueryItem(name: "seq", value: "gt.\(cursor)"),
            URLQueryItem(name: "order", value: "seq.asc"),
            URLQueryItem(name: "limit", value: String(Self.pageSize)),
        ]
        guard let pageURL = components.url else { throw SupabaseTransportError.malformedResponse }
        let response = try await send(method: "GET", url: pageURL, body: nil)
        guard response.status == 200 else { throw Self.failure(response) }
        guard let rows = try? OpCoding.decoder().decode([SeqRow].self, from: response.body) else {
            throw SupabaseTransportError.malformedResponse
        }
        // Sorted here rather than trusted from the wire: the cursor may only reach a seq whose
        // op is in this array, and applying out of arrival order is the loss W3 proved.
        return rows.sorted { $0.seq < $1.seq }
    }

    private func send(method: String, url: URL,
                      body: Foundation.Data?) async throws -> SupabaseResponse {
        guard let token = await accessToken(), !token.isEmpty else {
            throw SupabaseTransportError.unauthenticated
        }
        var headers = [
            "apikey": config.anonKey,
            "authorization": "Bearer \(token)",
            "accept": "application/json",
        ]
        if body != nil { headers["content-type"] = "application/json" }
        return try await http.send(
            SupabaseRequest(method: method, url: url, headers: headers, body: body))
    }

    /// A 4xx that is not 401 is a refusal: RLS said no, or the body was malformed. Retrying it
    /// forever is how a queue wedges, so it is reported as its own kind.
    static func failure(_ response: SupabaseResponse) -> SupabaseTransportError {
        let code = (try? JSONDecoder().decode(PostgrestError.self, from: response.body))?.code
        if response.status == 401 { return .unauthenticated }
        if (400..<500).contains(response.status) {
            return .rejected(status: response.status, code: code)
        }
        return .server(status: response.status)
    }

    private struct PushBody: Encodable {
        let ops: [Op]

        enum CodingKeys: String, CodingKey {
            case ops = "p_ops"
        }
    }

    // The op row plus the column the op itself does not carry: its server sequence.
    private struct SeqRow: Decodable {
        let seq: Int64
        let op: Op

        private enum CodingKeys: String, CodingKey {
            case seq
        }

        init(from decoder: any Decoder) throws {
            seq = try decoder.container(keyedBy: CodingKeys.self).decode(Int64.self, forKey: .seq)
            op = try Op(from: decoder)
        }
    }

    private struct PostgrestError: Decodable {
        let code: String?
    }
}
