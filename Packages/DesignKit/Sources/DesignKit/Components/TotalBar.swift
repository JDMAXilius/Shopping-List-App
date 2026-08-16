import SwiftUI
import Core

/// The double-ruled total (A·Ledger's organ). Everything — sum, `≈`, breakdown —
/// derives from one `[PriceLine]` (W4-C1 fix 2, W8-P5 ruling 2): a total that disagrees
/// with its own breakdown is unrepresentable, and so is one built from prices of ONE.
/// No loose counts cross this API.
public struct TotalBar: View {
    private let summary: PriceSummary

    /// Still labelled `prices:` — these ARE the rows' prices, each carrying the quantity
    /// the list says. `PriceDisplay.line(quantity:)` is the only way to make one.
    public init(prices: [PriceLine]) {
        self.init(summary: PriceSummary(prices))
    }

    /// Convenience for callers already holding the one derived value — never loose ints.
    public init(summary: PriceSummary) {
        self.summary = summary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            doubleRule
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel("TOTAL")
                    if let breakdown {
                        Text(breakdown)
                            .font(Typography.footnote)
                            .foregroundStyle(Palette.muted.color)
                    }
                }
                Spacer(minLength: 12)
                Text(summary.display)
                    .font(Typography.total)
                    .foregroundStyle(Palette.ink.color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var doubleRule: some View {
        VStack(spacing: 2) {
            Rectangle().fill(Palette.ink.color).frame(height: 2)
            Rectangle().fill(Palette.ink.color).frame(height: 1)
        }
    }

    private var breakdown: String? { summary.breakdown }

    private var accessibilityText: String { summary.accessibilityPhrase }
}
