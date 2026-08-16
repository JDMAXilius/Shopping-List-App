import Foundation

// Append-only: observations accumulate, they never overwrite.
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
    public let amount: Money
    public let source: Source

    public init(itemID: ItemID, shopID: ShopID, date: Date, amount: Money, source: Source) {
        self.itemID = itemID
        self.shopID = shopID
        self.date = date
        self.amount = amount
        self.source = source
    }

    // <30d trusted · 30–90d dated · >90d demoted back to estimate.
    public func confidence(asOf now: Date = Date()) -> Confidence {
        let days = now.timeIntervalSince(date) / 86_400
        if days < 30 { return .trusted }
        return days <= 90 ? .dated : .estimate
    }
}
