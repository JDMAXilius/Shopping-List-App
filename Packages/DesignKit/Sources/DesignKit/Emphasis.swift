import SwiftUI

extension Palette {

    /// How loudly reading-size text speaks: quietly, or because it is asking for something.
    /// Two values, and there is deliberately no third — `confirmed` green states a fact
    /// (done / measured) and so is never an emphasis a caller can pick (PRODUCT.md §2).
    public enum Emphasis: Sendable, Hashable, CaseIterable {
        case muted
        case attention
    }
}

extension Palette.Surface {

    /// The other ground — what an element inset into this one is painted. `insetFill` is
    /// this surface's `fill`, kept as the shorthand every existing caller already uses.
    public var inset: Palette.Surface {
        switch self {
        case .paper: return .card
        case .card: return .paper
        }
    }

    /// Whether `emphasis` is legible at reading sizes on **this fill** — the fill the text is
    /// actually drawn on, which for a component with its own inset background is `inset`,
    /// not the ground it sits on. Persimmon measures 4.64:1 on card and 4.23:1 on paper, so
    /// on paper there is no legal small-text persimmon: PRODUCT.md §2's escapes (≥18pt, bold,
    /// or white on a persimmon fill) are all out of reach at footnote and caption size.
    /// Deliberately size-blind — a colour that changed with Dynamic Type would be a second
    /// style, so the strict case governs once, for everyone.
    public func allows(_ emphasis: Palette.Emphasis) -> Bool {
        switch (emphasis, self) {
        case (.muted, _), (.attention, .card): return true
        case (.attention, .paper): return false
        }
    }

    /// The colour actually drawn, total by construction: an illegible request falls back to
    /// ink — the strongest legible emphasis that is neither a second action colour nor a
    /// decorative one. Not muted: a silent downgrade would delete the signal along with the
    /// contrast bug. Components that must keep the signal visible where persimmon is refused
    /// carry it in a 1pt persimmon border instead, which only owes the 3:1 non-text floor.
    public func text(_ emphasis: Palette.Emphasis) -> Palette.RGB {
        guard allows(emphasis) else { return Palette.ink }
        switch emphasis {
        case .muted: return Palette.muted
        case .attention: return Palette.persimmon
        }
    }
}
