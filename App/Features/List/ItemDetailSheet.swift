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
            unitField(row)
            noteField(row)
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
    }

    private func quantityField(_ row: ListRow) -> some View {
        HStack {
            Text("Quantity")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
            Spacer(minLength: 12)
            stepButton("minus", row: row, delta: -1)
            Text(quantityLabel(row.item.quantity))
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

    private func unitField(_ row: ListRow) -> some View {
        HStack {
            Text("Unit")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
            Spacer(minLength: 12)
            TextField("none", text: $unit)
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
                .multilineTextAlignment(.trailing)
                .onSubmit {
                    store.edit(row.item, [.unit(unit.isEmpty ? nil : unit)])
                }
        }
        .frame(minHeight: 44)
    }

    private func noteField(_ row: ListRow) -> some View {
        TextField("Add a note", text: $note)
            .font(Typography.body)
            .foregroundStyle(Palette.ink.color)
            .padding(12)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.paper.color))
            .onSubmit {
                store.edit(row.item, [.note(note.isEmpty ? nil : note)])
            }
    }

    private func priceSection(_ row: ListRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT YOU PAID")
                .font(Typography.sectionLabel)
                .tracking(Typography.labelTracking)
                .foregroundStyle(Palette.muted.color)
            HStack {
                TextField("$0.00", text: $priceText)
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
            Button {
                guard let amount = ItemDetailSheet.money(from: priceText) else { return }
                store.setPrice(row.item, amount)
                dismiss()
            } label: {
                Text("Save price")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(store.activeShop == nil || ItemDetailSheet.money(from: priceText) == nil)
            .opacity(store.activeShop == nil || ItemDetailSheet.money(from: priceText) == nil ? 0.4 : 1)
        }
    }

    private func quantityLabel(_ quantity: Double) -> String {
        quantity == quantity.rounded() ? String(Int(quantity)) : String(format: "%.2g", quantity)
    }

    // Strict: digits and one separator. A price we can't read is not a price we save.
    static func money(from text: String) -> Money? {
        let cleaned = text.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard cleaned.contains(where: \.isNumber), parts.count <= 2,
              let whole = Int(parts[0].isEmpty ? "0" : String(parts[0]))
        else { return nil }
        guard parts.count == 2 else { return Money(minorUnits: whole * 100) }
        let fraction = parts[1].prefix(2)
        guard let cents = Int(fraction.isEmpty ? "0" : String(fraction) + (fraction.count == 1 ? "0" : ""))
        else { return nil }
        return Money(minorUnits: whole * 100 + cents)
    }
}
