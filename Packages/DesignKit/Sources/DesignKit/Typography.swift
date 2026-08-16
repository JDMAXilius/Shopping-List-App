import SwiftUI

// System sans everywhere EXCEPT prices — prices and totals are monospace, tabular,
// always (PRODUCT.md §2). Every style is relative (Dynamic Type), never a fixed size.
public enum Typography {

    // MARK: Text — system sans

    public static var screenTitle: Font { .system(.largeTitle, design: .default, weight: .bold) }
    public static var itemName: Font { .system(.body, design: .default, weight: .regular) }
    public static var subtitle: Font { .system(.footnote, design: .default, weight: .regular) }
    public static var body: Font { .system(.body) }
    public static var footnote: Font { .system(.footnote) }

    /// Letterspaced small labels (aisle headers, `TOTAL`). **Use `SectionLabel`, not this** —
    /// the font is only half the treatment, and composing the other half inline is what put
    /// six copies of the persimmon-contrast rule in the app (W6-P1).
    public static var sectionLabel: Font { .system(.caption, design: .default, weight: .semibold) }
    public static let labelTracking: CGFloat = 1.2

    // MARK: Prices — monospace, tabular numerals

    public static var price: Font { PriceSize.body.measuredFont }

    /// Estimates render lighter than measured prices — weight is part of the honesty tier.
    public static var priceEstimated: Font { PriceSize.body.estimatedFont }

    public static var priceSmall: Font { PriceSize.small.estimatedFont }

    /// Small AND measured — the heavier half of the tier pair at footnote size.
    public static var priceSmallMeasured: Font { PriceSize.small.measuredFont }

    /// The hero figure on a screen whose subject IS the number (month spend, item history).
    public static var priceDisplay: Font { PriceSize.display.measuredFont }

    public static var priceDisplayEstimated: Font { PriceSize.display.estimatedFont }

    public static var total: Font {
        Font.system(.title3, design: .monospaced, weight: .semibold).monospacedDigit()
    }
}

/// How big a price renders (W7-P3 ruling 4). NOT a style variant and NOT a tier: the honesty
/// tiers (solid ink vs `~` + muted) live only in `PriceLabel` and are identical at every size.
/// This exists so a screen that needs a bigger hero asks for one instead of re-implementing
/// the tiers locally — which would fork the one rendering that must never fork.
public enum PriceSize: Hashable, Sendable, CaseIterable {
    /// Chart labels and dense secondary rows.
    case small
    /// The default — a list row's price.
    case body
    /// The one number a screen exists to state (`design/app/09` and `/10` hero figures).
    case display

    /// Relative, never a point size — every tier survives Dynamic Type.
    public var textStyle: Font.TextStyle {
        switch self {
        case .small: return .footnote
        case .body: return .body
        case .display: return .largeTitle
        }
    }

    public var measuredWeight: Font.Weight {
        switch self {
        case .small, .body: return .medium
        case .display: return .bold
        }
    }

    /// Always lighter than `measuredWeight` at the same size — weight is half the tier, and
    /// an estimate that renders as heavy as a measured price has lost its lighter half.
    public var estimatedWeight: Font.Weight { .regular }

    /// A truncated figure is a WRONG figure (`$284.6…`). At display size the hero shrinks to
    /// stay whole under the largest Dynamic Type; smaller sizes lay out as they always did.
    var minimumScale: CGFloat { self == .display ? 0.5 : 1 }

    var measuredFont: Font { font(measuredWeight) }
    var estimatedFont: Font { font(estimatedWeight) }

    private func font(_ weight: Font.Weight) -> Font {
        Font.system(textStyle, design: .monospaced, weight: weight).monospacedDigit()
    }
}
