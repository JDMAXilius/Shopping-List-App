import Core
import DesignKit
import SwiftUI

struct AisleOrderEditor: View {
    let store: ListStore
    let shopID: ShopID

    @State private var order: [AisleSection] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            List {
                ForEach(order) { aisle in
                    row(aisle)
                }
                .onMove(perform: move)
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            Text("This order is saved for \(shopName) only.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .padding(.horizontal, 16)
        }
        .background(Palette.paper.color)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // Editing a shop's walk order is editing the shop you're shopping.
            if store.activeShopID != shopID { store.switchShop(shopID) }
            // Today's aisles first, then every other one: what gets saved is the WHOLE
            // walk order, so an empty-today aisle never drops out of it.
            order = store.editableAisles
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Aisle order")
                    .font(.system(.title, weight: .bold))
                    .foregroundStyle(Palette.ink.color)
                Text(shopName)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
            Spacer(minLength: 12)
            // Bold: persimmon text on paper only clears 4.5:1 as large or bold type.
            Button("Done") { dismiss() }
                .font(.system(.body, weight: .bold))
                .foregroundStyle(Palette.persimmon.color)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func row(_ aisle: AisleSection) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(aisle.category.tint.color)
                .frame(width: 12, height: 12)
            Text(aisle.title)
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
            Spacer(minLength: 12)
            Text(aisle.totalCount == 0
                 ? "none today" : "\(aisle.totalCount) item\(aisle.totalCount == 1 ? "" : "s")")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
        .frame(minHeight: 44)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.card.color)
                .padding(.vertical, 3))
        .listRowSeparator(.hidden)
    }

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        Haptics.play(.dragDrop)
        store.reorderAisles(order.map { CategoryID($0.category.rawValue) })
    }

    private var shopName: String {
        store.shops.first { $0.id == shopID }?.name ?? "this shop"
    }
}
