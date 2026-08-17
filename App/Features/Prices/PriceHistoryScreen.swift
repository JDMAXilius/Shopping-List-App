import Core
import DesignKit
import SwiftUI

/// Screen 09 — one item over time, per shop, dated. Deltas are stated in ink: a price going
/// up is information, not a failure (PRODUCT §2 bans valuative colour on money).
struct PriceHistoryScreen: View {
    /// What sits below the current price. `estimateOnly` is the case that keeps this honest:
    /// an item nothing has priced has no history to withhold, so no gate is advertised over it.
    enum Shown: Equatable {
        case estimateOnly
        case full
        case plus
        case unavailable(String)
    }

    let store: PriceStore
    let itemID: ItemID
    let subscription: SubscriptionStore
    @Binding var sheet: Sheet?

    /// The current price is free wherever it appears — the list and the price book already show
    /// it. What Plus buys is every dated price, and what each shop charged (PRODUCT §6).
    static func shown(entries: Int, shops: Int, gate: Gate) -> Shown {
        guard entries > 0 || shops > 0 else { return .estimateOnly }
        switch gate {
        case .allowed: return .full
        case .paywall: return .plus
        case .unavailable(let sentence): return .unavailable(sentence)
        }
    }

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
        switch Self.shown(entries: history.entries.count, shops: history.shops.count,
                          gate: subscription.gate(.priceHistory)) {
        case .estimateOnly:
            Notice("No receipt has priced this yet — the figure above is the catalog's estimate.",
                   on: .paper)
        case .full:
            fullHistory(history)
        case .plus:
            plusSection
        // A joiner is told what this is and what stays theirs. No price, no offer, no button.
        case .unavailable(let sentence):
            Notice(sentence, on: .paper)
        }
    }

    @ViewBuilder private func fullHistory(_ history: ItemHistory) -> some View {
        if !history.shops.isEmpty { shopSection(history.shops) }
        if !history.entries.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("EVERY PRICE")
                ForEach(history.entries) { entry in
                    row(entry)
                }
            }
            Notice("Prices accumulate — new receipts never erase old ones.", on: .paper)
        }
    }

    /// Names the gate before the tap and sends the tap to the one screen that carries the price.
    /// A gate that hides what it costs is the dark pattern this project bans.
    private var plusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("EVERY PRICE")
            Text(Self.plusSentence)
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
            Button { sheet = .paywall } label: {
                Text("See what Plus costs")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.persimmon.color)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    static let plusSentence = "Every dated price for this item, and what each shop charged, is "
        + "part of Bagged Plus. The price above stays free, and nothing you've recorded is "
        + "deleted — it's all in your export."

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
