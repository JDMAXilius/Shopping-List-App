import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A labelled text input on an inset rounded fill. `ItemDetailSheet` and `ShopSwitcherSheet`
/// each hand-composed this — and the sheets' copies fill with `paper` on a `paper` sheet, so
/// the input has no visible edge at all. Enter-by-hand needs a row of them, so it becomes one
/// component whose fill inverts against the ground it is given.
///
/// A Field never formats money: it shows the characters typed and nothing else — no currency
/// symbol, no rounding, no `~` or `≈`. Every price it captures renders through `PriceLabel`.
public struct Field: View {

    /// Only the two entry kinds the app actually has. Not a passthrough for
    /// `UIKeyboardType` — a field has no business offering a URL or Twitter keyboard.
    public enum Keyboard: Sendable, Hashable {
        case text
        case decimal
    }

    private let label: String
    private let placeholder: String
    private let affix: String?
    private let keyboard: Keyboard
    private let surface: Palette.Surface
    private let focus: FocusState<Bool>.Binding?
    private let onSubmit: () -> Void

    @Binding private var text: String

    /// - Parameters:
    ///   - label: the words above the box. Above, never beside: a label in a leading column
    ///     steals the field's width at accessibility sizes (the same rule that puts an item's
    ///     quantity under its name). It is also what VoiceOver reads for the input.
    ///   - placeholder: the hint inside the empty box; never the only label.
    ///   - affix: a trailing unit — `lb`, `oz`, `%`. Blank is no affix.
    ///   - keyboard: `.decimal` for amounts, which also renders the entry in the tabular
    ///     mono digits prices are always set in — the glyphs, not a money format.
    ///   - surface: the ground the field SITS ON, not its fill.
    ///   - focus: optional, like `InputBar` — hand one in to open with the keyboard already up.
    ///   - onSubmit: return was pressed. Committing is the caller's business.
    public init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        affix: String? = nil,
        keyboard: Keyboard = .text,
        on surface: Palette.Surface,
        focus: FocusState<Bool>.Binding? = nil,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.affix = affix
        self.keyboard = keyboard
        self.surface = surface
        self.focus = focus
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Hidden from VoiceOver: the input below speaks these words as its own label, and
            // hearing them twice on the way into a field is noise.
            SectionLabel(label)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .font(Self.usesTabularDigits(keyboard) ? Typography.price : Typography.body)
                    .foregroundStyle(Palette.ink.color)
                    .submitLabel(.done)
                    .onSubmit(onSubmit)
                    .modifier(OptionalFocus(focus: focus))
                    .modifier(KeyboardStyle(keyboard: keyboard))
                    .accessibilityLabel(FieldSemantics.spokenLabel(label: label, affix: affix))
                if let visible = FieldSemantics.visibleAffix(affix) {
                    Text(visible)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                        // Spoken as part of the field's label, so it is not a second stop.
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(surface.insetFill.color))
        }
    }

    /// Digits the user types line up in the mono column the app sets every price in. This is
    /// the typeface for numerals — the formatting still belongs entirely to `PriceLabel`.
    static func usesTabularDigits(_ keyboard: Keyboard) -> Bool { keyboard == .decimal }
}

/// Field's promises, pure — testable without a harness.
enum FieldSemantics {

    /// A blank affix is no affix: never an empty trailing gap holding the box open.
    static func visibleAffix(_ affix: String?) -> String? {
        guard let affix else { return nil }
        let trimmed = affix.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// One phrase, in the order it is written: "Quantity, lb".
    static func spokenLabel(label: String, affix: String?) -> String {
        guard let unit = visibleAffix(affix) else { return label }
        return "\(label), \(unit)"
    }
}

/// `.keyboardType` is UIKit-only; the package builds for macOS too so the gate can run tests.
private struct KeyboardStyle: ViewModifier {
    let keyboard: Field.Keyboard

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content.keyboardType(keyboard == .decimal ? .decimalPad : .default)
        #else
        content
        #endif
    }
}
