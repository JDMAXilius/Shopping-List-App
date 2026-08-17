import Foundation

// Append-only: observations accumulate, they never overwrite.
// This is a `.price` op payload. Its key names are permanent — renaming one silently orphans
// every op already written — and an absent `quantityMilli` is the shape every one of them has.
public struct PriceObservation: Hashable, Sendable, Codable {
    public enum Source: String, Hashable, Sendable, Codable {
        case receipt, manual, typed, corrected
    }

    public enum Confidence: String, Hashable, Sendable {
        case trusted, dated, estimate
    }

    public let itemID: ItemID
    public let shopID: ShopID
    public let date: Date
    /// The price of ONE — what the price book compares between shops and across time.
    public let amount: Money
    public let source: Source
    /// How many `amount` was observed at, in thousandths so it round-trips exactly: 4 is 4000,
    /// half a pound is 500 — Money keeps Doubles out of a total and so does this. nil is not one:
    /// it is an observation written before counts existed, which is every op already in a log.
    public let quantityMilli: Int?

    /// `quantity` is optional at the door so a caller that does not know cannot accidentally
    /// claim one. Zero, negative and non-finite are not counts: they store as nil too.
    public init(itemID: ItemID, shopID: ShopID, date: Date, amount: Money, source: Source,
                quantity: Double? = nil) {
        self.itemID = itemID
        self.shopID = shopID
        self.date = date
        self.amount = amount
        self.source = source
        quantityMilli = quantity.flatMap(PriceObservation.milli)
    }

    private static func milli(_ quantity: Double) -> Int? {
        guard quantity.isFinite, quantity > 0, quantity <= 1_000_000 else { return nil }
        return Int((quantity * 1000).rounded())
    }

    /// One unit when nothing was recorded — exactly what such an observation has always meant
    /// to every total in the app. It is never a guess at how many were bought.
    public var quantity: Double { Double(quantityMilli ?? 1000) / 1000 }

    /// False for every observation written before this field existed: a total built from those
    /// counts them once, which is a floor. Surfaces that state a month's spend say so instead
    /// of calling the difference tax.
    public var hasRecordedQuantity: Bool { quantityMilli != nil }

    // <30d trusted · 30–90d dated · >90d demoted back to estimate.
    public func confidence(asOf now: Date = Date()) -> Confidence {
        let days = now.timeIntervalSince(date) / 86_400
        if days < 30 { return .trusted }
        return days <= 90 ? .dated : .estimate
    }
}
