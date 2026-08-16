import Core
import SwiftUI

/// What one till printed and one person handed over. The ONLY thing `PaidSummary` sums:
/// a per-item price cannot become one by accident, and the label says what the claim is.
public struct ReceiptTotal: Hashable, Sendable {
    public let amount: Money

    public init(printedOnReceipt amount: Money) {
        self.amount = amount
    }
}

/// Money actually paid (W7-P3 ruling 1). Deliberately NOT interchangeable with `PriceSummary`:
/// that one sums the lines we could match to items, this one sums till totals, and the two are
/// different quantities. Neither initializer accepts the other's input, so a call site cannot
/// present one as the other.
///
/// A total here is a FLOOR — it can only know the trips that were captured. That is stated in
/// words (`basis`), never in a symbol: `≈` means "contains an estimate", and every part of this
/// figure is exact.
public struct PaidSummary: Hashable, Sendable {
    public let total: Money
    /// Captured trips. The screen states it because a receipt-based total is only as complete
    /// as the scanning was.
    public let receiptCount: Int
    /// Names the span this covers, worded to read after "in": "July", "the last 7 days".
    public let period: String

    public init(_ receipts: [ReceiptTotal], in period: String, currencyCode: String) {
        var minor = 0
        var currency: String?
        for receipt in receipts {
            minor += receipt.amount.minorUnits
            currency = currency ?? receipt.amount.currencyCode
        }
        total = Money(minorUnits: minor, currencyCode: currency ?? currencyCode)
        receiptCount = receipts.count
        self.period = period
    }

    public var hasReceipts: Bool { receiptCount > 0 }

    /// `—` with nothing captured: `$0.00` would be a claim that nothing was spent.
    public var figure: String { hasReceipts ? total.display : "—" }

    /// What the number is built from and what it therefore cannot include, in one plain
    /// sentence a person reads once. Not a disclaimer — it sits with the number.
    public var basis: String {
        guard hasReceipts else {
            return "No receipts captured in \(period), so there is no total to state."
        }
        return "From \(receiptCount) receipt\(receiptCount == 1 ? "" : "s") captured in "
            + "\(period). A trip you didn't scan isn't in this number."
    }

    public var accessibilityPhrase: String {
        hasReceipts ? "\(total.display). \(basis)" : basis
    }
}

/// THE way a paid total renders — the figure and the sentence that qualifies it, together,
/// as one thing. Callers get no way to show the number without its basis (ruling 2).
/// Solid ink: a till total is a fact, not a guess.
public struct PaidTotalLabel: View {
    private let summary: PaidSummary
    private let size: PriceSize

    public init(_ summary: PaidSummary, size: PriceSize = .display) {
        self.summary = summary
        self.size = size
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.figure)
                .font(size.measuredFont)
                .foregroundStyle(Palette.ink.color)
                .lineLimit(1)
                .minimumScaleFactor(size.minimumScale)
            Text(summary.basis)
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityPhrase)
    }
}
