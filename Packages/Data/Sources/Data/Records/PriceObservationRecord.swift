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
    /// NULL for every row projected from an op written before counts existed: the column carries
    /// the op's own silence rather than the one every total already assumed.
    var quantityMilli: Int?

    enum CodingKeys: String, CodingKey {
        case opID = "op_id"
        case itemID = "item_id"
        case shopID = "shop_id"
        case observedAt = "observed_at"
        case amountMinor = "amount_minor"
        case currency
        case source
        case quantityMilli = "quantity_milli"
    }

    init(opID: OpID, observation: PriceObservation) {
        self.opID = opID.rawValue.uuidString
        itemID = observation.itemID.rawValue.uuidString
        shopID = observation.shopID.rawValue.uuidString
        observedAt = observation.date.msSince1970
        amountMinor = observation.amount.minorUnits
        currency = observation.amount.currencyCode
        source = observation.source.rawValue
        quantityMilli = observation.quantityMilli
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
            source: source,
            // Thousandths divide back exactly at this scale, so the row and the op it came
            // from carry the same count — and a NULL stays "nobody recorded one".
            quantity: quantityMilli.map { Double($0) / 1000 })
    }
}
