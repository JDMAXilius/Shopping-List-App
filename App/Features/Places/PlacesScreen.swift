import Core
import DesignKit
import SwiftUI

/// Screen 12 — the shops this kitchen shops at, and what THIS phone knows about where they are.
struct PlacesScreen: View {
    let store: ListStore
    let places: PlaceStore
    let subscription: SubscriptionStore

    @State private var newShopName = ""
    @State private var isAdding = false
    @State private var showsPaywall = false

    /// The SAME rule the switcher uses. Two ways to add a shop and one gate between them is not
    /// a gate — a free owner could meet the wall in the switcher and walk around it here.
    private var addGate: Gate {
        ShopSwitcherSheet.addShopGate(shopCount: store.shops.count, subscription)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if store.shops.isEmpty {
                    empty
                } else {
                    shopList
                }
                addShop
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Palette.paper.color)
        .sheet(isPresented: $showsPaywall) { PaywallScreen(store: subscription) }
        .navigationTitle("Places")
        .toolbar(.hidden, for: .navigationBar)
        // A shop deleted on another phone leaves a pin behind that nothing else would collect.
        .onAppear { places.prune(to: store.shops.map(\.id)) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Places")
                .font(Typography.screenTitle)
                .foregroundStyle(Palette.ink.color)
            Text("Aisle order and prices are per shop.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
    }

    private var shopList: some View {
        VStack(spacing: 8) {
            ForEach(store.shops, id: \.id) { shop in
                NavigationLink(value: Route.shopEditor(shop.id)) {
                    row(shop)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ shop: Shop) -> some View {
        HStack(spacing: 12) {
            GlyphTile(emoji: "📍")
            VStack(alignment: .leading, spacing: 2) {
                Text(shop.name)
                    .font(Typography.itemName)
                    .foregroundStyle(Palette.ink.color)
                Text(subtitle(shop))
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Image(systemName: "chevron.right")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Palette.muted.color)
        }
        .padding(12)
        .frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
        .accessibilityElement(children: .combine)
    }

    /// Never "wake-up on" when there is nothing to wake on: a shop with no pin says so.
    private func subtitle(_ shop: Shop) -> String {
        var parts: [String] = []
        if let place = places.place(shop.id) {
            parts.append(place.wakeEnabled
                         ? "Wakes the list when you arrive · \(Int(place.radius)) m"
                         : "Pin set · wake-up off")
        } else {
            parts.append("No pin on this phone")
        }
        if store.hasAisleOrder(shop.id) { parts.append("aisle order saved") }
        return parts.joined(separator: " · ")
    }

    private var empty: some View {
        EmptyState(
            glyph: .other,
            message: "No shops yet. A shop is what an aisle order and a price belong to — add "
                + "the one you go to most.")
    }

    @ViewBuilder private var addShop: some View {
        if isAdding {
            HStack(alignment: .bottom, spacing: 8) {
                Field("New shop", text: $newShopName, placeholder: "Where you shop",
                      on: .paper, onSubmit: create)
                Button("Add", action: create)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.persimmon.color)
                    .frame(minHeight: 44)
                    .disabled(trimmed.isEmpty)
                    .opacity(trimmed.isEmpty ? 0.4 : 1)
            }
        } else if case .unavailable(let sentence) = addGate {
            // A joiner is told what it is and never shown a price.
            Text(sentence)
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Button {
                if case .paywall = addGate { showsPaywall = true } else { isAdding = true }
            } label: {
                Text(addGate == .allowed ? "+ Add a shop" : "Add a shop — part of Plus")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.persimmon.color)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.card.color))
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if places.waiting > 0 {
                Notice("iPhone watches 20 places at a time. Bagged watches the 20 you pinned or "
                       + "visited most recently — \(places.waiting) "
                       + "\(places.waiting == 1 ? "is" : "are") waiting.", on: .paper)
            }
            if places.permission == .denied {
                Notice("Location is off for Bagged. Every shop still works — switch shops from "
                       + "the list whenever you like.", on: .paper)
            }
            Notice("Your location never leaves the phone. Arrival is checked on-device.",
                   on: .paper)
        }
    }

    private var trimmed: String { newShopName.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Makes the shop without switching to it: a shop added from a settings screen must not
    /// re-point the list somebody is standing in front of.
    private func create() {
        guard store.createShop(named: trimmed) != nil else { return }
        newShopName = ""
        isAdding = false
    }
}
