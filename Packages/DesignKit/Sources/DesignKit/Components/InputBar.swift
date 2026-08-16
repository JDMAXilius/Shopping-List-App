import SwiftUI

/// The add bar: rounded field ("I need…") + persimmon mic circle. Pure presentation —
/// speech, resolving and adding are the caller's business; closures out only.
public struct InputBar: View {
    @Binding private var text: String
    private let placeholder: String
    private let focus: FocusState<Bool>.Binding?
    private let isMicEnabled: Bool
    private let onSubmit: () -> Void
    private let onMic: () -> Void

    public init(
        text: Binding<String>,
        placeholder: String = "I need…",
        focus: FocusState<Bool>.Binding? = nil,
        isMicEnabled: Bool = true,
        onSubmit: @escaping () -> Void,
        onMic: @escaping () -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.focus = focus
        self.isMicEnabled = isMicEnabled
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
                // Optional, so every existing caller is untouched (W5-P4 fix 2): a sheet
                // hands in its own FocusState to open with the keyboard already up —
                // otherwise "add an item" costs a tap it promised not to.
                .modifier(OptionalFocus(focus: focus))
            mic
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.card.color)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Palette.line.color, lineWidth: 1))
        )
    }

    /// Speech capture lands in wave 6; until then callers pass `isMicEnabled: false`
    /// rather than let an inert control look live.
    private var mic: some View {
        Button(action: onMic) {
            ZStack {
                // White on persimmon: the passing large-element combination on paper.
                // Disabled swaps ONE token — an inert control must never wear the action
                // colour — and the slashed glyph carries it too, never colour alone.
                Circle().fill(Self.micFill(isEnabled: isMicEnabled).color)
                Image(systemName: isMicEnabled ? "mic.fill" : "mic.slash.fill")
                    .font(Typography.body)
                    .foregroundStyle(Palette.card.color)
            }
            .frame(width: 36, height: 36)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        // Disabled means disabled: no onMic, and VoiceOver says so.
        .disabled(!isMicEnabled)
        .accessibilityLabel("Add by voice")
        .padding(.trailing, 6)
    }

    /// Kept pure so "the disabled mic is muted, not persimmon" is a test, not a promise.
    static func micFill(isEnabled: Bool) -> Palette.RGB {
        isEnabled ? Palette.persimmon : Palette.muted
    }
}

/// `.focused` takes a non-optional binding. This keeps the optionality out of the view
/// tree; the branch is fixed for the bar's lifetime, so identity never flips under it.
private struct OptionalFocus: ViewModifier {
    let focus: FocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let focus {
            content.focused(focus)
        } else {
            content
        }
    }
}
