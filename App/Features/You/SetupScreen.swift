import Core
import DesignKit
import Foundation
import SwiftUI

/// The two feedback switches INTERACTION §4/§5 require, persisted where the app can read them.
/// `apply` has to run at launch — the toggles are read by DesignKit at the moment a tick fires,
/// so a phone that turned sound off must arrive with it off, not once this tab is opened.
@MainActor
enum SetupSettings {
    static let soundKey = "settings.sound"
    static let hapticsKey = "settings.haptics"

    static func apply(_ defaults: UserDefaults) {
        Sound.isEnabled = isOn(soundKey, defaults)
        Haptics.isEnabled = isOn(hapticsKey, defaults)
    }

    static func isOn(_ key: String, _ defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    static func set(_ key: String, _ isOn: Bool, in defaults: UserDefaults) {
        defaults.set(isOn, forKey: key)
        apply(defaults)
    }
}

/// Screen 14 — the third tab. Only settings that exist: a row here is a thing the app can
/// actually do today.
struct SetupScreen: View {
    let store: ListStore
    let subscription: SubscriptionStore
    @Binding var sheet: Sheet?

    private let defaults: UserDefaults
    @State private var soundOn: Bool
    @State private var hapticsOn: Bool

    init(store: ListStore, subscription: SubscriptionStore, sheet: Binding<Sheet?>,
         defaults: UserDefaults) {
        self.store = store
        self.subscription = subscription
        _sheet = sheet
        self.defaults = defaults
        _soundOn = State(initialValue: SetupSettings.isOn(SetupSettings.soundKey, defaults))
        _hapticsOn = State(initialValue: SetupSettings.isOn(SetupSettings.hapticsKey, defaults))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("You")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.ink.color)
                plus
                group {
                    link("Kitchen", nil, Route.kitchen)
                    link("Places", Self.shopsDetail(store.shops.count), Route.places)
                }
                group {
                    toggle("Sound", isOn: $soundOn, key: SetupSettings.soundKey)
                    toggle("Haptics", isOn: $hapticsOn, key: SetupSettings.hapticsKey)
                }
                group {
                    link("Data & privacy", nil, Route.dataPrivacy)
                    link("Why it works this way", nil, Route.whyItWorksThisWay)
                    link("About", nil, Route.about)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Palette.paper.color)
        .toolbar(.hidden, for: .navigationBar)
        .task { SetupSettings.apply(defaults) }
    }

    static func shopsDetail(_ count: Int) -> String {
        count == 0 ? "none yet" : "\(count) shop\(count == 1 ? "" : "s")"
    }

    // MARK: - Plus

    /// A joiner sees no card at all: they are never sold to, and an "upgrade" strip is a sale
    /// (PRODUCT §1). A Plus household sees a fact, not an offer.
    @ViewBuilder private var plus: some View {
        if subscription.isPlus {
            plusCard(title: "Bagged Plus", detail: "Active. Receipt scanning, price history and "
                     + "more than one shop.", chip: nil, action: nil)
        } else if subscription.mayBeOffered {
            plusCard(title: "Bagged Plus",
                     detail: Capability.allCases.filter(\.isPlus).map(\.title)
                        .joined(separator: " · "),
                     chip: Self.scansChip(subscription.freeScansLeft),
                     action: { sheet = .paywall })
        }
    }

    static func scansChip(_ left: Int) -> String {
        left == 0 ? "\(PlusPlan.freeScanLimit) free scans used"
                  : "\(left) free scan\(left == 1 ? "" : "s") left"
    }

    private func plusCard(title: String, detail: String, chip: String?,
                          action: (() -> Void)?) -> some View {
        let card = VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.card.color)
            Text(detail)
                .font(Typography.footnote)
                .foregroundStyle(Palette.line.color)
                .fixedSize(horizontal: false, vertical: true)
            if let chip {
                Text(chip)
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.card.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Palette.ink.color))
        return Group {
            if let action {
                Button(action: action) { card }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title). \(detail). \(chip ?? "")")
            } else {
                card.accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Rows

    private func group(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    private func link(_ title: String, _ detail: String?, _ route: Route) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                Text(title)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
                Spacer(minLength: 12)
                if let detail {
                    Text(detail)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                }
                Image(systemName: "chevron.right")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.muted.color)
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(detail.map { "\(title), \($0)" } ?? title)
    }

    private func toggle(_ title: String, isOn: Binding<Bool>, key: String) -> some View {
        Toggle(isOn: Binding(get: { isOn.wrappedValue },
                             set: { SetupSettings.set(key, $0, in: defaults)
                                    isOn.wrappedValue = $0 })) {
            Text(title)
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
        }
        .tint(Palette.persimmon.color)
        .frame(minHeight: 56)
    }
}
