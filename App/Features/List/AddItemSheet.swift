import Core
import DesignKit
import Foundation
import SwiftUI

struct AddItemSheet: View {
    let store: ListStore

    @State private var draft = ""
    @State private var showSpeechNote = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InputBar(text: $draft, placeholder: "I need…", onSubmit: submit,
                     onMic: { showSpeechNote = true })
            if showSpeechNote {
                // The stub, and it says so: SpeechService lands with the capture work.
                Text("Hold-to-speak isn't wired up yet. Type it for now.")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.suggestions(for: draft)) { suggestion in
                        row(suggestion)
                    }
                    if !typed.isEmpty {
                        asTypedRow
                    }
                }
            }
            Text("Prices show what you last paid")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Palette.paper.color)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var typed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func row(_ suggestion: ItemSuggestion) -> some View {
        Button { add(suggestion.name) } label: {
            HStack(spacing: 12) {
                GlyphTile(suggestion.category)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.name)
                        .font(Typography.itemName)
                        .foregroundStyle(Palette.ink.color)
                        .lineLimit(1)
                    if let detail = suggestion.detail {
                        Text(detail)
                            .font(Typography.footnote)
                            .foregroundStyle(Palette.muted.color)
                    }
                }
                Spacer(minLength: 12)
                PriceLabel(suggestion.price)
            }
            .padding(12)
            .frame(minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(suggestion.name), \(suggestion.price.accessibilityPhrase)")
    }

    private var asTypedRow: some View {
        Button { add(typed) } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(.body, weight: .semibold))
                Text("Add “\(typed)” as typed")
                    .font(.system(.body, weight: .semibold))
            }
            // Persimmon body text needs the card behind it to hold 4.5:1.
            .foregroundStyle(Palette.persimmon.color)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
        }
        .buttonStyle(.plain)
    }

    // Adding keeps the sheet open — the next item is one keystroke away.
    private func add(_ text: String) {
        store.add(text: text)
        draft = ""
    }

    private func submit() {
        guard !typed.isEmpty else {
            dismiss()
            return
        }
        add(typed)
    }
}
