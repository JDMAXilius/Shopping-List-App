import SwiftUI

/// The letterspaced small label — `TOTAL`, an aisle title, `COMPLETED (n)`, `NO PRICE YET`.
/// Before W6-P1 the treatment (`Typography.sectionLabel` + `labelTracking` + a colour
/// decision) was composed inline at six sites, which meant one rule was re-decided six
/// times: *persimmon at caption size holds contrast on card, never on paper*.
///
/// **How that rule is enforced, and why this way.** It lives in `Palette.Emphasis`, one home
/// for the three components that need it. The surface is a parameter and the colour is a
/// pure, total function: `.attention` cannot be asked for without naming the ground it lands
/// on, and `foreground(tone:surface:)` never returns a pair below 4.5:1 — on paper it refuses
/// persimmon rather than drawing it. The refusal is a unit test
/// (`ComponentSemanticsTests`), not a comment. A compile-time refusal was considered and
/// rejected: it would need the surface to reach the component through the environment from
/// a DesignKit-owned container, and features paint their own backgrounds today, so the
/// guarantee would be nominal — a caller could still hand a card container a paper fill.
/// Documentation alone is what produced the six copies, so it is not the answer either.
public struct SectionLabel: View {

    /// `.muted` is the section vocabulary — every label unless it is asking for something.
    /// `.attention` is the one persimmon exception and it is **card-only**; on paper the
    /// component refuses it (see `foreground`). Shared with `Chip` and `Notice` since W6-P4:
    /// the rule has one home (`Palette.Emphasis`), so persimmon is never re-reasoned.
    public typealias Tone = Palette.Emphasis

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

    /// A section label sits directly on its ground, so the ground IS the fill its text is
    /// drawn on — both of these are the shared rule, unwrapped for this component only.
    static func isLegible(tone: Tone, on surface: Palette.Surface) -> Bool {
        surface.allows(tone)
    }

    static func foreground(tone: Tone, surface: Palette.Surface) -> Palette.RGB {
        surface.text(tone)
    }
}
