import Core
import DesignKit
import SwiftUI

/// The capture flow's shop picker. It RETURNS a choice and touches nothing else: filing a
/// receipt must not re-point the list, and swiping this away must change nothing at all.
struct CaptureShopPicker: View {
    let store: ListStore
    let chosen: ShopID?
    let onChoose: (ShopID) -> Void

    @State private var newShopName = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        list
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.shops.isEmpty ? "Where did you shop?" : "File this receipt under")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.shops, id: \.id) { shop in
                        row(shop)
                    }
                    newShopRow
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

    // A shop you have not shopped at yet is exactly the shop a receipt arrives from, so it is
    // made here rather than sending the user out to the list — where making one re-points it.
    private var newShopRow: some View {
        HStack(spacing: 8) {
            Field("New shop", text: $newShopName, placeholder: "One that isn't here yet",
                  on: .paper, onSubmit: create)
            Button("Add", action: create)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.persimmon.color)
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.4 : 1)
        }
    }

    private var trimmed: String { newShopName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func create() {
        guard let shopID = store.createShop(named: trimmed) else { return }
        newShopName = ""
        onChoose(shopID)
        dismiss()
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
