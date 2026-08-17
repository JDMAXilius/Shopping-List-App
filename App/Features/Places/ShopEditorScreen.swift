import Core
import DesignKit
import SwiftUI
import UIKit

/// Screen 13 — one shop: where it is, how close counts as arrived, and its walk order.
/// There is no Save: every control here commits when you let go of it, so a Save button would
/// be decoration promising a step that does not exist.
struct ShopEditorScreen: View {
    let store: ListStore
    let places: PlaceStore
    let shopID: ShopID

    @State private var pinning = false
    @State private var awaitingPermission = false
    @State private var fixFailed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var place: Place? { places.place(shopID) }
    private var shopName: String { store.shops.first { $0.id == shopID }?.name ?? "This shop" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                RadiusDiagram(radius: place?.radius ?? Place.defaultRadius, pinned: place != nil)
                Text("No map is drawn here: asking for the tiles around your pin would send "
                     + "where you are to somebody's server.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                if let place {
                    wakeControls(place)
                } else {
                    pinPrompt
                }
                aisleOrderRow
                footer
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Palette.paper.color)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: places.permission) { _, permission in
            guard awaitingPermission else { return }
            awaitingPermission = false
            if permission.canLocate {
                Task { await pin() }
            } else {
                fixFailed = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundStyle(Palette.ink.color)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }
            .accessibilityLabel("Back")
            Text(shopName)
                .font(.system(.title, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Spacer(minLength: 0)
        }
    }

    // MARK: - The pin

    private var pinPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No pin on this phone")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.ink.color)
            Text("A pin lets the list switch to this shop by itself when you walk in. It is set "
                 + "from where you are standing — there is no search, because searching would "
                 + "send your location away.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
            pinButton("Set the pin from where I am")
            Text("A shop without a pin is a perfectly normal shop.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
    }

    private func pinButton(_ title: String) -> some View {
        Button { startPin() } label: {
            Text(pinning ? "Getting a fix…" : title)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.card.color)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Capsule().fill(Palette.persimmon.color))
        }
        .buttonStyle(.plain)
        .disabled(pinning || awaitingPermission)
        .opacity(pinning || awaitingPermission ? 0.5 : 1)
    }

    // MARK: - Radius and wake-up

    private func wakeControls(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            radiusRow(place)
            Divider().overlay(Palette.line.color)
            Toggle(isOn: Binding(get: { place.wakeEnabled },
                                 set: { places.setWake($0, for: shopID) })) {
                Text("Wake the list when I arrive")
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
            }
            .tint(Palette.persimmon.color)
            .frame(minHeight: 44)
            if place.wakeEnabled, places.permission == .whileUsing {
                backgroundUpgrade
            }
            Divider().overlay(Palette.line.color)
            pinFacts(place)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
    }

    private func radiusRow(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Wake-up radius")
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
                Spacer(minLength: 12)
                Text("\(Int(place.radius)) m")
                    .font(.system(.body).monospacedDigit())
                    .foregroundStyle(Palette.muted.color)
            }
            Slider(value: Binding(get: { place.radius },
                                  set: { places.setRadius($0, for: shopID) }),
                   in: Place.radiusRange, step: 25)
                .tint(Palette.persimmon.color)
                .frame(minHeight: 44)
                .accessibilityLabel("Wake-up radius, metres")
        }
    }

    /// The second ask, and the only one: while-using fences only fire with Bagged already open,
    /// which is not what "wakes when you arrive" says.
    private var backgroundUpgrade: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Right now this only works while Bagged is open. Letting it check in the "
                 + "background is what makes the list already right when you take the phone out.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
            Button("Allow background arrivals") { places.requestBackgroundPermission() }
                .font(.system(.body, weight: .bold))
                .foregroundStyle(Palette.persimmon.color)
                .frame(minHeight: 44)
        }
    }

    private func pinFacts(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pinned \(place.pinnedAt.formatted(date: .abbreviated, time: .omitted)) · "
                 + "accurate to about \(Int(place.accuracy.rounded())) m")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
            HStack(spacing: 16) {
                Button("Re-pin from here") { startPin() }
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Palette.persimmon.color)
                    .frame(minHeight: 44)
                    .disabled(pinning || awaitingPermission)
                Button("Remove the pin") { places.removePin(shopID) }
                    .font(Typography.body)
                    .foregroundStyle(Palette.muted.color)
                    .frame(minHeight: 44)
            }
        }
    }

    // MARK: - Aisle order

    private var aisleOrderRow: some View {
        NavigationLink(value: Route.aisleOrder(shopID)) {
            HStack(spacing: 12) {
                Text("Aisle order")
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
                Spacer(minLength: 12)
                Text(store.hasAisleOrder(shopID) ? "saved · edit" : "not set yet · edit")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.muted.color)
            }
            .padding(14)
            .frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.card.color))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this shop's walk order, and shops this list here")
    }

    // MARK: - Standing facts

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if fixFailed {
                Notice("No fix here. Standing inside the shop usually gets one — nothing was "
                       + "saved.", tone: .attention, on: .paper)
            }
            if places.permission == .denied {
                Notice("Location is off for Bagged, so no shop can wake the list. Everything "
                       + "else about this shop works.", on: .paper)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.system(.body, weight: .bold))
                .foregroundStyle(Palette.persimmon.color)
                .frame(minHeight: 44)
            }
            Notice("Everyone in your kitchen shares this shop, its aisle order and its prices. "
                   + "The pin and radius stay on this phone — your partner sets their own.",
                   on: .paper)
            Notice("Location checks happen on your phone. Nothing is uploaded.", on: .paper)
        }
    }

    // MARK: - Actions

    private func startPin() {
        fixFailed = false
        guard places.canPin else {
            // The primer IS this screen: the words above the button say what it is for, and the
            // system prompt only ever appears after that tap.
            awaitingPermission = true
            places.requestPermission()
            return
        }
        Task { await pin() }
    }

    private func pin() async {
        pinning = true
        let pinned = await places.pinHere(shopID)
        pinning = false
        fixFailed = !pinned
    }
}

/// The radius, drawn honestly and with no basemap under it: a map tile request would carry the
/// neighbourhood of the pin off the phone, which is the promise this screen is making.
private struct RadiusDiagram: View {
    let radius: Double
    let pinned: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(Palette.persimmon.color.opacity(0.14))
                    .overlay(Circle().strokeBorder(Palette.persimmon.color, lineWidth: 1))
                    .frame(width: side * scale, height: side * scale)
                Image(systemName: "mappin")
                    .font(.system(.title3))
                    .foregroundStyle(pinned ? Palette.persimmon.color : Palette.muted.color)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 180)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.line.color))
        .opacity(pinned ? 1 : 0.5)
        .accessibilityElement()
        .accessibilityLabel(pinned
                            ? "Wakes within \(Int(radius)) metres of the pin"
                            : "No pin yet")
    }
}

extension RadiusDiagram {
    /// Proportional inside the range so the circle means something, floored so the smallest
    /// radius is still a shape.
    private var scale: CGFloat {
        let span = Place.radiusRange.upperBound - Place.radiusRange.lowerBound
        let position = (radius - Place.radiusRange.lowerBound) / span
        return 0.45 + 0.45 * CGFloat(min(max(position, 0), 1))
    }
}
