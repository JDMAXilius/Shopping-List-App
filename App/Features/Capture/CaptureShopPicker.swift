import Core
import DesignKit
import SwiftUI

/// The capture flow's shop picker. It RETURNS a choice and touches nothing else: filing a
/// receipt must not re-point the list, and swiping this away must change nothing at all.
struct CaptureShopPicker: View {
    let store: ListStore
    let chosen: ShopID?
    let onChoose: (ShopID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if store.shops.isEmpty {
                // There is no shop to choose yet. Making the first one is what chooses it, and
                // there is no list ordering for it to re-point.
                ShopSwitcherSheet(store: store)
                    .onDisappear {
                        // A shop was made, or nothing was: skipping leaves both shops nil, which
                        // is the same no-op cancelling is everywhere else here.
                        if let shopID = store.activeShopID { onChoose(shopID) }
                    }
            } else {
                list
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File this receipt under")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.shops, id: \.id) { shop in
                        row(shop)
                    }
                }
            }
            Text("Only this receipt. Your list stays where it is.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper.color)
    }

    private func row(_ shop: Shop) -> some View {
        Button {
            onChoose(shop.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                GlyphTile(emoji: "📍")
                Text(shop.name)
                    .font(Typography.itemName)
                    .foregroundStyle(Palette.ink.color)
                Spacer(minLength: 12)
                if shop.id == chosen {
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
        .accessibilityLabel("File under \(shop.name)")
    }
}
