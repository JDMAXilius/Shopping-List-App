import Core
import DesignKit
import Foundation
import SwiftUI

struct ItemDetailSheet: View {
    let store: ListStore
    let listItemID: ListItemID

    @State private var priceText = ""
    @State private var note = ""
    @State private var unit = ""
    @State private var loaded = false
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let row = store.rows.first(where: { $0.id == listItemID }) {
                content(row)
            } else {
                EmptyState(glyph: .other, message: "That item is no longer on the list.")
            }
        }
        .background(Palette.paper.color)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func content(_ row: ListRow) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                GlyphTile(row.category)
                Text(row.item.name)
                    .font(.system(.title2, weight: .bold))
                    .foregroundStyle(Palette.ink.color)
            }
            quantityField(row)
            unitField
            noteField
            priceSection(row)
            Spacer(minLength: 0)
            Button("Remove from list", role: .destructive) {
                store.remove(row.item)
                dismiss()
            }
            // Bold: persimmon text on paper only clears 4.5:1 as large or bold type.
            .font(.system(.body, weight: .bold))
            .foregroundStyle(Palette.persimmon.color)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(16)
        .task {
            guard !loaded else { return }
            loaded = true
            note = row.item.note ?? ""
            unit = row.item.unit ?? ""
        }
        // A swipe down is how this sheet is meant to close, so it must not be how edits die.
        .onDisappear(perform: commit)
    }

    private func quantityField(_ row: ListRow) -> some View {
        HStack {
            Text("Quantity")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
            Spacer(minLength: 12)
            stepButton("minus", row: row, delta: -1)
            // The row's own words: "×3", "1.5 lb", "½ dozen" — never a bare number the
            // list then renders differently.
            Text(QuantityText.label(quantity: row.item.quantity, unit: row.item.unit) ?? "1")
                .font(Typography.price)
                .foregroundStyle(Palette.ink.color)
                .frame(minWidth: 40)
            stepButton("plus", row: row, delta: 1)
        }
    }

    private func stepButton(_ symbol: String, row: ListRow, delta: Double) -> some View {
        Button {
            let next = max(1, row.item.quantity + delta)
            store.edit(row.item, [.quantity(next)])
        } label: {
            Image(systemName: symbol)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Palette.ink.color)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.paper.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "Increase quantity" : "Decrease quantity")
    }

    private var unitField: some View {
        HStack {
            Text("Unit")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
            Spacer(minLength: 12)
            TextField("none", text: $unit)
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
                .multilineTextAlignment(.trailing)
                .onSubmit(commit)
        }
        .frame(minHeight: 44)
    }

    private var noteField: some View {
        TextField("Add a note", text: $note)
            .font(Typography.body)
            .foregroundStyle(Palette.ink.color)
            .padding(12)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.paper.color))
            .onSubmit(commit)
    }

    private func priceSection(_ row: ListRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // The count has to be in the label or the number is ambiguous: on a ×4 row, "what
            // you paid" reads as the line to one person and as one item to the next, and the two
            // answers differ by 4×. EnterByHandScreen already says "for all 4" when it means the
            // line; this asks for one, so it says so. The two must not disagree.
            Text(row.item.quantity > 1 ? "WHAT ONE COST" : "WHAT YOU PAID")
                .font(Typography.sectionLabel)
                .tracking(Typography.labelTracking)
                .foregroundStyle(Palette.muted.color)
            HStack {
                // The kitchen's own money in the placeholder: this field only ever accepts it.
                TextField(Money(minorUnits: 0, currencyCode: store.currencyCode).display,
                          text: $priceText)
                    .font(Typography.total)
                    .foregroundStyle(Palette.ink.color)
                    .keyboardType(.decimalPad)
                Spacer(minLength: 12)
                // What the row shows today, in its own tier — never confusable with the entry.
                PriceLabel(row.price)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.paper.color))
            if store.activeShop == nil {
                Text("Pick a shop first — a price belongs to the shop you paid it at.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
            if failed {
                Notice("That price wasn't saved, and nothing on this row changed. Try it again.",
                       tone: .attention, on: .paper)
            }
            Button {
                guard let amount = writable else { return }
                commit()
                // A refused write keeps the sheet open: dismissing on it is the silence itself.
                guard store.setPrice(row.item, amount) else {
                    failed = true
                    return
                }
                dismiss()
            } label: {
                Text("Save price")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(writable == nil)
            .opacity(writable == nil ? 0.4 : 1)
        }
    }

    /// The money this sheet could actually write, or nil — which is exactly when the button is
    /// off. A price with no shop, no readable number or nothing in it is not offered as savable.
    private var writable: Money? {
        guard store.activeShop != nil,
              let amount = MoneyText.money(from: priceText, currencyCode: store.currencyCode),
              amount.minorUnits > 0 else { return nil }
        return amount
    }

    /// Everything typed and not yet stored, written once — on submit, on dismiss, and
    /// before any action that closes the sheet.
    private func commit() {
        guard let row = store.rows.first(where: { $0.id == listItemID }) else { return }
        let writes = ItemDetailSheet.edits(unit: unit, note: note, item: row.item)
        guard !writes.isEmpty else { return }
        store.edit(row.item, writes)
    }

    /// Only fields that actually differ from what is stored — an empty field means nil,
    /// never an empty string that reads as an edit next time.
    static func edits(unit: String, note: String, item: ListItem) -> [FieldWrite] {
        var writes: [FieldWrite] = []
        let unitValue = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteValue = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if unitValue != (item.unit ?? "") { writes.append(.unit(unitValue.isEmpty ? nil : unitValue)) }
        if noteValue != (item.note ?? "") { writes.append(.note(noteValue.isEmpty ? nil : noteValue)) }
        return writes
    }
}
