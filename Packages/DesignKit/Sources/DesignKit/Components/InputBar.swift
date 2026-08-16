import SwiftUI

/// The add bar: rounded field ("I need…") + persimmon mic circle. Pure presentation —
/// speech, resolving and adding are the caller's business; closures out only.
public struct InputBar: View {
    @Binding private var text: String
    private let placeholder: String
    private let onSubmit: () -> Void
    private let onMic: () -> Void

    public init(
        text: Binding<String>,
        placeholder: String = "I need…",
        onSubmit: @escaping () -> Void,
        onMic: @escaping () -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onMic = onMic
    }

    public var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text)
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
                .submitLabel(.done)
                .onSubmit(onSubmit)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
            Button(action: onMic) {
                ZStack {
                    // White on persimmon: the passing large-element combination on paper.
                    Circle().fill(Palette.persimmon.color)
                    Image(systemName: "mic.fill")
                        .font(Typography.body)
                        .foregroundStyle(Palette.card.color)
                }
                .frame(width: 36, height: 36)
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add by voice")
            .padding(.trailing, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.card.color)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Palette.line.color, lineWidth: 1))
        )
    }
}
