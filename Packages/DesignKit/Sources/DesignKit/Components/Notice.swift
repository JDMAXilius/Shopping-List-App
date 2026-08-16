import SwiftUI

/// One calm line on its own inset card — *"No signal — everything still works"*, *"Catch the
/// whole receipt in the frame"*, *"more than 3× the usual"*. ListScreen built this inline as
/// `offlineBanner` and wave 6 needs the same shape at least three more times, so it is one
/// component before it is four copies of a corner radius.
///
/// Never a toast, never a dismissable overlay: a notice sits in the flow, covers nothing and
/// takes no focus. It is not interactive, so it owes no 44pt target — anything with an action
/// on it is a control, and this is not one.
///
/// **Attention obeys the shared rule, and carries a border because of it.** The text sits on
/// the notice's own inset fill, so the ground that governs the colour is `surface.inset` —
/// a notice on paper is filled card and may draw persimmon (4.64:1); a notice inside a card
/// is filled paper, where small persimmon is refused (4.23:1) and the shared rule returns
/// ink. The 1pt persimmon border keeps the signal visible in that case at the 3:1 non-text
/// floor, which persimmon clears on both fills. Callers still write the flag into the words —
/// *"$14.00, more than 3× the usual $3.50"* — because a border alone says only "look here".
public struct Notice: View {

    /// The same two values as everywhere else; there is one emphasis rule in DesignKit.
    public typealias Tone = Palette.Emphasis

    private let text: String
    private let tone: Tone
    private let surface: Palette.Surface

    /// - Parameters:
    ///   - text: the whole sentence. Wraps rather than truncates at every type size.
    ///   - tone: `.muted` for a standing fact, `.attention` for something that needs a look.
    ///   - surface: the ground the notice SITS ON, not its fill — the fill inverts against it.
    public init(_ text: String, tone: Tone = .muted, on surface: Palette.Surface) {
        self.text = text
        self.tone = tone
        self.surface = surface
    }

    public var body: some View {
        Text(text)
            .font(Typography.footnote)
            .foregroundStyle(Self.foreground(tone: tone, on: surface).color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 40, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
    }

    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return shape.fill(surface.insetFill.color)
            .overlay {
                if let border = Self.border(tone: tone) {
                    shape.strokeBorder(border.color, lineWidth: 1)
                }
            }
    }

    /// Resolved against the fill the text is drawn on, not the ground the card sits on.
    static func foreground(tone: Tone, on surface: Palette.Surface) -> Palette.RGB {
        surface.inset.text(tone)
    }

    /// Only attention is outlined — a border on every notice would make the quiet ones loud.
    static func border(tone: Tone) -> Palette.RGB? {
        switch tone {
        case .muted: return nil
        case .attention: return Palette.persimmon
        }
    }
}
