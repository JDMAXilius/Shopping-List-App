import Core
import Foundation
import GRDB

struct ListItemRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "list_item"

    var id: String
    var name: String
    var normalizedName: String
    var itemID: String?
    var quantity: Double
    var unit: String?
    var note: String?
    var checked: Bool
    var shopID: String?
    var createdAt: Int64
    var deleted: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, note, checked, deleted
        case normalizedName = "normalized_name"
        case itemID = "item_id"
        case shopID = "shop_id"
        case createdAt = "created_at"
    }

    init(item: ListItem) {
        id = item.listItemID.rawValue.uuidString
        name = item.name
        normalizedName = Merge.normalized(item.name)
        itemID = item.itemID?.rawValue.uuidString
        quantity = item.quantity
        unit = item.unit
        note = item.note
        checked = item.checked
        shopID = item.shopID?.rawValue.uuidString
        createdAt = item.createdAt.msSince1970
        // Reserved: Core's projection exposes live rows only; tombstoned rows are absent, not flagged.
        deleted = false
    }

    func listItem() throws -> ListItem {
        return ListItem(
            listItemID: ListItemID(try requireUUID(id)),
            itemID: try itemID.map { ItemID(try requireUUID($0)) },
            name: name,
            quantity: quantity,
            unit: unit,
            note: note,
            checked: checked,
            shopID: try shopID.map { ShopID(try requireUUID($0)) },
            createdAt: Date(msSince1970: createdAt))
    }
}

// Op-derived, like list_item: a null item_id is "ignore this receipt line forever",
// and no row at all is "this text was never aliased".
struct AliasRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "alias"

    var rawText: String
    var itemID: String?

    enum CodingKeys: String, CodingKey {
        case rawText = "raw_text"
        case itemID = "item_id"
    }
}

// Op-derived too: the name the kitchen taught an item, which outlives every list row that
// ever pointed at it.
struct ItemNameRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "item_name"

    var itemID: String
    var name: String

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case name
    }
}
