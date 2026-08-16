import DesignKit
import Foundation
import SwiftUI

/// The aha, once: the first receipt this phone commits just turned into real prices. Every
/// number here was written a second ago — there is no promise on this screen, only the count.
struct FirstReceiptSheet: View {
    let result: CaptureResult
    let shopName: String?
    let onDismiss: () -> Void

    // Beside the database, in the App Group: the widget and intents share this phone's flags.
    private static let seenKey = "bagged.firstReceiptSeen"

    /// Once, ever — and only for a receipt that actually produced prices. "0 prices are yours"
    /// is not an aha, and spending the one showing on it would spend it on nothing.
    @MainActor
    static func shouldShow(_ result: CaptureResult?, defaults: UserDefaults = .appGroup()) -> Bool {
        guard let result, result.pricedCount > 0 else { return false }
        return !defaults.bool(forKey: seenKey)
    }

    @MainActor
    static func markShown(_ defaults: UserDefaults = .appGroup()) {
        defaults.set(true, forKey: seenKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Self.headline(result))
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text(result.summary)
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.lines(result, shop: shopName), id: \.self) { line in
                    Text(line)
                        .font(Typography.body)
                        .foregroundStyle(Palette.muted.color)
                }
            }
            Spacer(minLength: 0)
            Button {
                Self.markShown()
                onDismiss()
            } label: {
                Text("Got it")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper.color)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        // A swipe down is a dismissal too, and this is shown once however it is closed.
        .onDisappear { Self.markShown() }
    }

    static func headline(_ result: CaptureResult) -> String {
        result.pricedCount == 1 ? "1 price is yours now" : "\(result.pricedCount) prices are yours now"
    }

    /// Only what happened: every line is a fact about the ops that were just written.
    static func lines(_ result: CaptureResult, shop: String?) -> [String] {
        let at = shop.map { " at \($0)" } ?? ""
        var lines = [result.pricedCount == 1
            ? "That item now shows what you actually paid\(at), not an estimate."
            : "Those \(result.pricedCount) items now show what you actually paid\(at), not an estimate."]
        if result.rememberedCount > 0 {
            let plural = result.rememberedCount == 1 ? "line" : "lines"
            lines.append("\(result.rememberedCount) till \(plural) will be recognised without asking next time.")
        }
        lines.append("After 90 days a price goes back to a ~ estimate, so the book never claims to be fresher than it is.")
        return lines
    }
}
