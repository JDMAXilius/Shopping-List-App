import Core
import DesignKit
import SwiftUI

/// Screen 09 — one item over time, per shop, dated. Deltas are stated in ink: a price going
/// up is information, not a failure (PRODUCT §2 bans valuative colour on money).
struct PriceHistoryScreen: View {
    let store: PriceStore
    let itemID: ItemID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let history = store.history(for: itemID) {
                    content(history)
                } else {
                    EmptyState(
                        glyph: .other,
                        message: "We can't show this item's prices — its name is missing.")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func content(_ history: ItemHistory) -> some View {
        HStack(spacing: 12) {
            GlyphTile(history.category)
            Text(history.name)
                .font(.system(.title, weight: .bold))
                .foregroundStyle(Palette.ink.color)
        }
        VStack(alignment: .leading, spacing: 2) {
            PriceLabel(history.headline, size: .display)
            Text(history.headlineDetail)
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
        .accessibilityElement(children: .combine)
        if !history.shops.isEmpty { shopSection(history.shops) }
        if history.entries.isEmpty {
            Notice("No receipt has priced this yet — the figure above is the catalog's estimate.",
                   on: .paper)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("EVERY PRICE")
                ForEach(history.entries) { entry in
                    row(entry)
                }
            }
            Notice("Prices accumulate — new receipts never erase old ones.", on: .paper)
        }
    }

    /// The comparison people actually want: the same item, each shop's latest, side by side.
    private func shopSection(_ shops: [ShopComparison]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("AT EACH SHOP")
            ForEach(shops) { shop in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shop.shopName)
                            .font(Typography.itemName)
                            .foregroundStyle(Palette.ink.color)
                            .lineLimit(1)
                        Text(shop.detail)
                            .font(Typography.subtitle)
                            .foregroundStyle(Palette.muted.color)
                    }
                    Spacer(minLength: 12)
                    PriceLabel(shop.price)
                }
                .frame(minHeight: 48)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(shop.shopName), \(shop.price.accessibilityPhrase), \(shop.detail)")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    private func row(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                PriceLabel(entry.price)
                    .fixedSize()
                Text(entry.detail)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                Spacer(minLength: 0)
            }
            if let delta = entry.delta {
                // Ink, never red or green: the number is the whole statement.
                Text(delta)
                    .font(Typography.priceSmall)
                    .foregroundStyle(Palette.ink.color)
            }
            if let note = entry.note {
                Text(note)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([entry.price.accessibilityPhrase, entry.detail, entry.delta, entry.note]
            .compactMap { $0 }.joined(separator: ", "))
    }
}
