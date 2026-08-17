import DesignKit
import Foundation
import SwiftUI

/// Screen 15 — everything Bagged holds, and where it lives. Every sentence here is a claim
/// about code, so each one names the mechanism rather than a feeling about it.
struct DataPrivacyScreen: View {
    /// nil when the database could not be opened: the page still tells the truth, it just has
    /// nothing to export.
    let exporter: CSVExporter?

    private let defaults: UserDefaults
    @State private var barcodeLookup: Bool
    @State private var exported: [URL] = []
    @State private var exportFailure: String?

    init(exporter: CSVExporter?, defaults: UserDefaults) {
        self.exporter = exporter
        self.defaults = defaults
        _barcodeLookup = State(initialValue: ProductLookup.isEnabled(defaults))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Everything Bagged holds, and where it lives.")
                    .font(Typography.body)
                    .foregroundStyle(Palette.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
                held
                leaves
                location
                export
                Text("No ads. No selling data. Guests never need an account.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(Palette.paper.color)
        .navigationTitle("Data & privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - What is held

    private var held: some View {
        card("ON THIS PHONE") {
            fact("Your list, items and prices",
                 "One database on this phone, which only Bagged, its widget and its shortcuts "
                     + "can open. Every screen reads that and nothing else, which is why it all "
                     + "works with no signal. When you share a kitchen, the same changes travel "
                     + "through Bagged's sync server so everyone in the kitchen sees them.")
            fact("Receipt photos",
                 "The photo file stays here, beside the database. Deleting the receipt deletes "
                     + "the file.")
            fact("What you tap and search",
                 "Nowhere. Bagged carries no analytics SDK and no crash reporter, so nothing "
                     + "reports how you use it.")
        }
    }

    // MARK: - What leaves

    private var leaves: some View {
        card("WHAT LEAVES THIS PHONE") {
            fact("A receipt you scan",
                 "The photo goes to Bagged's reader and, from there, to Anthropic's Claude, "
                     + "which turns it into lines. It is read, answered and not kept. Receipt "
                     + "photos are the only images that ever leave your phone.")
            barcodeToggle
        }
    }

    /// This screen owns the switch (`ProductLookup.settingKey`), and the wording is
    /// `ProductLookup`'s own: absent means on, off means no code ever leaves the phone.
    private var barcodeToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(get: { barcodeLookup },
                                 set: { DataPrivacyScreen.setBarcodeLookup($0, in: defaults)
                                        barcodeLookup = $0 })) {
                Text("Look up unknown barcodes")
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
            }
            .tint(Palette.persimmon.color)
            .frame(minHeight: 44)
            Text("On, a barcode this kitchen cannot name is sent to Open Food Facts. Off, no "
                 + "code ever leaves the phone. Only the digits go — never a photo, and only "
                 + "8 to 14 digit product codes, so a shop's own shelf label is never sent.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func setBarcodeLookup(_ isOn: Bool, in defaults: UserDefaults) {
        defaults.set(isOn, forKey: ProductLookup.settingKey)
    }

    // MARK: - Where you are

    /// Two rows, because a shop and a shop's pin have different answers: `ListStore.createShop`
    /// writes a `.shop` op, so shops sync; `PlaceStore` writes pins to one local file and never
    /// appends an op, so pins cannot reach the transport. The render (15) merges the two and
    /// promises secrecy for the half we upload by design — the truth wins.
    private var location: some View {
        card("WHERE YOU ARE") {
            fact("Your shops",
                 "On this phone · synced to your kitchen. A shop is a name everyone in the "
                     + "kitchen shares.")
            fact("Where your shops are",
                 "On this phone only — never uploaded, not even to your kitchen. Everyone sets "
                     + "their own pins. A pin lives in a file in this app's Application Support "
                     + "folder, outside the container the sync engine can read, and it is left "
                     + "out of your backups.")
            fact("So, in a shared kitchen",
                 "The shop syncs and the pin does not: your partner does not inherit your pins, "
                     + "and each phone wakes at the shops it was told about.")
        }
    }

    // MARK: - Getting it all back out

    private var export: some View {
        card("YOUR DATA, OUT") {
            fact("What's in it",
                 "Three files — your list, every price you have recorded, and every receipt. "
                     + "Every amount is written as the whole minor unit the app stores, so "
                     + "nothing is rounded on the way out, and a count nobody recorded is left "
                     + "blank rather than filled in with a 1.")
            if let exporter {
                Button {
                    run(exporter)
                } label: {
                    Text("Export everything (CSV)")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Palette.persimmon.color)
                        .frame(minHeight: 44)
                }
                if !exported.isEmpty {
                    ShareLink(items: exported) {
                        Text("\(exported.count) files ready — share or save")
                            .font(Typography.body)
                            .foregroundStyle(Palette.ink.color)
                            .frame(minHeight: 44)
                    }
                }
                if let exportFailure {
                    Notice(exportFailure, tone: .attention, on: .card)
                }
            }
            // The render (15) offers "Delete my data" as a button. Nothing in the app can honour
            // that yet — there is no wipe and no account deletion — so it says what is true.
            fact("Deleting it",
                 "Deleting Bagged from this phone takes the database, the receipt photos and "
                     + "your pins with it. A shared kitchen also lives on Bagged's server, and "
                     + "removing that is a support email today rather than a button here.")
        }
    }

    private func run(_ exporter: CSVExporter) {
        do {
            exported = try exporter.write()
            exportFailure = nil
        } catch {
            exported = []
            exportFailure = "The export couldn't be written. Nothing was changed or sent."
        }
    }

    // MARK: - Shapes

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(title)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    private func fact(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.ink.color)
            Text(body)
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
