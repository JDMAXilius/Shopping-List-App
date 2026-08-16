import SwiftUI
import Core

/// The three price tiers, never confusable (PRODUCT.md §2 row anatomy).
/// Opaque by design (W4-C1 fix 1): `.measured` is unreachable except through a
/// `PriceObservation.Confidence` — a caller holding a cached bare `Money` cannot
/// render it as solid ink. Public surface: the confidence init, `.estimated`, `.none`.
public struct PriceDisplay: Hashable, Sendable {
    enum Tier: Hashable, Sendable {
        case measured(Money)
        case estimated(Money)
        case none
    }

    let tier: Tier

    private init(_ tier: Tier) { self.tier = tier }

    /// The only path to a measured (solid-ink) price. >90-day observations have
    /// demoted themselves to estimates via Core's confidence.
    public init(amount: Money, confidence: PriceObservation.Confidence) {
        switch confidence {
        case .trusted, .dated: self.init(.measured(amount))
        case .estimate: self.init(.estimated(amount))
        }
    }

    /// An estimate is always constructible — honesty downward is free.
    public static func estimated(_ money: Money) -> PriceDisplay {
        PriceDisplay(.estimated(money))
    }

    public static let none = PriceDisplay(.none)

    /// The ONE VoiceOver phrase for a price (W4-C1 fix 7) — PriceLabel and ItemRow
    /// both read it from here, so the spoken price can never fork.
    public var accessibilityPhrase: String {
        switch tier {
        case .measured(let money): return money.display
        case .estimated(let money): return "about \(Money.estimate(from: money).display), estimated"
        case .none: return "no price yet"
        }
    }

    /// What this row puts in the trolley: the price of ONE times how many the list says.
    /// The row goes on showing the unit price — that is what a person compares between
    /// shops — and totals sum these (W8-P5 ruling 1).
    ///
    /// Scaling changes the amount and NEVER the tier: four measured items at $3.50 is
    /// $14.00 measured. The estimate grid is applied to the unit FIRST and the line total
    /// is never re-rounded (ruling 3), because `~$4.50` is what the row showed and half of
    /// what was shown is $2.25 — re-rounding would say ~$2.50, and rounding after the
    /// multiply would say $2.00. Neither is a figure anything on screen supports.
    public func line(quantity: Double) -> PriceLine {
        switch tier {
        case .measured(let money):
            return PriceLine(tier: .measured(PriceDisplay.scaled(money, by: quantity)))
        case .estimated(let money):
            return PriceLine(tier: .estimated(
                PriceDisplay.scaled(Money.estimate(from: money), by: quantity)))
        case .none:
            return PriceLine(tier: .none)
        }
    }

    /// Integer minor units wherever it can be: a whole count multiplies exactly, and only a
    /// genuine fraction (1.5 lb) rounds — once, to the nearest minor unit.
    static func scaled(_ money: Money, by quantity: Double) -> Money {
        // Not a positive finite number is not a basket; the price of one stands rather than
        // a total inventing or erasing money over a quantity nothing can read.
        guard quantity.isFinite, quantity > 0 else { return money }
        if quantity == quantity.rounded(), quantity <= 100_000 {
            return money.multiplied(by: Int(quantity))
        }
        return Money(minorUnits: Int((Double(money.minorUnits) * quantity).rounded()),
                     currencyCode: money.currencyCode)
    }
}

/// One row's contribution to a total, and the ONLY thing `PriceSummary` will add up.
/// Made solely by `PriceDisplay.line(quantity:)`, so a total built from prices of one —
/// which is what every total in this app was until W8-P5, ×4 milk at $3.50 reading $3.50 —
/// cannot be written. It carries no readable money: a scaled estimate must never find its
/// way to a label that would draw it in solid ink.
public struct PriceLine: Hashable, Sendable {
    let tier: PriceDisplay.Tier
}

/// One derived truth for any group of rows (W4-C1 fixes 2–3): sum, counts and the `≈`
/// decision all come from the same `[PriceLine]` — the only initializer — so a total that
/// disagrees with its breakdown is unrepresentable. Loose ints don't exist, and neither do
/// prices of one: a caller reaches a total only through `PriceDisplay.line(quantity:)`.
/// The counts are counts of ROWS, which is what the breakdown says out loud.
public struct PriceSummary: Hashable, Sendable {
    public let total: Money
    public let measuredCount: Int
    public let estimatedCount: Int
    public let unpricedCount: Int

    public init(_ lines: [PriceLine]) {
        var minor = 0
        var currency: String?
        var measured = 0, estimated = 0, unpriced = 0
        for line in lines {
            switch line.tier {
            case .measured(let money):
                measured += 1
                minor += money.minorUnits
                currency = currency ?? money.currencyCode
            case .estimated(let money):
                // Already on the grid and already scaled — `line(quantity:)` rounded the UNIT.
                // Rounding here again would make ½ × ~$4.50 read ~$2.50 instead of $2.25.
                estimated += 1
                minor += money.minorUnits
                currency = currency ?? money.currencyCode
            case .none:
                unpriced += 1
            }
        }
        total = Money(minorUnits: minor, currencyCode: currency ?? "USD")
        measuredCount = measured
        estimatedCount = estimated
        unpricedCount = unpriced
    }

    /// Any estimate or gap makes the figure approximate — `≈` is never caller-supplied.
    public var isApproximate: Bool { estimatedCount > 0 || unpricedCount > 0 }

    /// True when nothing in the group carries a price at all.
    public var hasPricedItems: Bool { measuredCount > 0 || estimatedCount > 0 }

    /// The figure, marked. Three surfaces had each written this string themselves — the widget's
    /// tile, TotalBar and the list's arrival line — which is the exact fork this type exists to
    /// make impossible. It lives here now, and they read it.
    public var display: String { (isApproximate ? "≈ " : "") + total.display }

    /// "3 estimated · 1 no price yet" — what makes the figure honest, and the reason a surface
    /// with no room for it must not show the figure at all.
    public var breakdown: String? {
        var parts: [String] = []
        if estimatedCount > 0 { parts.append("\(estimatedCount) estimated") }
        if unpricedCount > 0 { parts.append("\(unpricedCount) no price yet") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// `≈` is not a word. The figure as it is said — in a sentence, or out loud.
    public var spokenTotal: String { (isApproximate ? "about " : "") + total.display }

    /// One phrase, so a total can never be read aloud two ways.
    public var accessibilityPhrase: String {
        breakdown.map { "\(spokenTotal) total, \($0)" } ?? "\(spokenTotal) total"
    }
}

/// THE way a price renders — `$4.49` solid ink · `~$5.00` lighter + muted · `—` none.
/// Monospace tabular always; no initializer takes a bare number, so callers cannot
/// render a price outside the three tiers. Never colour alone: `~` + weight + colour.
public struct PriceLabel: View {
    private let display: PriceDisplay
    private let size: PriceSize

    /// `size` scales the type only (W7-P3): the hero figures on price history and month spend
    /// render at `.display` through THIS view, so the three tiers keep one implementation.
    public init(_ display: PriceDisplay, size: PriceSize = .body) {
        self.display = display
        self.size = size
    }

    public var body: some View {
        switch display.tier {
        case .measured(let money):
            text(money.display, font: size.measuredFont, colour: Palette.ink)
        case .estimated(let money):
            // Money.estimateDisplay supplies the `~` and the half-unit rounding.
            text(money.estimateDisplay, font: size.estimatedFont, colour: Palette.muted)
        case .none:
            text("—", font: size.estimatedFont, colour: Palette.muted)
        }
    }

    private func text(_ string: String, font: Font, colour: Palette.RGB) -> some View {
        Text(string)
            .font(font)
            .foregroundStyle(colour.color)
            // Only the hero is width-critical, and only it is allowed to shrink — a row
            // price keeps the layout it had (its callers give it `fixedSize`).
            .lineLimit(size == .display ? 1 : nil)
            .minimumScaleFactor(size.minimumScale)
            .accessibilityLabel(display.accessibilityPhrase)
    }
}
