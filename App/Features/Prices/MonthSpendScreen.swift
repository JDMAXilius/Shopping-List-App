import Core
import DesignKit
import SwiftUI

/// Screen 10 — this month against the user's own usual. No goal, no budget, no streak:
/// the number is stated and left alone (PRODUCT §2 bans guilt mechanics).
struct MonthSpendScreen: View {
    let store: PriceStore

    var body: some View {
        let month = store.month
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headline(month)
                if month.summary.hasPricedItems {
                    if month.bars.count > 1 { bars(month.bars) }
                    whereItWent(month.aisles)
                    honesty(month)
                    shopsLine(month.shops)
                } else {
                    Notice("Nothing has been priced in \(month.title) yet. A receipt is what "
                           + "puts a month here.", on: .paper)
                }
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headline(_ month: MonthSpend) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(month.title)
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.ink.color)
            Text(PriceDerivation.figure(month.summary))
                .font(Typography.total)
                .foregroundStyle(Palette.ink.color)
            if let delta = month.deltaText {
                // Ink. A month costing more is information, not a failure.
                Text(delta)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
            }
            Text(context(month))
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
        .accessibilityElement(children: .combine)
    }

    /// What the figure is made of, in the open: it counts priced lines, not till totals.
    private func context(_ month: MonthSpend) -> String {
        let prices = month.summary.measuredCount + month.summary.estimatedCount
        let receipts = month.receiptCount
        let lines = "\(prices) price\(prices == 1 ? "" : "s")"
        guard receipts > 0 else { return "\(lines) recorded" }
        return "\(lines) · \(receipts) receipt\(receipts == 1 ? "" : "s")"
    }

    private func bars(_ bars: [MonthBar]) -> some View {
        let tallest = max(bars.map(\.summary.total.minorUnits).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 16) {
            ForEach(bars) { bar in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill((bar.isCurrent ? Palette.persimmon : Palette.line).color)
                        .frame(width: 56,
                               height: max(8, 120 * Double(bar.summary.total.minorUnits) / Double(tallest)))
                    Text(bar.label)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                    Text(PriceDerivation.figure(bar.summary))
                        .font(Typography.priceSmall)
                        .foregroundStyle(Palette.muted.color)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(bar.label), \(PriceDerivation.figure(bar.summary))")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    private func whereItWent(_ aisles: [MonthGroup]) -> some View {
        let widest = max(aisles.map(\.summary.total.minorUnits).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("WHERE IT WENT")
            ForEach(aisles) { aisle in
                HStack(spacing: 12) {
                    Text(aisle.title)
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink.color)
                        .lineLimit(1)
                        .frame(width: 92, alignment: .leading)
                    Capsule()
                        .fill((aisle.tint ?? Palette.line).color)
                        .frame(width: 120 * Double(aisle.summary.total.minorUnits) / Double(widest),
                               height: 10)
                    Spacer(minLength: 8)
                    Text(PriceDerivation.figure(aisle.summary))
                        .font(Typography.priceSmall)
                        .foregroundStyle(Palette.ink.color)
                }
                .frame(minHeight: 32)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(aisle.title), \(PriceDerivation.figure(aisle.summary))")
            }
        }
    }

    /// What the month is built from: a till's own line, or something typed in afterwards.
    /// Both are counted off the same summary the total came from, so they cannot disagree.
    private func honesty(_ month: MonthSpend) -> some View {
        let summary = month.summary
        let priced = max(summary.measuredCount + summary.estimatedCount, 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("How real is this?")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.ink.color)
            Text("\(month.fromReceipts) of \(priced) came from a receipt"
                 + (summary.estimatedCount > 0
                     ? " · \(summary.estimatedCount) over 90 days old, an estimate again" : ""))
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line.color)
                    // Green states a fact — this part was printed by a till — never decoration.
                    Capsule().fill(Palette.confirmed.color)
                        .frame(width: proxy.size.width * Double(month.fromReceipts) / Double(priced))
                }
            }
            .frame(height: 8)
            Text("This counts the prices recorded in \(month.title) — not the trips that were "
                 + "never captured.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func shopsLine(_ shops: [MonthGroup]) -> some View {
        if !shops.isEmpty {
            Text(shops.prefix(4).map { "\($0.title) \(PriceDerivation.figure($0.summary))" }
                .joined(separator: " · "))
                .font(Typography.priceSmall)
                .foregroundStyle(Palette.muted.color)
        }
    }
}
