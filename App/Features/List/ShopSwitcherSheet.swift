import Core
import DesignKit
import Foundation
import SwiftUI

struct ShopSwitcherSheet: View {
    let store: ListStore

    @State private var newShopName = ""
    @State private var isAdding = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // No shops yet: the contextual first-shop step, right here, not a separate flow.
            if store.shops.isEmpty || isAdding {
                firstShopPrompt
            } else {
                switcher
            }
        }
        .padding(16)
        .background(Palette.paper.color)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var switcher: some View {
        VStack(spacing: 12) {
            Text("Shopping where?")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.shops, id: \.id) { shop in
                        row(shop)
                    }
                }
            }
            Button { isAdding = true } label: {
                Text("+ Add a shop")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.persimmon.color)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.card.color))
            }
            .buttonStyle(.plain)
            Text("Aisle order and prices follow the shop.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
    }

    private func row(_ shop: Shop) -> some View {
        Button {
            store.switchShop(shop.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                GlyphTile(emoji: "📍")
                VStack(alignment: .leading, spacing: 2) {
                    Text(shop.name)
                        .font(Typography.itemName)
                        .foregroundStyle(Palette.ink.color)
                    Text(subtitle(shop))
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                }
                Spacer(minLength: 12)
                if shop.id == store.activeShopID {
                    Image(systemName: "checkmark.circle")
                        .font(.system(.title3))
                        .foregroundStyle(Palette.persimmon.color)
                }
            }
            .padding(12)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
        }
        .buttonStyle(.plain)
    }

    private func subtitle(_ shop: Shop) -> String {
        var parts = ["\(store.measuredCount(at: shop.id)) of \(store.rows.count) priced"]
        if store.hasAisleOrder(shop.id) { parts.append("aisle order saved") }
        return parts.joined(separator: " · ")
    }

    private var firstShopPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where do you usually shop?")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text("Aisle order and prices are saved per shop.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
            TextField("Shop name", text: $newShopName)
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.card.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Palette.line.color, lineWidth: 1)))
                .onSubmit(save)
            Button(action: save) {
                Text("Continue")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
            .opacity(trimmed.isEmpty ? 0.4 : 1)
            Button("Skip for now") { dismiss() }
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var trimmed: String { newShopName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmed.isEmpty else { return }
        store.addShop(named: trimmed)
        dismiss()
    }
}
