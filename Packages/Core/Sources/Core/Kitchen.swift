import Foundation

public struct Kitchen: Hashable, Sendable, Codable {
    public let id: KitchenID
    public var name: String
    /// A kitchen shops in ONE currency: every price in its book, and every total over them,
    /// is in this code. A receipt printing another one is an exception to flag, never to mix.
    public var currencyCode: String

    public init(id: KitchenID = KitchenID(), name: String,
                currencyCode: String = Kitchen.defaultCurrencyCode(for: .current)) {
        self.id = id
        self.name = name
        self.currencyCode = currencyCode
    }

    // The device is the only signal at creation; a locale with no currency (POSIX) gets USD.
    public static func defaultCurrencyCode(for locale: Locale) -> String {
        locale.currency?.identifier ?? "USD"
    }
}

public struct Member: Hashable, Sendable, Codable {
    public enum Role: String, Hashable, Sendable, Codable {
        case owner, guest
    }

    public let userID: UserID
    public var role: Role
    public let joinedAt: Date

    public init(userID: UserID, role: Role, joinedAt: Date) {
        self.userID = userID
        self.role = role
        self.joinedAt = joinedAt
    }
}

public struct InviteToken: Hashable, Sendable, Codable {
    public let token: String
    public let createdAt: Date
    public var revokedAt: Date?

    public init(token: String, createdAt: Date, revokedAt: Date? = nil) {
        self.token = token
        self.createdAt = createdAt
        self.revokedAt = revokedAt
    }
}
