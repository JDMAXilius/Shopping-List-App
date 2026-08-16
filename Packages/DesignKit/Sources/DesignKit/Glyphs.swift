import SwiftUI

// The line-icon system as code (PRODUCT.md §2 imagery): monoline glyphs in a 24×24
// design space, stroke weight 2, stroke bound to ink by the consuming view. Never filled.
public enum CategoryGlyph: String, CaseIterable, Sendable {
    case produce, bakery, deli, meat, seafood, dairy
    case plantMilk = "plant-milk"
    case frozen, breakfast
    case pantryDry = "pantry-dry"
    case canned, condiments, baking, spices, snacks, beverages
    case coffeeTea = "coffee-tea"
    case household
    case personalCare = "personal-care"
    case baby, pet, other

    /// Canonical mapping of the 22 catalog categories onto the six aisle tints.
    public var tint: Palette.RGB {
        switch self {
        case .produce:
            return Palette.tintProduce
        case .dairy, .plantMilk:
            return Palette.tintDairy
        case .bakery, .breakfast, .meat, .deli:
            return Palette.tintBakery
        case .frozen, .seafood:
            return Palette.tintFrozen
        case .household, .personalCare, .baby, .pet:
            return Palette.tintHousehold
        case .pantryDry, .canned, .condiments, .baking, .spices,
             .snacks, .beverages, .coffeeTea, .other:
            return Palette.tintPantry
        }
    }

    public var shape: GlyphShape { GlyphShape(self) }
}

/// One `Shape` per glyph, parameterized — the switch is compile-time exhaustive.
public struct GlyphShape: Shape {
    public let glyph: CategoryGlyph

    public init(_ glyph: CategoryGlyph) { self.glyph = glyph }

    public func path(in rect: CGRect) -> Path {
        let design = designPath()
        let scale = min(rect.width, rect.height) / 24
        let dx = rect.midX - 12 * scale
        let dy = rect.midY - 12 * scale
        return design.applying(
            CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(CGAffineTransform(translationX: dx, y: dy)))
    }

    // MARK: 24×24 design space

    private func designPath() -> Path {
        var p = Path()
        switch glyph {
        case .produce: produce(&p)
        case .bakery: bakery(&p)
        case .deli: deli(&p)
        case .meat: meat(&p)
        case .seafood: seafood(&p)
        case .dairy: dairy(&p)
        case .plantMilk: plantMilk(&p)
        case .frozen: frozen(&p)
        case .breakfast: breakfast(&p)
        case .pantryDry: pantryDry(&p)
        case .canned: canned(&p)
        case .condiments: condiments(&p)
        case .baking: baking(&p)
        case .spices: spices(&p)
        case .snacks: snacks(&p)
        case .beverages: beverages(&p)
        case .coffeeTea: coffeeTea(&p)
        case .household: household(&p)
        case .personalCare: personalCare(&p)
        case .baby: baby(&p)
        case .pet: pet(&p)
        case .other: other(&p)
        }
        return p
    }

    private func line(_ p: inout Path, _ a: CGPoint, _ b: CGPoint) {
        p.move(to: a)
        p.addLine(to: b)
    }

    private func circle(_ p: inout Path, _ center: CGPoint, _ r: CGFloat) {
        p.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
    }

    // Apple: body + stem + leaf.
    private func produce(_ p: inout Path) {
        p.addEllipse(in: CGRect(x: 5.5, y: 9, width: 13, height: 12))
        line(&p, CGPoint(x: 12, y: 8.6), CGPoint(x: 12, y: 5))
        p.move(to: CGPoint(x: 12.2, y: 6.2))
        p.addQuadCurve(to: CGPoint(x: 16.8, y: 4.2), control: CGPoint(x: 13.5, y: 3.4))
    }

    // Bread loaf with two score marks.
    private func bakery(_ p: inout Path) {
        p.move(to: CGPoint(x: 4, y: 17.5))
        p.addLine(to: CGPoint(x: 4, y: 12))
        p.addQuadCurve(to: CGPoint(x: 12, y: 6.5), control: CGPoint(x: 4, y: 6.5))
        p.addQuadCurve(to: CGPoint(x: 20, y: 12), control: CGPoint(x: 20, y: 6.5))
        p.addLine(to: CGPoint(x: 20, y: 17.5))
        p.closeSubpath()
        line(&p, CGPoint(x: 10, y: 9), CGPoint(x: 8.5, y: 11.8))
        line(&p, CGPoint(x: 14.2, y: 9), CGPoint(x: 12.7, y: 11.8))
    }

    // Salami slice: ring + three fat flecks.
    private func deli(_ p: inout Path) {
        p.addEllipse(in: CGRect(x: 4, y: 4, width: 16, height: 16))
        circle(&p, CGPoint(x: 9.2, y: 10), 1.2)
        circle(&p, CGPoint(x: 14.6, y: 9.4), 1.2)
        circle(&p, CGPoint(x: 11.6, y: 15), 1.2)
    }

    // Drumstick: body + bone + two knobs.
    private func meat(_ p: inout Path) {
        p.addEllipse(in: CGRect(x: 3.8, y: 3.8, width: 11.5, height: 11.5))
        line(&p, CGPoint(x: 13.6, y: 12.6), CGPoint(x: 17, y: 16))
        line(&p, CGPoint(x: 12.6, y: 13.6), CGPoint(x: 16, y: 17))
        circle(&p, CGPoint(x: 18.4, y: 16.8), 1.8)
        circle(&p, CGPoint(x: 16.8, y: 18.4), 1.8)
    }

    // Fish: two arcs, tail, eye.
    private func seafood(_ p: inout Path) {
        p.move(to: CGPoint(x: 3.5, y: 12))
        p.addQuadCurve(to: CGPoint(x: 17, y: 12), control: CGPoint(x: 10, y: 5))
        p.addQuadCurve(to: CGPoint(x: 3.5, y: 12), control: CGPoint(x: 10, y: 19))
        p.move(to: CGPoint(x: 17, y: 12))
        p.addLine(to: CGPoint(x: 21, y: 8.2))
        p.move(to: CGPoint(x: 17, y: 12))
        p.addLine(to: CGPoint(x: 21, y: 15.8))
        circle(&p, CGPoint(x: 7.6, y: 10.6), 0.9)
    }

    // Milk carton: gabled body + ridge + cap.
    private func dairy(_ p: inout Path) {
        p.move(to: CGPoint(x: 6, y: 20))
        p.addLine(to: CGPoint(x: 6, y: 9))
        p.addLine(to: CGPoint(x: 9, y: 4))
        p.addLine(to: CGPoint(x: 15, y: 4))
        p.addLine(to: CGPoint(x: 18, y: 9))
        p.addLine(to: CGPoint(x: 18, y: 20))
        p.closeSubpath()
        line(&p, CGPoint(x: 6, y: 9), CGPoint(x: 18, y: 9))
        circle(&p, CGPoint(x: 12, y: 6.5), 1.2)
    }

    // Carton silhouette with a leaf inside.
    private func plantMilk(_ p: inout Path) {
        p.move(to: CGPoint(x: 6.5, y: 20))
        p.addLine(to: CGPoint(x: 6.5, y: 9.5))
        p.addLine(to: CGPoint(x: 12, y: 4.5))
        p.addLine(to: CGPoint(x: 17.5, y: 9.5))
        p.addLine(to: CGPoint(x: 17.5, y: 20))
        p.closeSubpath()
        p.move(to: CGPoint(x: 9.6, y: 16.4))
        p.addQuadCurve(to: CGPoint(x: 14.4, y: 11.8), control: CGPoint(x: 9.4, y: 11.6))
        p.addQuadCurve(to: CGPoint(x: 9.6, y: 16.4), control: CGPoint(x: 14.6, y: 16.4))
    }

    // Snowflake: three spokes + one chevron.
    private func frozen(_ p: inout Path) {
        line(&p, CGPoint(x: 12, y: 4), CGPoint(x: 12, y: 20))
        line(&p, CGPoint(x: 5.1, y: 8), CGPoint(x: 18.9, y: 16))
        line(&p, CGPoint(x: 18.9, y: 8), CGPoint(x: 5.1, y: 16))
        p.move(to: CGPoint(x: 10, y: 6.4))
        p.addLine(to: CGPoint(x: 12, y: 8.4))
        p.addLine(to: CGPoint(x: 14, y: 6.4))
    }

    // Bowl with rim and two curls of steam.
    private func breakfast(_ p: inout Path) {
        p.move(to: CGPoint(x: 4, y: 12))
        p.addQuadCurve(to: CGPoint(x: 20, y: 12), control: CGPoint(x: 12, y: 21.5))
        line(&p, CGPoint(x: 4, y: 12), CGPoint(x: 20, y: 12))
        p.move(to: CGPoint(x: 9, y: 8.5))
        p.addCurve(to: CGPoint(x: 9, y: 3.5),
                   control1: CGPoint(x: 10.6, y: 7.2), control2: CGPoint(x: 7.4, y: 4.8))
        p.move(to: CGPoint(x: 14.5, y: 8.5))
        p.addCurve(to: CGPoint(x: 14.5, y: 3.5),
                   control1: CGPoint(x: 16.1, y: 7.2), control2: CGPoint(x: 12.9, y: 4.8))
    }

    // Storage jar: lid + body + fill line.
    private func pantryDry(_ p: inout Path) {
        p.addRoundedRect(in: CGRect(x: 8, y: 4, width: 8, height: 2.6), cornerSize: CGSize(width: 1, height: 1))
        p.addRoundedRect(in: CGRect(x: 6.5, y: 6.6, width: 11, height: 13.4), cornerSize: CGSize(width: 2.5, height: 2.5))
        line(&p, CGPoint(x: 6.5, y: 11.2), CGPoint(x: 17.5, y: 11.2))
    }

    // Tin can: lid ellipse, sides, bottom curve, label line.
    private func canned(_ p: inout Path) {
        p.addEllipse(in: CGRect(x: 6, y: 3.6, width: 12, height: 4.4))
        line(&p, CGPoint(x: 6, y: 5.8), CGPoint(x: 6, y: 18.6))
        line(&p, CGPoint(x: 18, y: 5.8), CGPoint(x: 18, y: 18.6))
        p.move(to: CGPoint(x: 6, y: 18.6))
        p.addQuadCurve(to: CGPoint(x: 18, y: 18.6), control: CGPoint(x: 12, y: 21.4))
        line(&p, CGPoint(x: 6, y: 12.2), CGPoint(x: 18, y: 12.2))
    }

    // Squeeze bottle: tip, shoulders, body.
    private func condiments(_ p: inout Path) {
        p.move(to: CGPoint(x: 11, y: 3.5))
        p.addLine(to: CGPoint(x: 13, y: 3.5))
        p.addLine(to: CGPoint(x: 12.7, y: 6))
        p.addLine(to: CGPoint(x: 11.3, y: 6))
        p.closeSubpath()
        line(&p, CGPoint(x: 11.3, y: 6), CGPoint(x: 9.4, y: 8.4))
        line(&p, CGPoint(x: 12.7, y: 6), CGPoint(x: 14.6, y: 8.4))
        p.addRoundedRect(in: CGRect(x: 8.2, y: 8.4, width: 7.6, height: 12), cornerSize: CGSize(width: 2.6, height: 2.6))
    }

    // Whisk: handle + three nested loops.
    private func baking(_ p: inout Path) {
        line(&p, CGPoint(x: 12, y: 3.4), CGPoint(x: 12, y: 9))
        p.addEllipse(in: CGRect(x: 10.5, y: 9, width: 3, height: 11.2))
        p.addEllipse(in: CGRect(x: 8.7, y: 9, width: 6.6, height: 11.2))
        p.addEllipse(in: CGRect(x: 7, y: 9, width: 10, height: 11.2))
    }

    // Spice shaker: dome, three holes, body.
    private func spices(_ p: inout Path) {
        p.move(to: CGPoint(x: 8, y: 9))
        p.addQuadCurve(to: CGPoint(x: 16, y: 9), control: CGPoint(x: 12, y: 3))
        circle(&p, CGPoint(x: 10.4, y: 6.9), 0.6)
        circle(&p, CGPoint(x: 12, y: 6), 0.6)
        circle(&p, CGPoint(x: 13.6, y: 6.9), 0.6)
        p.addRoundedRect(in: CGRect(x: 7.8, y: 9, width: 8.4, height: 11.2), cornerSize: CGSize(width: 2, height: 2))
    }

    // Chip bag: body, two crimps, a chevron chip.
    private func snacks(_ p: inout Path) {
        p.addRoundedRect(in: CGRect(x: 6, y: 5.6, width: 12, height: 12.8), cornerSize: CGSize(width: 1.5, height: 1.5))
        line(&p, CGPoint(x: 6, y: 8), CGPoint(x: 18, y: 8))
        line(&p, CGPoint(x: 6, y: 16), CGPoint(x: 18, y: 16))
        p.move(to: CGPoint(x: 10.6, y: 13))
        p.addLine(to: CGPoint(x: 12, y: 11.5))
        p.addLine(to: CGPoint(x: 13.4, y: 13))
    }

    // Bottle: cap + necked body.
    private func beverages(_ p: inout Path) {
        p.addRoundedRect(in: CGRect(x: 10.3, y: 3, width: 3.4, height: 2.4), cornerSize: CGSize(width: 0.8, height: 0.8))
        p.move(to: CGPoint(x: 10.6, y: 5.4))
        p.addLine(to: CGPoint(x: 10.6, y: 8.8))
        p.addCurve(to: CGPoint(x: 8.2, y: 12.5),
                   control1: CGPoint(x: 10.6, y: 10.2), control2: CGPoint(x: 8.2, y: 10.8))
        p.addLine(to: CGPoint(x: 8.2, y: 18.2))
        p.addQuadCurve(to: CGPoint(x: 9.8, y: 19.8), control: CGPoint(x: 8.2, y: 19.8))
        p.addLine(to: CGPoint(x: 14.2, y: 19.8))
        p.addQuadCurve(to: CGPoint(x: 15.8, y: 18.2), control: CGPoint(x: 15.8, y: 19.8))
        p.addLine(to: CGPoint(x: 15.8, y: 12.5))
        p.addCurve(to: CGPoint(x: 13.4, y: 8.8),
                   control1: CGPoint(x: 15.8, y: 10.8), control2: CGPoint(x: 13.4, y: 10.2))
        p.addLine(to: CGPoint(x: 13.4, y: 5.4))
        p.closeSubpath()
    }

    // Mug: body, handle, one curl of steam.
    private func coffeeTea(_ p: inout Path) {
        p.move(to: CGPoint(x: 5.5, y: 8))
        p.addLine(to: CGPoint(x: 5.5, y: 17))
        p.addQuadCurve(to: CGPoint(x: 7.5, y: 19), control: CGPoint(x: 5.5, y: 19))
        p.addLine(to: CGPoint(x: 14, y: 19))
        p.addQuadCurve(to: CGPoint(x: 16, y: 17), control: CGPoint(x: 16, y: 19))
        p.addLine(to: CGPoint(x: 16, y: 8))
        p.closeSubpath()
        p.move(to: CGPoint(x: 16, y: 10))
        p.addCurve(to: CGPoint(x: 16, y: 15),
                   control1: CGPoint(x: 20.6, y: 10.4), control2: CGPoint(x: 20.6, y: 14.6))
        p.move(to: CGPoint(x: 10.75, y: 3))
        p.addCurve(to: CGPoint(x: 10.75, y: 6),
                   control1: CGPoint(x: 12, y: 3.8), control2: CGPoint(x: 9.5, y: 5.2))
    }

    // Spray bottle: head, spout, trigger, neck, body.
    private func household(_ p: inout Path) {
        p.move(to: CGPoint(x: 8.8, y: 7.4))
        p.addLine(to: CGPoint(x: 8.8, y: 4.4))
        p.addLine(to: CGPoint(x: 15.4, y: 4.4))
        p.addLine(to: CGPoint(x: 15.4, y: 7.4))
        p.closeSubpath()
        line(&p, CGPoint(x: 15.4, y: 5.4), CGPoint(x: 18, y: 5.4))
        line(&p, CGPoint(x: 8.8, y: 7.4), CGPoint(x: 7, y: 9.6))
        line(&p, CGPoint(x: 10, y: 7.4), CGPoint(x: 9.4, y: 11))
        line(&p, CGPoint(x: 14.2, y: 7.4), CGPoint(x: 14.8, y: 11))
        p.addRoundedRect(in: CGRect(x: 8.6, y: 11, width: 7.2, height: 9), cornerSize: CGSize(width: 2, height: 2))
    }

    // Lotion pump: arm + body + fill line.
    private func personalCare(_ p: inout Path) {
        p.move(to: CGPoint(x: 10.6, y: 10.4))
        p.addLine(to: CGPoint(x: 10.6, y: 4.6))
        p.addLine(to: CGPoint(x: 14.8, y: 4.6))
        p.addLine(to: CGPoint(x: 14.8, y: 6.6))
        p.addRoundedRect(in: CGRect(x: 7.8, y: 10.4, width: 8.4, height: 9.6), cornerSize: CGSize(width: 2, height: 2))
        line(&p, CGPoint(x: 7.8, y: 14.4), CGPoint(x: 16.2, y: 14.4))
    }

    // Baby bottle: teat, collar, body, two ticks.
    private func baby(_ p: inout Path) {
        p.move(to: CGPoint(x: 10.2, y: 5.4))
        p.addQuadCurve(to: CGPoint(x: 13.8, y: 5.4), control: CGPoint(x: 12, y: 2.4))
        line(&p, CGPoint(x: 10.2, y: 5.4), CGPoint(x: 9.4, y: 7.6))
        line(&p, CGPoint(x: 13.8, y: 5.4), CGPoint(x: 14.6, y: 7.6))
        line(&p, CGPoint(x: 9.4, y: 7.6), CGPoint(x: 14.6, y: 7.6))
        p.addRoundedRect(in: CGRect(x: 8.4, y: 7.6, width: 7.2, height: 12.6), cornerSize: CGSize(width: 2.4, height: 2.4))
        line(&p, CGPoint(x: 8.4, y: 11.6), CGPoint(x: 11, y: 11.6))
        line(&p, CGPoint(x: 8.4, y: 14.6), CGPoint(x: 11, y: 14.6))
    }

    // Paw: pad + three toes.
    private func pet(_ p: inout Path) {
        p.addEllipse(in: CGRect(x: 8, y: 12, width: 8, height: 7))
        circle(&p, CGPoint(x: 7.4, y: 9), 1.6)
        circle(&p, CGPoint(x: 12, y: 7.2), 1.6)
        circle(&p, CGPoint(x: 16.6, y: 9), 1.6)
    }

    // Price tag: rotated tag + hole.
    private func other(_ p: inout Path) {
        p.move(to: CGPoint(x: 4.5, y: 4.5))
        p.addLine(to: CGPoint(x: 11.5, y: 4.5))
        p.addLine(to: CGPoint(x: 19.5, y: 12.5))
        p.addLine(to: CGPoint(x: 12.5, y: 19.5))
        p.addLine(to: CGPoint(x: 4.5, y: 11.5))
        p.closeSubpath()
        circle(&p, CGPoint(x: 8.4, y: 8.4), 1.4)
    }
}

/// Rounded tile in the category tint, glyph stroked in ink. Decorative only —
/// the text label is always primary; a tile never carries meaning alone.
/// W4-C1 lead ruling: SOLID TINT FILL is canonical (08-prices); 01-list's white+ring
/// treatment is superseded. Item-specific glyphs stay progressive per PRODUCT §2.
public struct GlyphTile: View {
    private enum Content {
        case category(CategoryGlyph)
        case emoji(String)
    }

    private let content: Content
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 40

    public init(_ category: CategoryGlyph) {
        content = .category(category)
    }

    /// The permanent fallback for items with no glyph — must look intentional, never broken.
    public init(emoji: String) {
        content = .emoji(emoji)
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .fill(tint.color)
            switch content {
            case .category(let glyph):
                GlyphShape(glyph)
                    .stroke(Palette.ink.color, style: StrokeStyle(
                        lineWidth: max(1.5, 2 * glyphSide / 24), lineCap: .round, lineJoin: .round))
                    .frame(width: glyphSide, height: glyphSide)
            case .emoji(let emoji):
                Text(emoji).font(.system(size: size * 0.48))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var glyphSide: CGFloat { size * 0.6 }

    private var tint: Palette.RGB {
        switch content {
        case .category(let glyph): return glyph.tint
        case .emoji: return Palette.line
        }
    }
}
