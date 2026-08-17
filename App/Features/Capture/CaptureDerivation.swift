import Core
import Foundation

/// What the user decided about one line. Nothing here is written until commit.
enum LineDecision: Hashable, Sendable {
    case accept
    case ignore
    /// No match yet: commit writes nothing at all, so the next receipt asks again.
    case unresolved
}

/// What commit remembers about a line — kitchen-wide and permanently, which is the point.
enum AliasWrite: Hashable, Sendable {
    case remember(ItemID)
    case forget

    var itemID: ItemID? {
        switch self {
        case .remember(let itemID): return itemID
        case .forget: return nil
        }
    }
}

struct CaptureMatch: Hashable, Sendable {
    let itemID: ItemID
    let name: String
    /// The seeded estimate for this item, or nil when the catalog has no seed for it.
    let estimate: Money?
    /// The name this match must teach the kitchen when it is priced — set only for an item
    /// minted here, which nothing else in the world names. nil for anything already named.
    var teaches: String? = nil
}

extension CaptureMatch {
    /// A remembered alias carries an id and no name, so the one name order resolves it.
    @MainActor
    init(remembered itemID: ItemID, kitchenNames: [ItemID: String], listName: String?,
         fallback: String, catalog: ListCatalog) {
        self.init(itemID: itemID,
                  name: catalog.displayName(for: itemID, kitchenNames: kitchenNames,
                                            listName: listName, fallback: fallback),
                  estimate: catalog.estimate(for: itemID))
    }
}

struct CaptureLine: Identifiable, Hashable, Sendable {
    let id: UUID
    let rawText: String
    /// Exactly what the line printed: minor units from `amount_minor`, never a parsed string.
    let amount: Money
    let quantity: Double
    let confidence: ScanConfidence
    /// The model's lowercase guess at the item, which is the resolver's opening query.
    let hint: String?
    var match: CaptureMatch?
    var decision: LineDecision
    var alias: AliasWrite?
    /// The match came from an alias this kitchen already wrote, not from a fresh guess.
    var isRemembered: Bool

    init(id: UUID = UUID(), rawText: String, amount: Money, quantity: Double,
         confidence: ScanConfidence, hint: String? = nil, match: CaptureMatch? = nil,
         decision: LineDecision = .unresolved, alias: AliasWrite? = nil,
         isRemembered: Bool = false) {
        self.id = id
        self.rawText = rawText
        self.amount = amount
        self.quantity = quantity
        self.confidence = confidence
        self.hint = hint
        self.match = match
        self.decision = decision
        self.alias = alias
        self.isRemembered = isRemembered
    }

    /// The price of ONE, which is the space the price book and the seeded estimate live in.
    /// Under one (0.5 lb) the printed amount stands: scaling it up would claim a per-unit
    /// price the receipt never printed.
    var unitAmount: Money {
        guard quantity > 1 else { return amount }
        return Money(minorUnits: Int((Double(amount.minorUnits) / quantity).rounded()),
                     currencyCode: amount.currencyCode)
    }

    /// How many `unitAmount` is the price of, so unit × count is the money this line printed.
    /// Under one it is ONE, because `unitAmount` kept the whole printed amount there — recording
    /// 0.5 against it would put half of what the till charged into the month's total.
    var unitCount: Double { quantity > 1 ? quantity : 1 }

    /// A multi-unit line shows what one cost, because that is the number being recorded.
    var showsEach: Bool { quantity > 1 }

    /// An amount of zero or less is not a price: a coupon is money off the receipt's total, and
    /// no arrangement of decisions can make it what one of something cost.
    var isMoneyOff: Bool { amount.minorUnits <= 0 }

    /// What such a line says instead of a price — never a number in the measured tier.
    var moneyOffText: String {
        guard amount.minorUnits < 0 else { return "no amount" }
        return Money(minorUnits: -amount.minorUnits, currencyCode: amount.currencyCode).display
            + " off"
    }

    var isPriced: Bool { decision == .accept && match != nil && !isMoneyOff }

    /// The gate: more than 3× the seeded estimate, named with both numbers. Compared against
    /// the estimate exactly as the app shows it (`~` rounds hard), so the sentence's two
    /// numbers are the two numbers it compared.
    var estimateFlag: String? {
        guard let estimate = match?.estimate,
              estimate.currencyCode == amount.currencyCode else { return nil }
        let usual = Money.estimate(from: estimate)
        guard usual.minorUnits > 0, unitAmount.minorUnits > 3 * usual.minorUnits else { return nil }
        let paid = showsEach ? "\(unitAmount.display) each" : unitAmount.display
        return "\(paid) — more than 3× the usual \(usual.display)"
    }
}

/// The close, in real counts.
struct CaptureResult: Hashable, Sendable {
    let lineCount: Int
    let matchedCount: Int
    let pricedCount: Int
    let ignoredCount: Int
    let rememberedCount: Int

    init(lines: [CaptureLine]) {
        lineCount = lines.count
        matchedCount = lines.filter { $0.match != nil }.count
        pricedCount = lines.filter(\.isPriced).count
        ignoredCount = lines.filter { $0.decision == .ignore }.count
        rememberedCount = lines.filter { $0.alias != nil }.count
    }

    /// "14 lines · 12 matched · every line became a price" — and that last clause only when
    /// every line really did, because a rounded flourish here is a lie about money.
    var summary: String {
        guard lineCount > 0 else { return "No lines on this receipt" }
        let head = "\(lineCount) \(lineCount == 1 ? "line" : "lines") · \(matchedCount) matched"
        guard pricedCount != lineCount else { return head + " · every line became a price" }
        return head + " · \(pricedCount) became \(pricedCount == 1 ? "a price" : "prices")"
    }
}
