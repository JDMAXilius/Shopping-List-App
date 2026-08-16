import Foundation

public struct ItemID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try UUID(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}

public struct ListItemID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try UUID(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}

public struct KitchenID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try UUID(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}

public struct ShopID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try UUID(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}

public struct DeviceID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try UUID(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}

public struct OpID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try UUID(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}

public struct UserID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try UUID(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}

// String-keyed: catalog categories are hand-built stable slugs, not UUIDs.
public struct CategoryID: Hashable, Sendable, Codable {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try String(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}
