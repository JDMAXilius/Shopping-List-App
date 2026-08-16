import XCTest
import SwiftUI
import DesignKit

final class GlyphTests: XCTestCase {

    // The 22 catalog category ids, verbatim — CategoryGlyph must cover exactly these.
    private let catalogIDs: Set<String> = [
        "produce", "bakery", "deli", "meat", "seafood", "dairy", "plant-milk",
        "frozen", "breakfast", "pantry-dry", "canned", "condiments", "baking",
        "spices", "snacks", "beverages", "coffee-tea", "household",
        "personal-care", "baby", "pet", "other",
    ]

    func testAllCatalogCategoriesCovered() {
        XCTAssertEqual(Set(CategoryGlyph.allCases.map(\.rawValue)), catalogIDs)
        XCTAssertEqual(CategoryGlyph.allCases.count, 22)
    }

    // Every glyph draws something, inside its 24×24 design space (small allowance
    // for the 2pt stroke that the consuming view applies).
    func testEveryGlyphProducesAPathInBounds() {
        let rect = CGRect(x: 0, y: 0, width: 24, height: 24)
        for glyph in CategoryGlyph.allCases {
            let path = GlyphShape(glyph).path(in: rect)
            XCTAssertFalse(path.isEmpty, "\(glyph.rawValue) draws nothing")
            let bounds = path.boundingRect
            XCTAssertTrue(rect.insetBy(dx: -1, dy: -1).contains(bounds),
                          "\(glyph.rawValue) escapes the design space: \(bounds)")
        }
    }

    // Glyphs scale with their rect — the tile drives size, Dynamic Type drives the tile.
    func testGlyphScalesToRect() {
        let big = GlyphShape(.produce).path(in: CGRect(x: 0, y: 0, width: 48, height: 48))
        XCTAssertFalse(big.isEmpty)
        XCTAssertGreaterThan(big.boundingRect.width, 24)
    }

    // Every category resolves to one of the six aisle tints, never an off-token colour.
    func testEveryGlyphTintIsACanonicalAisleTint() {
        for glyph in CategoryGlyph.allCases {
            XCTAssertTrue(Palette.aisleTints.contains(glyph.tint),
                          "\(glyph.rawValue) has a non-canonical tint")
        }
    }
}
