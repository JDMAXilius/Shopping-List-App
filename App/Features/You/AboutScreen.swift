import DesignKit
import Foundation
import SwiftUI

/// The links a store build must carry. They are read from this build's Info.plist the way the
/// scan endpoint is (`BaggedApp.makeScanBackend`) — never a literal here, because the domain
/// they point at is not owned yet and a row that opens nothing is worse than no row.
struct AboutLinks: View {
    struct Row: Identifiable, Hashable {
        let title: String
        let url: URL

        var id: String { title }
    }

    let rows: [Row]

    static var policyRows: [Row] {
        [row("Privacy policy", "PrivacyPolicyURL"), row("Terms", "TermsURL")].compactMap { $0 }
    }

    static var allRows: [Row] {
        [row("Support", "SupportURL")].compactMap { $0 } + policyRows
    }

    var body: some View {
        ForEach(rows) { row in
            Link(destination: row.url) {
                HStack {
                    Text(row.title)
                        .font(Typography.body)
                        .foregroundStyle(Palette.ink.color)
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.up.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Palette.muted.color)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
        }
    }

    private static func row(_ title: String, _ key: String) -> Row? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespaces)),
              url.scheme != nil else { return nil }
        return Row(title: title, url: url)
    }
}

/// Screen 16 — what this is, which version, and who else's work is in it.
struct AboutScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                identity
                links
                attribution
                // Testing scaffolding. Not `#if DEBUG`: TestFlight is a Release build. Dropping
                // BAGGED_SCREENS_PANEL from project.yml removes this line's effect too, so the
                // panel leaves the binary without a second edit here.
                #if BAGGED_SCREENS_PANEL
                ScreensPanelRow()
                #endif
                Text("Made for the weekly shop.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(20)
        }
        .background(Palette.paper.color)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var identity: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.persimmon.color)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "cart")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Palette.card.color)
                }
            Text("Bagged")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            if let version = AboutScreen.versionLine {
                Text(version)
                    .font(Typography.priceSmall)
                    .foregroundStyle(Palette.muted.color)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var links: some View {
        let rows = AboutLinks.allRows
        VStack(alignment: .leading, spacing: 4) {
            if rows.isEmpty {
                Text("Support and the policy pages aren't reachable from this build.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                AboutLinks(rows: rows)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    private var attribution: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("WITH THANKS")
            paragraph("Barcode names come from Open Food Facts, used under the Open Database "
                      + "Licence (ODbL). Bagged queries it and shows you the answer; nothing from "
                      + "it is copied into Bagged's own catalog.")
            // RevenueCat is the sanctioned choice and is not in the binary yet, so this credits
            // only what actually ships. Add it back with the dependency, not before.
            paragraph("The database layer is GRDB.swift.")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Typography.footnote)
            .foregroundStyle(Palette.muted.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Nothing invented: a build with no version string shows no version line at all.
    static var versionLine: String? {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let short, !short.isEmpty else { return nil }
        guard let build, !build.isEmpty else { return "Version \(short)" }
        return "Version \(short) (\(build))"
    }
}
