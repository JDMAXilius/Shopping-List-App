import Foundation

public struct Kitchen: Hashable, Sendable, Codable {
    public let id: KitchenID
    public var name: String

    public init(id: KitchenID = KitchenID(), name: String) {
        self.id = id
        self.name = name
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
