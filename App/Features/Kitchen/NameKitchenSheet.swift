import DesignKit
import Foundation
import SwiftUI

/// Sheet 17 — "What do you call home?". Contextual: it appears because someone asked to
/// invite, never as a step of a wizard nobody asked for. Until then the kitchen is just
/// "your kitchen" and the app has never mentioned it.
struct NameKitchenSheet: View {
    let store: KitchenStore
    var onNamed: (() -> Void)?

    @State private var name = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    private static let suggestions = ["Home", "The flat", "Casa"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What do you call home?")
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            Text("Your lists live in your kitchen. Everyone you invite shares it.")
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .fixedSize(horizontal: false, vertical: true)
            Field("Kitchen name", text: $name, placeholder: "Flat 2B", on: .paper,
                  focus: $focused, onSubmit: save)
            HStack(spacing: 8) {
                ForEach(Self.suggestions, id: \.self) { suggestion in
                    Chip(suggestion, on: .paper) { name = suggestion }
                }
                Spacer(minLength: 0)
            }
            if let message = store.message {
                Notice(message, on: .paper)
            }
            Spacer(minLength: 0)
            Button(action: save) {
                Text(store.isWorking ? "Saving…" : "Continue")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(trimmed.isEmpty || store.isWorking)
            .opacity(trimmed.isEmpty || store.isWorking ? 0.4 : 1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.paper.color)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmed.isEmpty else { return }
        Task {
            guard await store.nameKitchen(trimmed) else { return }
            onNamed?()
            dismiss()
        }
    }
}
