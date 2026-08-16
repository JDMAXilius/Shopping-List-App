import Core
import Foundation
import GRDB

struct ShopRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "shop"

    var id: String
    var name: String
    var branch: String?
    var wakeRadius: Double
    var wakeEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, branch
        case wakeRadius = "wake_radius"
        case wakeEnabled = "wake_enabled"
    }

    init(shop: Shop) {
        id = shop.id.rawValue.uuidString
        name = shop.name
        branch = shop.branch
        wakeRadius = shop.wakeRadius
        wakeEnabled = shop.wakeEnabled
    }

    func shop() throws -> Shop {
        Shop(id: ShopID(try requireUUID(id)), name: name, branch: branch,
             wakeRadius: wakeRadius, wakeEnabled: wakeEnabled)
    }
}

struct AisleOrderRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "aisle_order"

    var shopID: String
    var position: Int
    var categoryID: String

    enum CodingKeys: String, CodingKey {
        case shopID = "shop_id"
        case position
        case categoryID = "category_id"
    }
}
