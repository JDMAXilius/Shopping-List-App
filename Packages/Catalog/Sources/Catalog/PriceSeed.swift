public struct PriceSeed: Sendable, Equatable {
    public let itemID: Int64
    public let baseAmount: Double
    public let currency: String
    public let baseUnit: String?
    public let compiledYear: Int

    public init(itemID: Int64, baseAmount: Double, currency: String, baseUnit: String?, compiledYear: Int) {
        self.itemID = itemID
        self.baseAmount = baseAmount
        self.currency = currency
        self.baseUnit = baseUnit
        self.compiledYear = compiledYear
    }
}

public struct PriceRegion: Sendable, Equatable {
    public let key: String
    public let label: String
    public let multiplier: Double

    public init(key: String, label: String, multiplier: Double) {
        self.key = key
        self.label = label
        self.multiplier = multiplier
    }
}

extension CatalogDatabase {
    public func priceSeed(itemID: Int64) throws -> PriceSeed? {
        let sql = """
            SELECT item_id, base_amount, currency, base_unit, compiled_year
              FROM price_seed WHERE item_id = ?
            """
        guard let row = try rows(sql, bind: [.integer(itemID)]).first,
            let id = row[0].integerValue,
            let base = row[1].doubleValue,
            let currency = row[2].textValue,
            let year = row[4].integerValue
        else { return nil }
        return PriceSeed(
            itemID: id, baseAmount: base, currency: currency,
            baseUnit: row[3].textValue, compiledYear: Int(year))
    }

    public func priceRegion(_ key: String) throws -> PriceRegion? {
        let sql = "SELECT region_key, label, multiplier FROM price_region WHERE region_key = ?"
        guard let row = try rows(sql, bind: [.text(key)]).first,
            let regionKey = row[0].textValue,
            let label = row[1].textValue,
            let multiplier = row[2].doubleValue
        else { return nil }
        return PriceRegion(key: regionKey, label: label, multiplier: multiplier)
    }
}

public enum PriceEstimate {
    /// Duplicated from Core/Money.estimate on purpose (no cross-package
    /// dependency): estimates round hard to the nearest half unit, ties up —
    /// ~$4.50, never $4.37. The honesty of the number is the brand.
    public static func rounded(_ amount: Double) -> Double {
        (amount * 2).rounded() / 2
    }

    /// base_amount × regional multiplier, rounded to the estimate grid.
    /// nil when the item has no seed or the region is unknown.
    public static func estimate(db: CatalogDatabase, itemID: Int64, regionKey: String) throws -> Double? {
        guard let seed = try db.priceSeed(itemID: itemID),
            let region = try db.priceRegion(regionKey)
        else { return nil }
        return rounded(seed.baseAmount * region.multiplier)
    }
}
