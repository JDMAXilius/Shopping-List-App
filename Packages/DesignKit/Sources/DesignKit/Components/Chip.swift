import SwiftUI

/// The small pill: a word, optionally a glyph, on an inset capsule. One definition (W6-P4)
/// because ListScreen composed it inline twice — the shop chip on paper and the suggestion
/// chips on card — from a `capsuleSurface` that filled with card **both times**, so on card
/// the fill was invisible and only the hairline survived. Here the fill inverts against the
/// ground it is given (`Palette.Surface.insetFill`), which is the bug and the duplication
/// closed by the same parameter. Wave 6's receipt lines need the same pill for their
/// confidence markers and the `typed` tag.
///
/// **Tones are semantic, and there are two.** `.neutral` is everything that is simply
/// labelled — a shop, a suggestion, `typed`. `.attention` is a chip on something the user
/// still has to deal with; the persimmon it wears points at the row's own action, and the
/// chip itself never becomes the button.
///
/// **`sure` is NOT green — the ruling.** Green means done or measured and nothing else
/// (PRODUCT.md §2). A `sure` receipt line is the machine's confidence in its own parse,
/// before review commits anything: no money has been measured and nothing is done, so
/// painting it `confirmed` would spend the one colour that means *fact* on a guess — in the
/// exact place users are being asked to check the guess. `sure` is therefore `.neutral`: no
/// marker colour at all, which is also what "nothing needs you here" should look like.
/// `not sure` and `no match` are both `.attention` — they differ by their word, not their
/// colour, because the word is what says which of the two it is. There is no green chip
/// tone in this enum for anyone to reach for.
///
/// The Figma page's raw-hex amber (`#D9A03F`, recorded as a deviation) is refused rather
/// than promoted to a token: it measures 2.32:1 on card, so it can carry neither the label
/// nor the ring legibly — it could only ever have been a decorative dot.
public struct Chip: View {

    public enum Tone: Sendable, Hashable, CaseIterable {
        case neutral
        case attention
    }

    private let text: String
    private let glyph: CategoryGlyph?
    private let tone: Tone
    private let surface: Palette.Surface
    private let opensPicker: Bool
    private let spokenLabel: String?
    private let action: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var glyphSide: CGFloat = 18

    /// - Parameters:
    ///   - text: the word, always primary and always present — a chip is never a bare glyph.
    ///   - glyph: the leading line icon, decorative and hidden from VoiceOver.
    ///   - tone: `.neutral` unless the chip marks something still asking for the user.
    ///   - surface: the ground the chip SITS ON, not its fill. The fill inverts against it.
    ///   - opensPicker: the trailing chevron, for a chip that opens a choice instead of doing
    ///     its thing outright (the shop chip). Ignored on a tag — a thing that cannot be
    ///     tapped must not wear the mark of a thing that opens.
    ///   - accessibilityLabel: when the words on screen aren't the whole sentence VoiceOver
    ///     should hear — "Shopping at Tesco. Change shop." Defaults to `text`.
    ///   - action: `nil` means a tag, not a control: no button, no 44pt target, nothing that
    ///     fakes a tap. Non-nil means a real one, and the haptic belongs to the caller
    ///     because adding an item and opening a sheet do not deserve the same feedback.
    public init(
        _ text: String,
        glyph: CategoryGlyph? = nil,
        tone: Tone = .neutral,
        on surface: Palette.Surface,
        opensPicker: Bool = false,
        accessibilityLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.glyph = glyph
        self.tone = tone
        self.surface = surface
        self.opensPicker = opensPicker
        self.spokenLabel = accessibilityLabel
        self.action = action
    }

    @ViewBuilder public var body: some View {
        if let action {
            Button(action: action) { pill }
                .buttonStyle(.plain)
                .accessibilityLabel(spokenLabel ?? text)
        } else {
            pill
                .accessibilityElement(children: .combine)
                .accessibilityLabel(spokenLabel ?? text)
        }
    }

    private var isTappable: Bool { action != nil }

    private var pill: some View {
        HStack(spacing: 8) {
            if let glyph {
                GlyphShape(glyph)
                    .stroke(Palette.ink.color, style: StrokeStyle(
                        lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: glyphSide, height: glyphSide)
                    .accessibilityHidden(true)
            }
            Text(text)
                // A tag is smaller than a control on purpose: the same predicate that decides
                // the touch target decides the weight it pulls beside an item name.
                .font(isTappable ? Typography.body : Typography.footnote)
                .foregroundStyle(Self.label(tone: tone, on: surface).color)
                // At accessibility sizes the word wraps rather than truncating — "not su…"
                // is not a confidence marker.
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            if Self.showsDisclosure(opensPicker: opensPicker, isTappable: isTappable) {
                Image(systemName: "chevron.down")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.muted.color)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isTappable ? 0 : 6)
        .frame(minHeight: Self.minimumHeight(isTappable: isTappable))
        .background(
            Capsule()
                .fill(surface.insetFill.color)
                .overlay(Capsule().strokeBorder(Self.ring(tone: tone).color, lineWidth: 1)))
        .contentShape(Capsule())
    }

    /// The ring is the tone's carrier, because it is the part that survives everywhere: at
    /// 4.23:1 on paper and 4.64:1 on card, persimmon clears the 3:1 non-text floor on both
    /// grounds, while persimmon *text* is refused on one of them.
    static func ring(tone: Tone) -> Palette.RGB {
        switch tone {
        case .neutral: return Palette.line
        case .attention: return Palette.persimmon
        }
    }

    /// Neutral chips are ink — a chip label is the item's name or its tag, not commentary.
    /// Attention defers to the shared rule against the fill the label really sits on, so a
    /// chip inside a card draws ink and lets the ring carry the tone.
    static func label(tone: Tone, on surface: Palette.Surface) -> Palette.RGB {
        switch tone {
        case .neutral: return Palette.ink
        case .attention: return surface.inset.text(.attention)
        }
    }

    /// 44pt only when there is something to hit. A confidence marker with a touch target is
    /// a promise of a tap it does not have; `nil` leaves the tag its natural height.
    static func minimumHeight(isTappable: Bool) -> CGFloat? { isTappable ? 44 : nil }

    /// The chevron is a claim about what a tap does, so it cannot outlive the tap.
    static func showsDisclosure(opensPicker: Bool, isTappable: Bool) -> Bool {
        opensPicker && isTappable
    }
}
