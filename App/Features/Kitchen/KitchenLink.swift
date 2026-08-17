import Foundation

/// An invite link is a bearer token: whoever holds it can join the kitchen until it is
/// replaced. So it is never logged, never truncated into an "id", and never guessed at —
/// the only thing this type does is carry the exact string between a URL and the server.
///
/// The server mints 256 bits of base64url (`create_invite`, 0002_rls.sql). Nothing here
/// validates a token against the server: a token is valid iff `join_kitchen` says so, and
/// missing and revoked come back as the same answer on purpose (no enumeration oracle).
enum KitchenLink {
    static let host = "bagged.app"
    static let pathPrefix = "/j/"

    /// The allowed shape, not a claim of validity — it only keeps obvious junk (a whole
    /// pasted sentence, an empty clipboard) from being sent as a token.
    static let allowedLength = 16...200

    static func url(token: String) -> URL? {
        guard isWellFormed(token) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = pathPrefix + token
        return components.url
    }

    /// Accepts what a person can actually give us: the link they were sent, the link without
    /// its scheme, or the token on its own.
    static func token(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let last = pathToken(trimmed) { return last }
        return isWellFormed(trimmed) ? trimmed : nil
    }

    static func token(from url: URL) -> String? {
        token(from: url.absoluteString)
    }

    /// True for a link this app should open at all — the lead's `.onOpenURL` gate.
    static func isInvite(_ url: URL) -> Bool {
        token(from: url) != nil
    }

    private static func pathToken(_ text: String) -> String? {
        let normalized = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: normalized), url.host() == host else {
            return nil
        }
        let path = url.path()
        guard path.hasPrefix(pathPrefix) else { return nil }
        let candidate = String(path.dropFirst(pathPrefix.count))
        return isWellFormed(candidate) ? candidate : nil
    }

    private static func isWellFormed(_ token: String) -> Bool {
        guard allowedLength.contains(token.count) else { return false }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        return token.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
