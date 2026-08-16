import Core
import DesignKit
import SwiftUI

/// Screen 04, and the gate: nothing commits unreviewed. Every op this flow will ever write is
/// written by the save button below and by nothing else on this screen.
struct ReceiptReviewScreen: View {
    let session: CaptureSession
    @Binding var path: [CaptureRoute]

    @State private var isPickingShop = false
    @State private var saveFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                shopRow
                totalRow
                // The save button goes inert on a mismatch, and a button that stops working
                // without saying why is the same silence as a wrong number.
                if let printed = session.currencyMismatch {
                    Notice("This receipt is in \(printed) and this kitchen keeps its prices in \(session.currencyCode). Saving it would mix two currencies into one total, so it can't be saved here.",
                           tone: .attention, on: .paper)
                } else if session.shopID == nil {
                    Notice("Pick a shop first — a price with no shop can't be compared with anything.",
                           tone: .attention, on: .paper)
                }
                ForEach(session.lines) { line in
                    card(line)
                }
                commitBar
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationTitle("Check the lines")
        .navigationBarTitleDisplayMode(.inline)
        // Only an explicit choice changes the shop: cancelling this is a no-op, and nothing here
        // touches the shop the list is pointed at.
        .sheet(isPresented: $isPickingShop) {
            CaptureShopPicker(store: session.store, chosen: session.shopID) { shopID in
                session.shopID = shopID
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Notice("Nothing is saved until you tap save.", on: .paper)
            if let disagreement = Self.disagreement(printed: session.printedShopName,
                                                    chosen: session.shopName) {
                Notice(disagreement, tone: .attention, on: .paper)
            } else if let printed = session.printedShopName {
                Text("Printed on the receipt: \(printed)")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
        }
    }

    /// The printed name and the chosen shop disagreeing is where a whole receipt gets filed under
    /// the wrong shop, so it asks for attention rather than sitting in a footnote.
    static func disagreement(printed: String?, chosen: String?) -> String? {
        guard let printed, let chosen,
              Merge.normalized(printed) != Merge.normalized(chosen) else { return nil }
        return "This receipt printed “\(printed)” but it will be filed under \(chosen)."
    }

    private var shopRow: some View {
        HStack(spacing: 8) {
            SectionLabel("SHOP")
            Spacer(minLength: 8)
            Chip(session.shopName ?? "Pick a shop", on: .paper, opensPicker: true,
                 accessibilityLabel: "Filed under \(session.shopName ?? "no shop yet"). Change shop.") {
                isPickingShop = true
            }
        }
    }

    /// The user is the last check on the money, and until now they were shown no total at all.
    /// A total the receipt never printed is said in words, in the muted tier — nothing computed
    /// ever stands where the till's own figure would.
    private var totalRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                SectionLabel("TOTAL PRINTED ON THIS RECEIPT")
                Spacer(minLength: 8)
                if let printed = session.printedTotal {
                    Text(printed.display)
                        .font(Typography.total)
                        .foregroundStyle(Palette.ink.color)
                } else {
                    Text("not read")
                        .font(Typography.body)
                        .foregroundStyle(Palette.muted.color)
                }
            }
            Text(Self.totalNote(printed: session.printedTotal, recorded: session.recordedTotal))
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
    }

    /// Two numbers that must never be confusable: what the till charged, and what the lines you
    /// are keeping add up to. The second one says whose it is.
    static func totalNote(printed: Money?, recorded: Money) -> String {
        guard let printed else {
            return "This receipt's total wasn't read, so none is saved. The lines you keep add "
                + "up to \(recorded.display) — that is ours, not what the till charged."
        }
        guard recorded.minorUnits < printed.minorUnits else {
            return "The lines you keep add up to \(recorded.display)."
        }
        return "The lines you keep add up to \(recorded.display) of it — the rest is tax, "
            + "deposits and lines nothing was matched to."
    }

    // MARK: - One line

    private func card(_ line: CaptureLine) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.match?.name ?? "No match yet")
                        .font(Typography.itemName)
                        .foregroundStyle(Palette.ink.color)
                    // The raw text stays visible for every line: it is what the user checks the
                    // match against, and what "remembered forever" will be keyed on.
                    Text(line.rawText)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                        .lineLimit(2)
                    if let detail = Self.quantityDetail(line) {
                        Text(detail)
                            .font(Typography.footnote)
                            .foregroundStyle(Palette.muted.color)
                    }
                }
                Spacer(minLength: 12)
                amount(line)
            }
            chips(line)
            if let flag = line.estimateFlag {
                Notice(flag, tone: .attention, on: .card)
            }
            actions(line)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.card.color))
    }

    /// A coupon is on the receipt and stays on the screen, shown as what it is: money off, in no
    /// price tier at all, so it can never read as what an item cost.
    @ViewBuilder private func amount(_ line: CaptureLine) -> some View {
        if line.isMoneyOff {
            Text(line.moneyOffText)
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
        } else {
            PriceLabel(PriceDisplay(amount: line.amount, confidence: .trusted))
        }
    }

    private func chips(_ line: CaptureLine) -> some View {
        HStack(spacing: 8) {
            Chip(Self.word(line.confidence), tone: Self.tone(line.confidence), on: .card)
            if line.isMoneyOff {
                Chip("money off — not a price", on: .card)
            }
            if line.isRemembered {
                Chip("remembered", on: .card)
            }
            if line.decision == .ignore {
                Chip("ignored for good", tone: .attention, on: .card)
            }
            Spacer(minLength: 0)
        }
    }

    private func actions(_ line: CaptureLine) -> some View {
        HStack(spacing: 12) {
            action(line.match == nil ? "Match this line" : "Change match") {
                path.append(.resolver(line.id))
            }
            Spacer(minLength: 8)
            if line.decision == .ignore {
                action("Keep it") { session.accept(line.id) }
            } else {
                action("Ignore forever") { session.ignore(line.id) }
            }
        }
    }

    private func action(_ title: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Text(title)
                // Persimmon body text holds 4.5:1 on card, which is the fill under this row.
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.persimmon.color)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - The commit

    private var commitBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if saveFailed {
                Notice("Nothing was saved — not one price. The receipt is still here: try saving it again.",
                       tone: .attention, on: .paper)
            }
            Button { saveFailed = !session.commit() } label: {
                Text(saveTitle)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(!session.canCommit)
            .opacity(session.canCommit ? 1 : 0.4)
            if rememberCount > 0 {
                Text("\(rememberCount) \(rememberCount == 1 ? "line is" : "lines are") remembered for the whole kitchen, permanently.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
            Button { session.discard() } label: {
                Text("Discard this photo")
                    .font(Typography.body)
                    .foregroundStyle(Palette.muted.color)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    /// The real count, never a rounded flourish — it is the number of prices about to exist.
    private var saveTitle: String {
        let count = session.acceptedCount
        return count == 1 ? "Save 1 price" : "Save \(count) prices"
    }

    private var rememberCount: Int { session.lines.filter { $0.alias != nil }.count }

    // MARK: - Words

    /// The word carries the meaning; the colour never does (`Chip`).
    static func word(_ confidence: ScanConfidence) -> String {
        switch confidence {
        case .sure: return "sure"
        case .notSure: return "not sure"
        case .noMatch: return "no match"
        }
    }

    static func tone(_ confidence: ScanConfidence) -> Chip.Tone {
        confidence == .sure ? .neutral : .attention
    }

    /// A multi-unit line shows what one cost, because that is the number being recorded.
    static func quantityDetail(_ line: CaptureLine) -> String? {
        guard line.showsEach else { return QuantityText.label(quantity: line.quantity, unit: nil) }
        let quantity = QuantityText.label(quantity: line.quantity, unit: nil) ?? "×1"
        return "\(quantity) · \(line.unitAmount.display) each"
    }
}
