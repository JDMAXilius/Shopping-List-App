import Foundation

public enum ListItemField: String, Hashable, Sendable, CaseIterable {
    case itemID, name, quantity, unit, note, checked, shopID
}

public enum FieldWrite: Hashable, Sendable, Codable {
    case itemID(ItemID?)
    case name(String)
    case quantity(Double)
    case unit(String?)
    case note(String?)
    case checked(Bool)
    case shopID(ShopID?)

    public var field: ListItemField {
        switch self {
        case .itemID: return .itemID
        case .name: return .name
        case .quantity: return .quantity
        case .unit: return .unit
        case .note: return .note
        case .checked: return .checked
        case .shopID: return .shopID
        }
    }
}

public enum ShopChange: Hashable, Sendable, Codable {
    case upsert(Shop)
    case aisleOrder(AisleOrder)
}

// (clock, wallClock, deviceID) — the total order every LWW decision uses.
public struct OpStamp: Hashable, Sendable, Codable, Comparable {
    public let clock: UInt64
    public let wallClock: Date
    public let deviceID: DeviceID

    public init(clock: UInt64, wallClock: Date, deviceID: DeviceID) {
        self.clock = clock
        self.wallClock = wallClock
        self.deviceID = deviceID
    }

    public static func < (lhs: OpStamp, rhs: OpStamp) -> Bool {
        if lhs.clock != rhs.clock { return lhs.clock < rhs.clock }
        if lhs.wallClock != rhs.wallClock { return lhs.wallClock < rhs.wallClock }
        return lhs.deviceID.rawValue.uuidString < rhs.deviceID.rawValue.uuidString
    }
}

public struct Op: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case add(ListItem)
        case check(ListItemID)
        case uncheck(ListItemID)
        case edit(ListItemID, [FieldWrite])
        case delete(ListItemID)
        case price(PriceObservation)
        case shop(ShopChange)
    }

    public let opID: OpID
    public let kitchenID: KitchenID
    public let deviceID: DeviceID
    public let clock: UInt64
    public let wallClock: Date
    public let kind: Kind

    public init(opID: OpID = OpID(), kitchenID: KitchenID, deviceID: DeviceID,
                clock: UInt64, wallClock: Date, kind: Kind) {
        self.opID = opID
        self.kitchenID = kitchenID
        self.deviceID = deviceID
        self.clock = clock
        self.wallClock = wallClock
        self.kind = kind
    }

    public var stamp: OpStamp {
        OpStamp(clock: clock, wallClock: wallClock, deviceID: deviceID)
    }

    public var type: String {
        switch kind {
        case .add: return "add"
        case .check: return "check"
        case .uncheck: return "uncheck"
        case .edit: return "edit"
        case .delete: return "delete"
        case .price: return "price"
        case .shop: return "shop"
        }
    }
}

// Wire format for the supabase `op` row: type + payload columns, snake_case keys.
extension Op: Codable {
    private enum CodingKeys: String, CodingKey {
        case opID = "id"
        case kitchenID = "kitchen_id"
        case deviceID = "device_id"
        case clock
        case wallClock = "wall_clock"
        case type
        case payload
    }

    private struct EditPayload: Codable {
        let id: ListItemID
        let fields: [FieldWrite]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        opID = try container.decode(OpID.self, forKey: .opID)
        kitchenID = try container.decode(KitchenID.self, forKey: .kitchenID)
        deviceID = try container.decode(DeviceID.self, forKey: .deviceID)
        clock = try container.decode(UInt64.self, forKey: .clock)
        wallClock = try container.decode(Date.self, forKey: .wallClock)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "add":
            kind = .add(try container.decode(ListItem.self, forKey: .payload))
        case "check":
            kind = .check(try container.decode(ListItemID.self, forKey: .payload))
        case "uncheck":
            kind = .uncheck(try container.decode(ListItemID.self, forKey: .payload))
        case "edit":
            let payload = try container.decode(EditPayload.self, forKey: .payload)
            kind = .edit(payload.id, payload.fields)
        case "delete":
            kind = .delete(try container.decode(ListItemID.self, forKey: .payload))
        case "price":
            kind = .price(try container.decode(PriceObservation.self, forKey: .payload))
        case "shop":
            kind = .shop(try container.decode(ShopChange.self, forKey: .payload))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "unknown op type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(opID, forKey: .opID)
        try container.encode(kitchenID, forKey: .kitchenID)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(clock, forKey: .clock)
        try container.encode(wallClock, forKey: .wallClock)
        try container.encode(type, forKey: .type)
        switch kind {
        case .add(let item):
            try container.encode(item, forKey: .payload)
        case .check(let id), .uncheck(let id), .delete(let id):
            try container.encode(id, forKey: .payload)
        case .edit(let id, let fields):
            try container.encode(EditPayload(id: id, fields: fields), forKey: .payload)
        case .price(let observation):
            try container.encode(observation, forKey: .payload)
        case .shop(let change):
            try container.encode(change, forKey: .payload)
        }
    }
}
