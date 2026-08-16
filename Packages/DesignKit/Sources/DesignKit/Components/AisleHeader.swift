import SwiftUI
import Core

/// Aisle section header: letterspaced uppercase label + per-aisle subtotal right.
/// Collapsed variant: `✓ PRODUCE · done (2) · ≈ $11.40` — the green tick is the only
/// green here, and it means done. Subtotal and `≈` derive from the aisle's own
/// `[PriceLine]` (W4-C1 fix 3): estimates AND unpriced gaps both make it
/// approximate — the same honesty rule as TotalBar, never a caller flag. Since W8-P5 the
/// subtotal counts what the aisle actually holds: `[PriceLine]`, quantity included.
public struct AisleHeader: View {
    private let title: String
    private let summary: PriceSummary
    private let doneCount: Int
    private let isCollapsed: Bool

    public init(
        title: String,
        prices: [PriceLine],
        doneCount: Int = 0,
        isCollapsed: Bool = false
    ) {
        self.init(
            title: title, summary: PriceSummary(prices),
            doneCount: doneCount, isCollapsed: isCollapsed)
    }

    /// Convenience for callers already holding the one derived value — never loose ints.
    public init(
        title: String,
        summary: PriceSummary,
        doneCount: Int = 0,
        isCollapsed: Bool = false
    ) {
        self.title = title
        self.summary = summary
        self.doneCount = doneCount
        self.isCollapsed = isCollapsed
    }

    /// No subtotal at all when nothing in the aisle carries a price — `≈ $0.00` would lie.
    private var subtotal: Money? { summary.hasPricedItems ? summary.total : nil }

    private var approxPrefix: String { summary.isApproximate ? "≈ " : "" }

    public var body: some View {
        Group {
            if isCollapsed {
                collapsed
            } else {
                expanded
            }
        }
        .frame(minHeight: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isHeader)
    }

    private var expanded: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(title)
            Spacer(minLength: 12)
            if let subtotal {
                Text(approxPrefix + subtotal.display)
                    .font(Typography.priceSmall)
                    .foregroundStyle(Palette.muted.color)
            }
        }
    }

    private var collapsed: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(.caption, weight: .bold))
                .foregroundStyle(Palette.confirmed.color)
            SectionLabel(title)
            Text("· done (\(doneCount)) ·")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
            if let subtotal {
                Text(approxPrefix + subtotal.display)
                    .font(Typography.priceSmall)
                    .foregroundStyle(Palette.muted.color)
            }
            Spacer(minLength: 0)
        }
    }

    private var accessibilityText: String {
        var text = title
        if isCollapsed { text += ", done, \(doneCount) items" }
        if let subtotal {
            text += summary.isApproximate
                ? ", about \(subtotal.display)" : ", \(subtotal.display)"
        }
        return text
    }
}
