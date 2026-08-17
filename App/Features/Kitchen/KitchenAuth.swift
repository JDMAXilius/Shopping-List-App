import Core
import Data
import Foundation
import Security

/// Who this phone is to the server. A guest is anonymous auth — a real `authenticated` user
/// with no account behind it (ARCHITECTURE §7) — and never sees a sign-in screen.
struct KitchenIdentity: Sendable, Equatable, Codable {
    let userID: UserID
    let isAnonymous: Bool
    let email: String?
}

enum KitchenError: Error, Equatable {
    /// Offline, a timeout, or a 5xx: the same request will work later.
    case unreachable
    /// Missing OR revoked, told apart by nobody — the server answers both the same way and
    /// so does this app.
    case inviteNotFound
    case notPermitted
    case badCode
    case signInRequired
    /// Linking an Apple identity to an existing anonymous user needs GoTrue's OAuth link
    /// flow; signing in with Apple here would mint a DIFFERENT user and drop this phone's
    /// membership. Refused rather than done quietly.
    case appleUpgradeUnsupported
    case malformed
}

protocol TokenStorage: Sendable {
    func read() -> Foundation.Data?
    func write(_ data: Foundation.Data)
    func clear()
}

/// The session lives in the keychain, not in defaults: a refresh token is a long-lived bearer
/// credential. `afterFirstUnlock` because sync runs before the user has typed a passcode.
struct KeychainTokenStorage: TokenStorage {
    let service: String
    let account: String

    init(service: String = "app.bagged.session", account: String = "supabase") {
        self.service = service
        self.account = account
    }

    private var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func read() -> Foundation.Data? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Foundation.Data
    }

    func write(_ data: Foundation.Data) {
        _ = SecItemDelete(base as CFDictionary)
        var query = base
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        _ = SecItemAdd(query as CFDictionary, nil)
    }

    func clear() {
        _ = SecItemDelete(base as CFDictionary)
    }
}

/// GoTrue, spoken directly. One actor owns the tokens, so the transport, the scan client and
/// the screens all read one session and a refresh can never race itself.
actor KitchenAuth {
    private struct Tokens: Sendable, Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var identity: KitchenIdentity
    }

    private enum PendingEmail: Sendable {
        /// A brand-new owner: `/otp` then `verify(type: email)`.
        case signIn(String)
        /// An anonymous user securing their kitchen: `PUT /user` then
        /// `verify(type: email_change)`. This keeps the SAME user id, which is what keeps
        /// their membership — a fresh sign-in would strand the kitchen they already joined.
        case change(String)
    }

    private let config: SupabaseConfig
    private let http: any SupabaseHTTP
    private let storage: any TokenStorage
    private var tokens: Tokens?
    private var loaded = false
    private var pending: PendingEmail?

    init(config: SupabaseConfig, http: any SupabaseHTTP = URLSessionHTTP(),
         storage: any TokenStorage = KeychainTokenStorage()) {
        self.config = config
        self.http = http
        self.storage = storage
    }

    func identity() -> KitchenIdentity? {
        load()
        return tokens?.identity
    }

    /// What the transport and the scan client call. Nil means "no session" — never a guess,
    /// never a stale token: an expired one is refreshed first.
    func accessToken() async -> String? {
        load()
        guard let current = tokens else { return nil }
        guard current.expiresAt.timeIntervalSinceNow < 60 else { return current.accessToken }
        return try? await refresh(current.refreshToken).accessToken
    }

    func signInAnonymously() async throws -> KitchenIdentity {
        load()
        // A session that can no longer be refreshed is replaced, not reported: a guest must
        // never be sent to a sign-in screen because a refresh token aged out.
        if tokens != nil, await accessToken() != nil, let existing = tokens?.identity {
            return existing
        }
        let body = try encode(["data": [:] as [String: String]])
        let response = try await send(method: "POST", url: url("signup"), body: body, token: nil)
        return try adopt(response)
    }

    func requestEmailCode(_ email: String) async throws {
        load()
        if let current = tokens, current.identity.isAnonymous {
            let token = await accessToken()
            let response = try await send(method: "PUT", url: url("user"),
                                          body: try encode(["email": email]), token: token)
            guard response.status == 200 else { throw Self.failure(response) }
            pending = .change(email)
            return
        }
        let body = try encode(["email": email, "create_user": true])
        let response = try await send(method: "POST", url: url("otp"), body: body, token: nil)
        guard response.status == 200 else { throw Self.failure(response) }
        pending = .signIn(email)
    }

    func verifyEmailCode(_ code: String) async throws -> KitchenIdentity {
        guard let pending else { throw KitchenError.malformed }
        let email: String
        let type: String
        switch pending {
        case .signIn(let address):
            email = address
            type = "email"
        case .change(let address):
            email = address
            type = "email_change"
        }
        let body = try encode(["email": email, "token": code, "type": type])
        let response = try await send(method: "POST", url: url("verify"), body: body, token: nil)
        guard response.status == 200 else {
            throw response.status == 401 || response.status == 403 || response.status == 400
                ? KitchenError.badCode : Self.failure(response)
        }
        self.pending = nil
        return try adopt(response)
    }

    /// Only for a phone with no session at all. With an anonymous session this would sign in
    /// as a different user and lose the kitchen — see `appleUpgradeUnsupported`.
    func signInWithApple(idToken: String, nonce: String) async throws -> KitchenIdentity {
        load()
        if tokens?.identity.isAnonymous == true { throw KitchenError.appleUpgradeUnsupported }
        let body = try encode(["provider": "apple", "id_token": idToken, "nonce": nonce])
        var components = URLComponents(url: url("token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        guard let endpoint = components?.url else { throw KitchenError.malformed }
        let response = try await send(method: "POST", url: endpoint, body: body, token: nil)
        return try adopt(response)
    }

    func signOut() {
        tokens = nil
        pending = nil
        loaded = true
        storage.clear()
    }

    // MARK: - Plumbing

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let data = storage.read() else { return }
        tokens = try? JSONDecoder().decode(Tokens.self, from: data)
    }

    private func refresh(_ refreshToken: String) async throws -> Tokens {
        var components = URLComponents(url: url("token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let endpoint = components?.url else { throw KitchenError.malformed }
        let body = try encode(["refresh_token": refreshToken])
        let response = try await send(method: "POST", url: endpoint, body: body, token: nil)
        // A refused refresh is a dead session: keeping it would retry a token that will never
        // work again, and the screens would keep claiming a membership this phone has lost.
        if response.status == 400 || response.status == 401 {
            signOut()
            throw KitchenError.signInRequired
        }
        _ = try adopt(response)
        guard let current = tokens else { throw KitchenError.malformed }
        return current
    }

    @discardableResult
    private func adopt(_ response: SupabaseResponse) throws -> KitchenIdentity {
        guard response.status == 200 else { throw Self.failure(response) }
        guard let body = try? JSONDecoder().decode(SessionBody.self, from: response.body) else {
            throw KitchenError.malformed
        }
        let identity = KitchenIdentity(userID: UserID(body.user.id),
                                       isAnonymous: body.user.isAnonymous ?? false,
                                       email: body.user.email)
        let next = Tokens(accessToken: body.accessToken, refreshToken: body.refreshToken,
                          expiresAt: Date().addingTimeInterval(body.expiresIn ?? 3600),
                          identity: identity)
        tokens = next
        if let data = try? JSONEncoder().encode(next) { storage.write(data) }
        return identity
    }

    private func url(_ path: String) -> URL {
        config.authURL.appendingPathComponent(path)
    }

    private func encode(_ object: [String: Any]) throws -> Foundation.Data {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            throw KitchenError.malformed
        }
        return data
    }

    private func send(method: String, url: URL, body: Foundation.Data?,
                      token: String?) async throws -> SupabaseResponse {
        var headers = ["apikey": config.anonKey, "accept": "application/json"]
        if body != nil { headers["content-type"] = "application/json" }
        // The anon key is the gateway's key; a user token, when there is one, is the identity.
        headers["authorization"] = "Bearer \(token ?? config.anonKey)"
        do {
            return try await http.send(
                SupabaseRequest(method: method, url: url, headers: headers, body: body))
        } catch {
            throw KitchenError.unreachable
        }
    }

    static func failure(_ response: SupabaseResponse) -> KitchenError {
        switch response.status {
        case 401: return .signInRequired
        case 403: return .notPermitted
        case 404: return .inviteNotFound
        case 400..<500: return .malformed
        default: return .unreachable
        }
    }

    private struct SessionBody: Decodable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Double?
        let user: UserBody

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }

        struct UserBody: Decodable {
            let id: UUID
            let email: String?
            let isAnonymous: Bool?

            enum CodingKeys: String, CodingKey {
                case id, email
                case isAnonymous = "is_anonymous"
            }
        }
    }
}
