import Foundation

public struct ItemID: Hashable, Sendable, Codable {
    public let rawValue: UUID
    public init(_ rawValue: UUID = UUID()) { self.rawValue = rawValue }
    public init(from decoder: Decoder) throws { rawValue = try UUID(from: decoder) }
    public func encode(to encoder: Encoder) throws { try rawValue.encode(to: encoder) }
}

extension ItemID {
    // Byte 6 is 0x00, which no random (v4) UUID can carry — its version nibble is 4 —
    // so a catalog-backed id and a user-created one can never collide.
    private static let catalogNamespace: [UInt8] = [0xBA, 0x60, 0xCA, 0x7A, 0x10, 0x60, 0x00, 0x01]

    /// Catalog-backed items MUST take their ItemID from here, everywhere, forever: this is the
    /// join key between seeded estimates and observed prices, and two mappings split the price book.
    public static func catalog(_ catalogID: Int64) -> ItemID {
        var b = catalogNamespace
        withUnsafeBytes(of: catalogID.bigEndian) { b.append(contentsOf: $0) }
        return ItemID(
            UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                        b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])))
    }

    /// The catalog row this id was minted from; nil for a user-created item.
    public var catalogID: Int64? {
        let u = rawValue.uuid
        guard [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7] == Self.catalogNamespace else { return nil }
        let bits = [u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
            .reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        return Int64(bitPattern: bits)
    }
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
