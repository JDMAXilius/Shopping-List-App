import Core
import DesignKit
import SwiftUI

/// Screen 08 — the price book: what this kitchen pays, where, and how long ago.
struct PricesScreen: View {
    @Bindable var store: PriceStore
    let onCapture: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Prices")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.ink.color)
                search
                statsRow
                if store.isEmpty {
                    empty
                } else {
                    book
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Palette.paper.color)
        .navigationTitle("Prices")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { store.refresh() }
    }

    // MARK: - Header

    private var search: some View {
        TextField("", text: $store.query, prompt: Text("Find an item")
            .foregroundStyle(Palette.muted.color))
            .font(Typography.body)
            .foregroundStyle(Palette.ink.color)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.line.color))
            .accessibilityLabel("Find an item")
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard("\(store.stats.priceCount)", "prices")
            statCard(store.stats.receiptShare.map { "\($0)%" } ?? "—", "from receipts")
            statCard("\(store.stats.shopCount)", "shops")
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text(label)
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
        .accessibilityElement(children: .combine)
    }

    // MARK: - States

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmptyState(
                glyph: .other,
                message: "No prices here yet. One receipt fills this page — every line on it "
                    + "becomes a price you can look up.",
                actionTitle: "Scan a receipt",
                action: onCapture)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var book: some View {
        if !store.hasRecordedPrices {
            Notice("Everything here is the catalog's estimate. The + button turns one receipt "
                   + "into prices you actually paid.", on: .paper)
        }
        monthLink
        if !store.recent.isEmpty { section("RECENT", store.recent) }
        receiptsSection
        ForEach(store.aisles) { aisle in
            section(aisle.title, aisle.entries)
        }
        if store.isSearching, store.aisles.isEmpty {
            Text("Nothing matches “\(store.query)”.")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
        }
        unnamedNote
    }

    /// Not a decoration: an id the naming rule cannot answer for is a bug, and a silent drop
    /// would hide it. The row it belongs to is not invented from a UUID either.
    @ViewBuilder private var unnamedNote: some View {
        if store.unnamedCount > 0 {
            Notice("\(store.unnamedCount) recorded price\(store.unnamedCount == 1 ? "" : "s") "
                   + "can't be shown — we've lost the name of the item they belong to.",
                   tone: .attention, on: .paper)
        }
    }

    // MARK: - Sections

    private var monthLink: some View {
        let month = store.month
        let figure = PriceDerivation.figure(month.summary)
        return NavigationLink(value: Route.monthSpend) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(month.title)
                Spacer(minLength: 12)
                Text(figure)
                    .font(Typography.price)
                    .foregroundStyle(Palette.ink.color)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.muted.color)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(month.title), \(figure). Where it went.")
    }

    private func section(_ title: String, _ entries: [PriceBookEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(title)
            ForEach(entries) { entry in
                entryRow(entry)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    private func entryRow(_ entry: PriceBookEntry) -> some View {
        NavigationLink(value: Route.priceHistory(entry.itemID)) {
            HStack(spacing: 12) {
                GlyphTile(entry.category)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(Typography.itemName)
                        .foregroundStyle(Palette.ink.color)
                        .lineLimit(1)
                    Text(entry.detail)
                        .font(Typography.subtitle)
                        .foregroundStyle(Palette.muted.color)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                Spacer(minLength: 12)
                PriceLabel(entry.price)
                    .fixedSize()
                    .layoutPriority(2)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.name), \(entry.price.accessibilityPhrase), \(entry.detail)")
    }

    @ViewBuilder private var receiptsSection: some View {
        let rows = store.receiptRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("RECEIPTS")
                ForEach(rows) { row in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(Typography.itemName)
                                .foregroundStyle(Palette.ink.color)
                                .lineLimit(1)
                            Text(row.detail)
                                .font(Typography.subtitle)
                                .foregroundStyle(Palette.muted.color)
                        }
                        Spacer(minLength: 12)
                        // The till's own total, not a sum of lines — it is not a price tier.
                        Text(row.total.display)
                            .font(Typography.price)
                            .foregroundStyle(Palette.ink.color)
                    }
                    .frame(minHeight: 52)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
        }
    }
}
