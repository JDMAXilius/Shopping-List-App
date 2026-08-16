import SwiftUI

// The single style (PRODUCT.md §2). A plain module, not a themed provider:
// no light/dark, no variants — the app renders identically under every system setting.
public enum Palette {

    /// Raw sRGB components (0…1) so tests can do WCAG math without SwiftUI.
    public struct RGB: Hashable, Sendable {
        public let r: Double
        public let g: Double
        public let b: Double

        public init(_ r255: Int, _ g255: Int, _ b255: Int) {
            self.r = Double(r255) / 255
            self.g = Double(g255) / 255
            self.b = Double(b255) / 255
        }

        public var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    }

    // MARK: Ground

    public static let paper = RGB(0xF7, 0xF4, 0xEE)      // #F7F4EE
    public static let card  = RGB(0xFF, 0xFF, 0xFF)      // #FFFFFF
    public static let ink   = RGB(0x19, 0x17, 0x13)      // #191713
    public static let line  = RGB(0xE4, 0xDF, 0xD5)      // #E4DFD5

    // #716A5F, NOT the Figma #8C857A — the original fails 4.5:1 on paper (3.33:1)
    // and card (3.65:1); this one measures 4.87:1 / 5.34:1. Estimates must be readable.
    public static let muted = RGB(0x71, 0x6A, 0x5F)

    // MARK: Semantics

    // The ONLY action colour. W4-C1 ruling: darkened one step from #C9502C (4.4993:1,
    // fails strict 4.5) to pass STRICTLY — #C64E2B measures 4.64:1 against #FFFFFF in
    // both directions. Body-size persimmon passes on card but NOT on paper (4.23:1) —
    // on paper: ≥18pt, bold, or a fill behind white text only.
    public static let persimmon = RGB(0xC6, 0x4E, 0x2B)  // #C64E2B

    // Semantic only: done / measured. Never decorative (PRODUCT.md §2).
    public static let confirmed = RGB(0x1F, 0x7A, 0x4D)  // #1F7A4D

    // MARK: Aisle tints

    public static let tintProduce   = RGB(0xB9, 0xCD, 0xA8)  // #B9CDA8
    public static let tintDairy     = RGB(0xF1, 0xDC, 0xA4)  // #F1DCA4
    public static let tintBakery    = RGB(0xEF, 0xC2, 0xB4)  // #EFC2B4
    public static let tintFrozen    = RGB(0xB7, 0xCC, 0xDD)  // #B7CCDD
    public static let tintHousehold = RGB(0xD0, 0xC4, 0xE0)  // #D0C4E0
    public static let tintPantry    = RGB(0xDD, 0xC5, 0xAA)  // #DDC5AA

    public static let aisleTints: [RGB] = [
        tintProduce, tintDairy, tintBakery, tintFrozen, tintHousehold, tintPantry,
    ]
}

extension Palette {

    /// Which of the two grounds a component has been placed on. NOT a theme and not an
    /// appearance variant — there is still exactly one style (PRODUCT.md §2); this only
    /// names where a component sits, because two rules depend on it: persimmon's contrast
    /// floor (`SectionLabel.Tone.attention`) and the fill inversion (`UndoBar`). Naming it
    /// once is what stops every screen guessing it again.
    public enum Surface: Sendable, Hashable, CaseIterable {
        case paper
        case card

        /// The ground itself.
        public var fill: RGB {
            switch self {
            case .paper: return Palette.paper
            case .card: return Palette.card
            }
        }

        /// The fill an inset element wears so it reads AS an element on this ground:
        /// paper inside a card, card on the paper background. Card-on-card is invisible,
        /// which is exactly the per-screen guess this property replaces.
        public var insetFill: RGB {
            switch self {
            case .paper: return Palette.card
            case .card: return Palette.paper
            }
        }
    }
}
