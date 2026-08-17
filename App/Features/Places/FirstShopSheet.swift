import Core
import DesignKit
import SwiftUI

/// Screen 18 — the first shop, asked at the first switcher use and nowhere else. No progress
/// dots: this is one contextual step, not page two of a wizard (PRODUCT §5).
struct FirstShopSheet: View {
    let store: ListStore
    let places: PlaceStore

    @State private var name = ""
    @State private var created: ShopID?
    @State private var pinning = false
    @State private var awaitingPermission = false
    @State private var fixFailed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let created {
                pinOffer(created)
            } else {
                namePrompt
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper.color)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: places.permission) { _, permission in
            guard awaitingPermission, let created else { return }
            awaitingPermission = false
            if permission.canLocate {
                Task { await pin(created) }
            } else {
                fixFailed = true
            }
        }
    }

    private var namePrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where do you usually shop?")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text("Aisle order and prices are saved per shop.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
            Field("Shop name", text: $name, placeholder: "Trader Joe's", on: .paper,
                  onSubmit: save)
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
            // The design offers a nearby list. A nearby list is a search, and a search is this
            // phone telling a server where it is standing.
            Text("There is no nearby list, on purpose: finding shops around you means sending "
                 + "where you are to a search service.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The permission moment, and the only reason this app ever wants location: asked here
    /// because here is where somebody says they want the list to wake up.
    private func pinOffer(_ shopID: ShopID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Wake the list when you arrive?")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text("If you are standing in \(shopName(shopID)) right now, Bagged can remember the "
                 + "spot and switch the list to this shop when you come back. The spot is kept "
                 + "on this phone and never uploaded — not even to the people in your kitchen.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
            if fixFailed {
                Notice("No fix here — nothing was saved. You can add a pin later from Places.",
                       tone: .attention, on: .paper)
            }
            Button { startPin(shopID) } label: {
                Text(pinning ? "Getting a fix…" : "I'm here now — set the pin")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(pinning || awaitingPermission)
            .opacity(pinning || awaitingPermission ? 0.5 : 1)
            Button("Not now") { dismiss() }
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func shopName(_ shopID: ShopID) -> String {
        store.shops.first { $0.id == shopID }?.name ?? "this shop"
    }

    /// The shop lands and the list moves to it — this sheet opened because somebody asked where
    /// they were shopping. The pin is a separate, refusable question after it.
    private func save() {
        guard let shopID = store.createShop(named: trimmed) else { return }
        store.switchShop(shopID)
        created = shopID
    }

    private func startPin(_ shopID: ShopID) {
        fixFailed = false
        guard places.canPin else {
            awaitingPermission = true
            places.requestPermission()
            return
        }
        Task { await pin(shopID) }
    }

    private func pin(_ shopID: ShopID) async {
        pinning = true
        let pinned = await places.pinHere(shopID)
        pinning = false
        fixFailed = !pinned
        if pinned { dismiss() }
    }
}
