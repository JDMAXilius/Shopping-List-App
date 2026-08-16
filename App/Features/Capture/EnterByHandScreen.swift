import Core
import DesignKit
import Foundation
import SwiftUI

/// Screen 07. No camera, no signal, same prices: the resolver's own item picker, then the typed
/// half — which the barcode screen shares, so the two can never drift apart.
struct EnterByHandScreen: View {
    let session: CaptureSession

    @State private var chosen: CaptureMatch?
    /// A brand-new item's name is the only text that can find it again, so it earns an alias.
    @State private var teaches = false
    @State private var saved: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let saved {
                    Notice(saved, on: .paper)
                }
                if let chosen {
                    picked(chosen)
                    TypedPriceEntry(session: session, item: chosen,
                                    rawText: teaches ? chosen.name : "") { sentence in
                        saved = sentence
                        self.chosen = nil
                    }
                } else {
                    Notice("A typed price counts exactly the same as one read off a receipt.",
                           on: .paper)
                    ItemChoice(session: session, prompt: "WHAT DID YOU BUY?") { match, created in
                        chosen = match
                        teaches = created
                    }
                }
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationTitle("Enter by hand")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func picked(_ match: CaptureMatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("THE ITEM")
            HStack(spacing: 12) {
                Text(match.name)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(Palette.ink.color)
                Spacer(minLength: 12)
                if let estimate = match.estimate {
                    PriceLabel(.estimated(estimate))
                }
            }
            Button { chosen = nil } label: {
                Text("Pick a different item")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.persimmon.color)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// The resolver's shape for the two ways in that have no receipt line to hang it on: the
/// catalog's closest, or an item this kitchen names itself.
struct ItemChoice: View {
    let session: CaptureSession
    let prompt: String
    /// The match, and whether it was created here rather than found in the catalog.
    let onChoose: (CaptureMatch, Bool) -> Void

    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(prompt)
            Field("Search", text: $query, placeholder: "milk", on: .paper)
            matches
            create
        }
    }

    @ViewBuilder private var matches: some View {
        let found = trimmed.isEmpty ? [] : session.suggestions(for: trimmed)
        if trimmed.isEmpty {
            Text("Type what it is — the catalog's closest matches appear here.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        } else if found.isEmpty {
            Text("Nothing in the catalog looks like that. You can make it your own item below.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        } else {
            ForEach(found, id: \.itemID) { match in
                Button {
                    onChoose(session.match(itemID: match.itemID, name: match.name), false)
                } label: {
                    HStack(spacing: 12) {
                        GlyphTile(match.category)
                        Text(match.name)
                            .font(Typography.itemName)
                            .foregroundStyle(Palette.ink.color)
                        Spacer(minLength: 12)
                    }
                    .padding(12)
                    .frame(minHeight: 56)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.card.color))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Price \(match.name)")
            }
        }
    }

    private var create: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("OR MAKE IT A NEW ITEM")
            Button {
                // A name this kitchen was already taught keeps its item, so two typings of the
                // same thing are one history — and the name shown is the item that gets priced.
                onChoose(session.remembered(trimmed)
                    ?? session.match(itemID: ItemID(), name: trimmed), true)
            } label: {
                Text(trimmed.isEmpty ? "Create it" : "Create “\(trimmed)”")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty)
            .opacity(trimmed.isEmpty ? 0.4 : 1)
        }
    }

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// What you paid, how many, where and when — and the one write. Shared by enter-by-hand and the
/// barcode screen: two money fields would drift, and a price book off by a cent is a wrong one.
struct TypedPriceEntry: View {
    let session: CaptureSession
    let item: CaptureMatch
    /// The text this price teaches the kitchen to mean this item — a barcode, or the name a new
    /// item was typed under. Empty teaches nothing.
    let rawText: String
    let onSaved: (String) -> Void

    @State private var amountText = ""
    /// Text, not a step count: the scanned path carries 0.5 lb and the typed one has to be able
    /// to say the same thing.
    @State private var quantityText = "1"
    @State private var date = Date()
    @State private var isPickingShop = false
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            amountRow
            quantityRow
            shopRow
            if session.shopID == nil {
                Notice("Pick a shop first — a price with no shop can't be compared with anything.",
                       tone: .attention, on: .paper)
            }
            dateRow
            if let flag = previewLine?.estimateFlag {
                Notice(flag, tone: .attention, on: .paper)
            }
            if failed {
                Notice("That price wasn't saved. Try it again.", tone: .attention, on: .paper)
            }
            saveButton
            Text("It lands in the price book tagged typed — never as a line read off a receipt.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
        // Cancelling changes nothing, and choosing here never re-points the list.
        .sheet(isPresented: $isPickingShop) {
            CaptureShopPicker(store: session.store, chosen: session.shopID) { shopID in
                session.shopID = shopID
            }
        }
    }

    private var amountRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // The label carries the multi-buy rule: what goes in the box is the whole line.
            Field(quantity > 1 ? "What you paid for all \(Self.quantityText(quantity))"
                               : "What you paid",
                  text: $amountText, placeholder: "0.00", keyboard: .decimal, on: .paper)
            preview
                .padding(.bottom, 12)
        }
    }

    /// What the field says, in the form it will be stored — `—` while it says nothing readable.
    @ViewBuilder private var preview: some View {
        if let line = previewLine {
            PriceLabel(PriceDisplay(amount: line.amount, confidence: .trusted))
        } else {
            PriceLabel(PriceDisplay.none)
        }
    }

    private var quantityRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                Field("HOW MANY", text: $quantityText, placeholder: "1", keyboard: .decimal,
                      on: .paper)
                step("minus", to: quantity - 1)
                step("plus", to: quantity + 1)
            }
            Text("Half a pound is 0.5 — under one, what you paid is what's recorded.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
            if let line = previewLine, line.showsEach {
                Text("The price recorded is \(line.unitAmount.display) — what one cost.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
        }
    }

    private func step(_ symbol: String, to next: Double) -> some View {
        Button { quantityText = Self.quantityText(next) } label: {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.ink.color)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.card.color))
        }
        .buttonStyle(.plain)
        .disabled(next <= 0)
        .opacity(next <= 0 ? 0.4 : 1)
        .accessibilityLabel(symbol == "plus" ? "One more" : "One fewer")
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

    /// Back as far as you like, never forward: a future date would outrank every real price.
    private var dateRow: some View {
        HStack(spacing: 8) {
            SectionLabel("WHEN")
            Spacer(minLength: 8)
            DatePicker("When you paid it", selection: $date, in: ...Date(),
                       displayedComponents: .date)
                .labelsHidden()
                .tint(Palette.persimmon.color)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save 1 price")
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.card.color)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Capsule().fill(Palette.persimmon.color))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.4)
    }

    private var canSave: Bool { previewLine != nil && session.shopID != nil }

    private var quantity: Double { Self.quantity(from: quantityText) ?? 1 }

    /// The line the session will write, exactly as a receipt line is written — so the >3× gate
    /// and the price-of-one rule are the same code here as they are at review.
    private var previewLine: CaptureLine? {
        guard let amount = Self.money(from: amountText, currencyCode: session.currencyCode),
              amount.minorUnits > 0, let quantity = Self.quantity(from: quantityText) else {
            return nil
        }
        return CaptureLine(rawText: rawText, amount: amount, quantity: quantity,
                           confidence: .sure, match: item, decision: .accept,
                           alias: rawText.isEmpty ? nil : .remember(item.itemID))
    }

    private func save() {
        guard let line = previewLine, let shopID = session.shopID else { return }
        guard session.record(line, shopID: shopID, date: date) else {
            failed = true
            return
        }
        failed = false
        amountText = ""
        quantityText = "1"
        onSaved(Self.savedSentence(item: item, line: line, shop: session.shopName))
    }

    /// 0.5 is half a pound, which the scanned path has always been able to say. Blank, zero and
    /// anything that isn't a number are not quantities — and the save button stays off.
    static func quantity(from text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isNumber || $0 == "." }),
              cleaned.filter({ $0 == "." }).count <= 1,
              let value = Double(cleaned), value > 0, value <= 999 else { return nil }
        return value
    }

    /// Whole counts stay whole — "×2", never "×2.0".
    static func quantityText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }

    /// The number that was written, which for more than one is the price of one.
    static func savedSentence(item: CaptureMatch, line: CaptureLine, shop: String?) -> String {
        let each = line.showsEach ? " each" : ""
        let at = shop.map { " at \($0)" } ?? ""
        return "Saved: \(item.name) — \(line.unitAmount.display)\(each)\(at), typed."
    }

    /// Minor units, built with integers only: 4.49 has no exact Double and a price book that is
    /// off by a cent is a wrong price book. Anything else in the text is not a price.
    static func money(from text: String, currencyCode: String) -> Money? {
        guard text.allSatisfy({
            $0.isNumber || $0 == "." || $0 == "," || $0.isWhitespace || $0.isCurrencySymbol
        }) else { return nil }
        let digits = text.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        let parts = digits.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, digits.contains(where: \.isNumber), parts[0].count <= 9,
              let major = Int(parts[0].isEmpty ? "0" : String(parts[0])) else { return nil }
        let exponent = Money.minorUnitExponent(for: currencyCode)
        var minorUnits = major
        for _ in 0 ..< exponent { minorUnits *= 10 }
        guard exponent > 0, parts.count == 2 else {
            return Money(minorUnits: minorUnits, currencyCode: currencyCode)
        }
        // "4.4" is $4.40, not $4.04 — the fraction is padded on the right, like a till.
        let fraction = parts[1].prefix(exponent)
        let padded = fraction + String(repeating: "0", count: exponent - fraction.count)
        guard let cents = Int(String(padded)) else { return nil }
        return Money(minorUnits: minorUnits + cents, currencyCode: currencyCode)
    }
}
