import Core
import Data
import Foundation

/// Everything the sharing flow asks of the server. A protocol so the store can be tested
/// without a network, exactly as `ScanBackend` is.
protocol KitchenBackend: Sendable {
    func identity() async -> KitchenIdentity?
    /// The guest's whole account story: an anonymous session, no email, no password, no wall.
    func signInAnonymously() async throws -> KitchenIdentity
    /// Goes through the `join-kitchen` function, which calls the SECURITY DEFINER
    /// `join_kitchen(token)`. There is no anon SELECT on `invite` anywhere in this app.
    func join(token: String) async throws -> KitchenID
    func createKitchen(name: String, id: KitchenID) async throws -> KitchenID
    func renameKitchen(_ kitchenID: KitchenID, to name: String) async throws
    /// Mints a NEW token and revokes every earlier one (the trigger does it server-side).
    func createInvite(kitchenID: KitchenID) async throws -> String
    func members(kitchenID: KitchenID) async throws -> [Member]
    func kitchenName(kitchenID: KitchenID) async throws -> String?
    /// Entitlement without a scan (TERMINAL_TICKET_FOUNDER_BLOCKERS §9). It does not throw
    /// because a caller must not be able to catch "the row is not there" and "the request
    /// failed" in one `catch`: only one of them is allowed to write.
    func entitlement() async -> EntitlementRead
    func requestEmailCode(_ email: String) async throws
    func verifyEmailCode(_ code: String) async throws -> KitchenIdentity
    func signInWithApple(idToken: String, nonce: String) async throws -> KitchenIdentity
    func signOut() async
}

/// PostgREST + the join function. No credential lives here beyond the anon key the build was
/// given; the session belongs to `KitchenAuth`.
struct KitchenClient: KitchenBackend {
    private let config: SupabaseConfig
    private let http: any SupabaseHTTP
    private let auth: KitchenAuth

    init(config: SupabaseConfig, auth: KitchenAuth, http: any SupabaseHTTP = URLSessionHTTP()) {
        self.config = config
        self.auth = auth
        self.http = http
    }

    func identity() async -> KitchenIdentity? { await auth.identity() }

    func signInAnonymously() async throws -> KitchenIdentity {
        try await auth.signInAnonymously()
    }

    func requestEmailCode(_ email: String) async throws { try await auth.requestEmailCode(email) }

    func verifyEmailCode(_ code: String) async throws -> KitchenIdentity {
        try await auth.verifyEmailCode(code)
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> KitchenIdentity {
        try await auth.signInWithApple(idToken: idToken, nonce: nonce)
    }

    func signOut() async { await auth.signOut() }

    func join(token: String) async throws -> KitchenID {
        let url = config.functionsURL.appendingPathComponent("join-kitchen")
        let body = try encode(["token": token])
        let response = try await send(method: "POST", url: url, body: body)
        // The function answers one 404 for invalid AND revoked; this app repeats that answer
        // rather than guessing which it was.
        guard response.status == 200 else { throw KitchenAuth.failure(response) }
        guard let decoded = try? JSONDecoder().decode(JoinBody.self, from: response.body) else {
            throw KitchenError.malformed
        }
        return KitchenID(decoded.kitchenID)
    }

    /// The id goes UP, not down. Every op this phone has already written is stamped with its
    /// local kitchen id; letting the server mint a new one strands all of them, invisibly —
    /// the engine correctly refuses to push another kitchen's ops and the local projection is
    /// kitchen-blind, so the owner keeps seeing a list the guest will never receive.
    func createKitchen(name: String, id: KitchenID) async throws -> KitchenID {
        let response = try await rpc("create_kitchen",
                                     ["p_name": name, "p_id": identifier(id)])
        guard let id = UUID(uuidString: Self.scalar(response)) else { throw KitchenError.malformed }
        return KitchenID(id)
    }

    func renameKitchen(_ kitchenID: KitchenID, to name: String) async throws {
        var components = URLComponents(
            url: config.restURL.appendingPathComponent("kitchen"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "id", value: "eq.\(identifier(kitchenID))")]
        guard let url = components?.url else { throw KitchenError.malformed }
        let response = try await send(method: "PATCH", url: url, body: try encode(["name": name]))
        guard response.status == 200 || response.status == 204 else {
            throw KitchenAuth.failure(response)
        }
    }

    func createInvite(kitchenID: KitchenID) async throws -> String {
        let response = try await rpc("create_invite", ["p_kitchen": identifier(kitchenID)])
        let token = Self.scalar(response)
        guard !token.isEmpty else { throw KitchenError.malformed }
        return token
    }

    func members(kitchenID: KitchenID) async throws -> [Member] {
        let rows: [MemberBody] = try await select(
            "member", query: [URLQueryItem(name: "select", value: "user_id,role,joined_at"),
                              URLQueryItem(name: "kitchen_id",
                                           value: "eq.\(identifier(kitchenID))")])
        return rows.compactMap { row in
            guard let id = UUID(uuidString: row.userID),
                  let role = Member.Role(rawValue: row.role) else { return nil }
            return Member(userID: UserID(id), role: role,
                          joinedAt: KitchenClient.timestamp(row.joinedAt))
        }
    }

    func kitchenName(kitchenID: KitchenID) async throws -> String? {
        let rows: [NameBody] = try await select(
            "kitchen", query: [URLQueryItem(name: "select", value: "name"),
                               URLQueryItem(name: "id", value: "eq.\(identifier(kitchenID))")])
        return rows.first?.name
    }

    /// This user's own entitlement row. No filter and no user id on the wire: the policy is
    /// `entitlement_select_own` — `user_id = auth.uid()` — so the answer is one row or none, and
    /// a client-supplied owner column is exactly what that policy exists to make unnecessary.
    func entitlement() async -> EntitlementRead {
        do {
            let rows: [EntitlementBody] = try await select(
                "entitlement",
                query: [URLQueryItem(name: "select", value: "is_plus,scans_used")])
            // An empty array is a user who has never scanned: `consume_scan` creates the row
            // lazily. That is an answer, not a failure.
            guard let row = rows.first else { return .absent }
            return .found(isPlus: row.isPlus, scansUsed: row.scansUsed)
        } catch {
            // Offline, 401, malformed, no session at all: every one of these claims nothing.
            return .unavailable
        }
    }

    // MARK: - Plumbing

    private func rpc(_ name: String, _ arguments: [String: Any]) async throws -> Foundation.Data {
        let url = config.restURL.appendingPathComponent("rpc/\(name)")
        let response = try await send(method: "POST", url: url, body: try encode(arguments))
        guard response.status == 200 else { throw KitchenAuth.failure(response) }
        return response.body
    }

    private func select<T: Decodable>(_ table: String, query: [URLQueryItem]) async throws -> [T] {
        var components = URLComponents(url: config.restURL.appendingPathComponent(table),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = query
        guard let url = components?.url else { throw KitchenError.malformed }
        let response = try await send(method: "GET", url: url, body: nil)
        guard response.status == 200 else { throw KitchenAuth.failure(response) }
        guard let rows = try? JSONDecoder().decode([T].self, from: response.body) else {
            throw KitchenError.malformed
        }
        return rows
    }

    private func send(method: String, url: URL,
                      body: Foundation.Data?) async throws -> SupabaseResponse {
        guard let token = await auth.accessToken() else { throw KitchenError.signInRequired }
        var headers = ["apikey": config.anonKey, "authorization": "Bearer \(token)",
                       "accept": "application/json"]
        if body != nil { headers["content-type"] = "application/json" }
        do {
            return try await http.send(
                SupabaseRequest(method: method, url: url, headers: headers, body: body))
        } catch {
            throw KitchenError.unreachable
        }
    }

    private func identifier(_ kitchenID: KitchenID) -> String {
        kitchenID.rawValue.uuidString.lowercased()
    }

    private func encode(_ object: [String: Any]) throws -> Foundation.Data {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            throw KitchenError.malformed
        }
        return data
    }

    /// `timestamptz` as PostgREST prints it. A date we cannot read becomes the epoch, which
    /// the roster renders as no date at all — never a guessed "joined today".
    static func timestamp(_ text: String) -> Date {
        let shapes: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
        ]
        let formatter = ISO8601DateFormatter()
        // Postgres prints microseconds; ISO8601DateFormatter reads milliseconds, so the
        // sub-second part is dropped rather than costing us the whole date.
        let candidates = [text, Self.withoutFraction(text)]
        for candidate in candidates {
            for options in shapes {
                formatter.formatOptions = options
                if let date = formatter.date(from: candidate) { return date }
            }
        }
        return Date(timeIntervalSince1970: 0)
    }

    /// A PostgREST function returning a scalar answers with a bare JSON value (`"abc"`), which
    /// is read as text rather than decoded as a fragment — one less thing to be wrong about.
    private static func scalar(_ data: Foundation.Data) -> String {
        String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"\r\n "))
    }

    private static func withoutFraction(_ text: String) -> String {
        guard let dot = text.firstIndex(of: ".") else { return text }
        let rest = text[dot...].drop { $0 == "." || $0.isNumber }
        return String(text[text.startIndex..<dot]) + String(rest)
    }

    private struct JoinBody: Decodable {
        let kitchenID: UUID

        enum CodingKeys: String, CodingKey {
            case kitchenID = "kitchen_id"
        }
    }

    private struct MemberBody: Decodable {
        let userID: String
        let role: String
        let joinedAt: String

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case role
            case joinedAt = "joined_at"
        }
    }

    private struct NameBody: Decodable {
        let name: String
    }

    private struct EntitlementBody: Decodable {
        let isPlus: Bool
        let scansUsed: Int

        enum CodingKeys: String, CodingKey {
            case isPlus = "is_plus"
            case scansUsed = "scans_used"
        }
    }
}
