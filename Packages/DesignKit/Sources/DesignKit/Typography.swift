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

    /// Letterspaced small labels (aisle headers, `TOTAL`); apply `labelTracking` alongside.
    public static var sectionLabel: Font { .system(.caption, design: .default, weight: .semibold) }
    public static let labelTracking: CGFloat = 1.2

    // MARK: Prices — monospace, tabular numerals

    public static var price: Font {
        Font.system(.body, design: .monospaced, weight: .medium).monospacedDigit()
    }

    /// Estimates render lighter than measured prices — weight is part of the honesty tier.
    public static var priceEstimated: Font {
        Font.system(.body, design: .monospaced, weight: .regular).monospacedDigit()
    }

    public static var priceSmall: Font {
        Font.system(.footnote, design: .monospaced, weight: .regular).monospacedDigit()
    }

    public static var total: Font {
        Font.system(.title3, design: .monospaced, weight: .semibold).monospacedDigit()
    }
}
