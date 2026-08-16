import Core
import Foundation
import GRDB

// Keyed by op_id: replay is idempotent and identical duplicate lines both survive.
struct PriceObservationRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "price_observation"

    var opID: String
    var itemID: String
    var shopID: String
    var observedAt: Int64
    var amountMinor: Int
    var currency: String
    var source: String

    enum CodingKeys: String, CodingKey {
        case opID = "op_id"
        case itemID = "item_id"
        case shopID = "shop_id"
        case observedAt = "observed_at"
        case amountMinor = "amount_minor"
        case currency
        case source
    }

    init(opID: OpID, observation: PriceObservation) {
        self.opID = opID.rawValue.uuidString
        itemID = observation.itemID.rawValue.uuidString
        shopID = observation.shopID.rawValue.uuidString
        observedAt = observation.date.msSince1970
        amountMinor = observation.amount.minorUnits
        currency = observation.amount.currencyCode
        source = observation.source.rawValue
    }

    func observation() throws -> PriceObservation {
        guard let source = PriceObservation.Source(rawValue: source) else {
            throw DataError.malformedRow
        }
        return PriceObservation(
            itemID: ItemID(try requireUUID(itemID)),
            shopID: ShopID(try requireUUID(shopID)),
            date: Date(msSince1970: observedAt),
            amount: Money(minorUnits: amountMinor, currencyCode: currency),
            source: source)
    }
}
