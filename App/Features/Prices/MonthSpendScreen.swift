import Core
import DesignKit
import SwiftUI

/// Screen 10 — what the month cost, from the tills' own totals. No goal, no budget, no streak:
/// the number is stated and left alone (PRODUCT §2 bans guilt mechanics).
///
/// Two quantities live here and are never mixed: what was PAID (receipt totals, the headline)
/// and what was MATCHED to items (price observations, the aisle breakdown). The second is
/// smaller than the first by the tax, fees and unmatched lines, and it says so.
struct MonthSpendScreen: View {
    let store: PriceStore

    var body: some View {
        let month = store.month
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if month.paid.hasReceipts || month.matched.hasPricedItems {
                    headline(month)
                    if month.bars.count > 1 { bars(month.bars) }
                    if !month.aisles.isEmpty { whereItWent(month) }
                    if month.matched.hasPricedItems { honesty(month) }
                    shopsLine(month.shops)
                } else {
                    Notice("Nothing has been recorded in \(month.title) yet. A receipt is what "
                           + "puts a month here.", on: .paper)
                }
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The figure and what it is built from, together — `PaidTotalLabel` will not render one
    /// without the other, so no version of this screen can imply a completeness it lacks.
    private func headline(_ month: MonthSpend) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(month.title)
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.ink.color)
            PaidTotalLabel(month.paid)
            if let delta = month.deltaText {
                // Ink. A month costing more is information, not a failure.
                Text(delta)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func bars(_ bars: [MonthBar]) -> some View {
        let tallest = max(bars.map(\.paid.total.minorUnits).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 16) {
            ForEach(bars) { bar in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill((bar.isCurrent ? Palette.persimmon : Palette.line).color)
                        .frame(width: 56,
                               height: max(8, 120 * Double(bar.paid.total.minorUnits) / Double(tallest)))
                    Text(bar.label)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                    Text(bar.paid.figure)
                        .font(Typography.priceSmall)
                        .foregroundStyle(Palette.muted.color)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(bar.label), \(bar.paid.figure)")
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    /// Aisle rows are a breakdown of the MATCHED lines, not of the money paid — the caption
    /// says which, because these bars can never add up to the headline.
    private func whereItWent(_ month: MonthSpend) -> some View {
        let aisles = month.aisles
        let widest = max(aisles.map(\.summary.total.minorUnits).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("WHERE IT WENT")
            Text(month.coverageText)
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(aisles) { aisle in
                HStack(spacing: 12) {
                    // The column is fixed so every bar starts at the same x — that alignment
                    // is what makes them readable as a chart. But a fixed width with one line
                    // truncated "Dairy & Eggs" to "Dairy & Eg…", and an aisle whose name is
                    // cut is an aisle the reader has to guess at. Two lines, wrapped at a
                    // word: the alignment is kept and nothing is cut.
                    Text(aisle.title)
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink.color)
                        .lineLimit(2)
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

    /// What the breakdown is built from: a till's own line, or something typed in afterwards.
    /// Both are counted off the same summary the aisle rows came from, so they cannot disagree.
    private func honesty(_ month: MonthSpend) -> some View {
        let matched = month.matched
        let priced = max(matched.measuredCount + matched.estimatedCount, 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("How real is this?")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.ink.color)
            Text("\(month.matchedFromReceipts) of \(priced) matched price"
                 + "\(priced == 1 ? "" : "s") came from a receipt"
                 + (matched.estimatedCount > 0
                     ? " · \(matched.estimatedCount) over 90 days old, an estimate again" : ""))
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line.color)
                    // Green states a fact — this part was printed by a till — never decoration.
                    Capsule().fill(Palette.confirmed.color)
                        .frame(width: proxy.size.width
                               * Double(month.matchedFromReceipts) / Double(priced))
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func shopsLine(_ shops: [ShopSpend]) -> some View {
        if !shops.isEmpty {
            Text(shops.prefix(4).map { "\($0.title) \($0.paid.figure)" }.joined(separator: " · "))
                .font(Typography.priceSmall)
                .foregroundStyle(Palette.muted.color)
        }
    }
}
