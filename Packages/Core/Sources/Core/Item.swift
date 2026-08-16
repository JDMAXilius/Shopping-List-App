import Foundation

public struct Item: Hashable, Sendable, Codable {
    public let id: ItemID
    public var canonicalName: String
    public var categoryID: CategoryID
    public var defaultUnit: String?

    public init(id: ItemID = ItemID(), canonicalName: String, categoryID: CategoryID,
                defaultUnit: String? = nil) {
        self.id = id
        self.canonicalName = canonicalName
        self.categoryID = categoryID
        self.defaultUnit = defaultUnit
    }
}

public struct ListItem: Hashable, Sendable, Codable {
    public let listItemID: ListItemID
    public var itemID: ItemID?
    public var name: String
    public var quantity: Double
    public var unit: String?
    public var note: String?
    public var checked: Bool
    public var shopID: ShopID?
    public let createdAt: Date
    // Per-field LWW stamps; rebuilt by Merge, never sent on the wire.
    public var updatedFields: [ListItemField: OpStamp] = [:]

    private enum CodingKeys: String, CodingKey {
        case listItemID, itemID, name, quantity, unit, note, checked, shopID, createdAt
    }

    public init(listItemID: ListItemID = ListItemID(), itemID: ItemID? = nil, name: String,
                quantity: Double = 1, unit: String? = nil, note: String? = nil,
                checked: Bool = false, shopID: ShopID? = nil, createdAt: Date = Date(),
                updatedFields: [ListItemField: OpStamp] = [:]) {
        self.listItemID = listItemID
        self.itemID = itemID
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.note = note
        self.checked = checked
        self.shopID = shopID
        self.createdAt = createdAt
        self.updatedFields = updatedFields
    }

    mutating func apply(_ write: FieldWrite) {
        switch write {
        case .itemID(let value): itemID = value
        case .name(let value): name = value
        case .quantity(let value): quantity = value
        case .unit(let value): unit = value
        case .note(let value): note = value
        case .checked(let value): checked = value
        case .shopID(let value): shopID = value
        }
    }
}
