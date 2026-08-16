import SwiftUI

/// The letterspaced small label — `TOTAL`, an aisle title, `COMPLETED (n)`, `NO PRICE YET`.
/// Before W6-P1 the treatment (`Typography.sectionLabel` + `labelTracking` + a colour
/// decision) was composed inline at six sites, which meant one rule was re-decided six
/// times: *persimmon at caption size holds contrast on card, never on paper*.
///
/// **How that rule is enforced here, and why this way.** The surface is a parameter and the
/// colour is a pure, total function: `.attention` cannot be asked for without naming the
/// ground it lands on, and `foreground(tone:surface:)` never returns a pair below 4.5:1 —
/// on paper it refuses persimmon rather than drawing it. The refusal is a unit test
/// (`ComponentSemanticsTests`), not a comment. A compile-time refusal was considered and
/// rejected: it would need the surface to reach the component through the environment from
/// a DesignKit-owned container, and features paint their own backgrounds today, so the
/// guarantee would be nominal — a caller could still hand a card container a paper fill.
/// Documentation alone is what produced the six copies, so it is not the answer either.
public struct SectionLabel: View {

    /// `.muted` is the section vocabulary — every label unless it is asking for something.
    /// `.attention` is the one persimmon exception and it is **card-only**; on paper the
    /// component refuses it (see `foreground`).
    public enum Tone: Sendable, Hashable {
        case muted
        case attention
    }

    private let text: String
    private let tone: Tone
    private let surface: Palette.Surface

    /// The default label: muted, on either ground. Muted is contrast-verified on BOTH
    /// (4.87:1 paper / 5.34:1 card), so this initializer needs no surface and there is no
    /// way to place it wrongly — which is why it is the one-argument call.
    public init(_ text: String) {
        self.init(text, tone: .muted, on: .card)
    }

    /// Choosing a tone means naming the ground, because only one tone is ground-dependent.
    /// - Parameters:
    ///   - text: the words, in whatever case reads best — VoiceOver speaks these verbatim.
    ///   - tone: `.muted` for a section, `.attention` for one that is asking for something.
    ///   - surface: what the label is drawn ON, not what it is drawn in.
    public init(_ text: String, tone: Tone, on surface: Palette.Surface) {
        self.text = text
        self.tone = tone
        self.surface = surface
    }

    public var body: some View {
        Text(Self.display(text))
            .font(Typography.sectionLabel)
            .tracking(Typography.labelTracking)
            .foregroundStyle(Self.foreground(tone: tone, surface: surface).color)
            // Uppercase is a rendering, not the words: VoiceOver gets the caller's casing,
            // so "AISLE ORDER · TESCO" is never spelled out letter by letter.
            .accessibilityLabel(text)
    }

    /// Uppercase belongs to the treatment, so it lives here with the tracking rather than
    /// at each call site. Idempotent, so already-uppercased callers render identically.
    static func display(_ text: String) -> String { text.uppercased() }

    /// Whether a tone is legible at caption size on a given ground — the whole rule as one
    /// predicate. Persimmon measures 4.64:1 on card and 4.23:1 on paper; a section label is
    /// caption-size at default Dynamic Type, so on paper there is no legal persimmon form
    /// (PRODUCT.md §2's ≥18pt / bold / white-on-fill escapes are all out of reach at that
    /// size). Deliberately size-blind: at accessibility sizes caption grows past 18pt and
    /// 4.23:1 would clear the large-text floor, but a colour that changes with Dynamic Type
    /// is a second style — the strict case governs, once, for everyone.
    static func isLegible(tone: Tone, on surface: Palette.Surface) -> Bool {
        switch (tone, surface) {
        case (.muted, _), (.attention, .card): return true
        case (.attention, .paper): return false
        }
    }

    /// The colour actually drawn. Total by construction: an illegible request falls back to
    /// ink — the strongest legible emphasis in the token set that is *not* the action colour,
    /// so nothing gains a second action colour and nothing gains a decorative one. It is
    /// deliberately not muted: a silent downgrade would delete the signal as well as the
    /// contrast bug, and the caller would never find out.
    static func foreground(tone: Tone, surface: Palette.Surface) -> Palette.RGB {
        guard isLegible(tone: tone, on: surface) else { return Palette.ink }
        switch tone {
        case .muted: return Palette.muted
        case .attention: return Palette.persimmon
        }
    }
}
