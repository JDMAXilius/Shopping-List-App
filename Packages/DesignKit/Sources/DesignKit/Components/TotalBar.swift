import SwiftUI
import Core

/// The double-ruled total (A·Ledger's organ). Everything — sum, `≈`, breakdown —
/// derives from one `[PriceDisplay]` (W4-C1 fix 2): a total that disagrees with its
/// own breakdown is unrepresentable. No loose counts cross this API.
public struct TotalBar: View {
    private let summary: PriceSummary

    public init(prices: [PriceDisplay]) {
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
                Text((summary.isApproximate ? "≈ " : "") + summary.total.display)
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

    /// "3 estimated · 1 no price yet" — the total breaks itself down, always honest.
    private var breakdown: String? {
        var parts: [String] = []
        if summary.estimatedCount > 0 { parts.append("\(summary.estimatedCount) estimated") }
        if summary.unpricedCount > 0 {
            parts.append("\(summary.unpricedCount) no price yet")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var accessibilityText: String {
        let figure = "\(summary.isApproximate ? "about " : "")\(summary.total.display) total"
        return breakdown.map { "\(figure), \($0)" } ?? figure
    }
}
