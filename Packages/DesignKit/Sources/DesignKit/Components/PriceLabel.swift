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
}

/// One derived truth for any group of prices (W4-C1 fixes 2–3): sum, counts and the
/// `≈` decision all come from the same `[PriceDisplay]` — the only initializer — so a
/// total that disagrees with its breakdown is unrepresentable. Loose ints don't exist.
public struct PriceSummary: Hashable, Sendable {
    public let total: Money
    public let measuredCount: Int
    public let estimatedCount: Int
    public let unpricedCount: Int

    public init(_ prices: [PriceDisplay]) {
        var minor = 0
        var currency: String?
        var measured = 0, estimated = 0, unpriced = 0
        for price in prices {
            switch price.tier {
            case .measured(let money):
                measured += 1
                minor += money.minorUnits
                currency = currency ?? money.currencyCode
            case .estimated(let money):
                // Sum the display-rounded value — the visible ledger must add up.
                estimated += 1
                minor += Money.estimate(from: money).minorUnits
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
