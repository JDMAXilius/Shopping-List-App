import XCTest
import Catalog

// The 23 golden cases from data/catalog/resolve.mjs --test, ported verbatim.
// Each test asserts the golden semantic AND pins the complete result set
// (id, name, parent, category, emoji, unit, base, score, via) as produced
// by the reference engine. Any divergence is a port bug.
final class ResolverTests: XCTestCase {

    private func resolveAll(_ query: String) throws -> [CatalogMatch] {
        try resolve(db: CatalogDatabase.bundled(), query: query)
    }

    private func m(
        _ id: Int64, _ name: String, _ parent: String?, _ category: String,
        _ emoji: String, _ unit: String, _ base: Double, _ score: Double,
        _ via: CatalogMatch.Via
    ) -> CatalogMatch {
        CatalogMatch(
            id: id, canonicalName: name, parentConcept: parent, categoryID: category,
            emoji: emoji, defaultUnit: unit, baseAmount: base, score: score, via: via)
    }

    // qualifier stripped
    func test01_organicWholeMilk() throws {
        let r = try resolveAll("organic whole milk")
        XCTAssertEqual(r.first?.canonicalName, "whole milk")
        XCTAssertEqual(r, [m(2, "whole milk", "milk", "dairy", "🥛", "L", 3.5, 2, .exact)])
    }

    // exact, qualifier kept when canonical
    func test02_freeRangeEggs() throws {
        let r = try resolveAll("free-range eggs")
        XCTAssertEqual(r.first?.canonicalName, "free-range eggs")
        XCTAssertEqual(r, [
            m(46, "free-range eggs", "eggs", "dairy", "🥚", "dozen", 7, 0, .exact),
            m(45, "eggs", "eggs", "dairy", "🥚", "dozen", 6, 2, .exact),
            m(47, "organic eggs", "eggs", "dairy", "🥚", "dozen", 8, 4, .exact),
        ])
    }

    // multi-qualifier
    func test03_bonelessSkinlessChickenBreast() throws {
        let r = try resolveAll("boneless skinless chicken breast")
        XCTAssertEqual(r.first?.canonicalName, "chicken breast")
        XCTAssertEqual(r, [m(76, "chicken breast", "chicken", "meat", "🍗", "lb", 7, 1, .exact)])
    }

    // typo
    func test04_bananna() throws {
        let r = try resolveAll("bananna")
        XCTAssertEqual(r.first?.canonicalName, "bananas")
        XCTAssertEqual(r, [m(122, "bananas", "banana", "produce", "🍌", "each", 0.5, 7, .fuzzy)])
    }

    // typo + plural
    func test05_tomatos() throws {
        let r = try resolveAll("tomatos")
        XCTAssertEqual(r.first?.canonicalName, "vine tomatoes")
        XCTAssertEqual(r, [
            m(146, "vine tomatoes", "tomato", "produce", "🍅", "lb", 3.5, 3, .exact),
            m(246, "canned tomatoes", "canned-veg", "canned", "🥫", "can", 2, 3, .exact),
        ])
    }

    // irregular plural, exact
    func test06_mangoes() throws {
        let r = try resolveAll("mangoes")
        XCTAssertEqual(r.first?.canonicalName, "mangoes")
        XCTAssertEqual(r, [m(191, "mangoes", "fruit", "produce", "🥭", "each", 2, 0, .exact)])
    }

    // UK synonym
    func test07_aubergine() throws {
        let r = try resolveAll("aubergine")
        XCTAssertEqual(r.first?.canonicalName, "eggplant")
        XCTAssertEqual(r, [m(179, "eggplant", "vegetable", "produce", "🍆", "each", 2.5, 1, .exact)])
    }

    // UK synonym
    func test08_courgette() throws {
        let r = try resolveAll("courgette")
        XCTAssertEqual(r.first?.canonicalName, "zucchini")
        XCTAssertEqual(r, [m(178, "zucchini", "vegetable", "produce", "🥒", "each", 1.5, 1, .exact)])
    }

    // UK synonym
    func test09_coriander() throws {
        let r = try resolveAll("coriander")
        XCTAssertEqual(r.first?.canonicalName, "cilantro")
        XCTAssertEqual(r, [m(197, "cilantro", "herb", "produce", "🌿", "bunch", 1.5, 1, .exact)])
    }

    // UK synonym
    func test10_rocket() throws {
        let r = try resolveAll("rocket")
        XCTAssertEqual(r.first?.canonicalName, "arugula")
        XCTAssertEqual(r, [m(151, "arugula", "greens", "produce", "🥬", "bag", 4, 1, .exact)])
    }

    // UK synonym + plural
    func test11_springOnions() throws {
        let r = try resolveAll("spring onions")
        XCTAssertEqual(r.first?.canonicalName, "green onions")
        XCTAssertEqual(r, [m(137, "green onions", "onion", "produce", "🧅", "bunch", 1.5, 1, .exact)])
    }

    // ambiguous: show every mince, let the list disambiguate —
    // every listed variant must appear; which ranks first is the user's call
    func test12_mince() throws {
        let r = try resolveAll("mince")
        let names = r.map(\.canonicalName)
        for expected in ["ground beef", "ground pork", "ground lamb"] {
            XCTAssertTrue(names.contains(expected), "missing \(expected)")
        }
        XCTAssertEqual(r, [
            m(84, "ground beef", "beef", "meat", "🥩", "lb", 7, 4, .prefix),
            m(102, "ground lamb", "lamb", "meat", "🐑", "lb", 10, 4.5, .prefix),
            m(95, "ground pork", "pork", "meat", "🥩", "lb", 6, 4.5, .prefix),
            m(99, "ground turkey", "turkey", "meat", "🦃", "lb", 6, 4.5, .prefix),
            m(82, "ground chicken", "chicken", "meat", "🍗", "lb", 6, 4.5, .prefix),
        ])
    }

    // UK term
    func test13_beefMince() throws {
        let r = try resolveAll("beef mince")
        XCTAssertEqual(r.first?.canonicalName, "ground beef")
        XCTAssertEqual(r, [m(84, "ground beef", "beef", "meat", "🥩", "lb", 7, 1, .exact)])
    }

    // exact beats prefix; oat milk follows
    func test14_oat() throws {
        let r = try resolveAll("oat")
        XCTAssertEqual(r.first?.canonicalName, "rolled oats")
        XCTAssertEqual(r, [
            m(235, "rolled oats", "cereal", "breakfast", "🥣", "box", 5, 2, .exact),
            m(11, "oat milk", "milk", "plant-milk", "🥛", "carton", 5, 4, .prefix),
            m(343, "oatcakes", "biscuit", "snacks", "🍘", "pack", 2.5, 4, .prefix),
            m(242, "oat cereal", "cereal", "breakfast", "🥣", "box", 5, 4, .prefix),
            m(44, "oat yogurt", "yogurt", "dairy", "🥣", "tub", 6, 4, .prefix),
            m(236, "steel cut oats", "cereal", "breakfast", "🥣", "box", 6, 4.5, .prefix),
        ])
    }

    // UK synonym
    func test15_crisps() throws {
        let r = try resolveAll("crisps")
        XCTAssertEqual(r.first?.canonicalName, "potato chips")
        XCTAssertEqual(r, [m(338, "potato chips", "chips", "snacks", "🥔", "bag", 4.5, 1, .exact)])
    }

    // UK slang
    func test16_looRoll() throws {
        let r = try resolveAll("loo roll")
        XCTAssertEqual(r.first?.canonicalName, "toilet paper")
        XCTAssertEqual(r, [m(405, "toilet paper", "paper", "household", "🧻", "pack", 13, 1, .exact)])
    }

    // UK term
    func test17_clingFilm() throws {
        let r = try resolveAll("cling film")
        XCTAssertEqual(r.first?.canonicalName, "plastic wrap")
        XCTAssertEqual(r, [m(421, "plastic wrap", "kitchen-supply", "household", "🧻", "roll", 4.5, 1, .exact)])
    }

    // article + qualifiers + singular
    func test18_aLargeRipeAvocado() throws {
        let r = try resolveAll("a large ripe avocado")
        XCTAssertEqual(r.first?.canonicalName, "avocados")
        XCTAssertEqual(r, [m(165, "avocados", "avocado", "produce", "🥑", "each", 1.5, 4, .exact)])
    }

    // UK variant
    func test19_skimmedMilk() throws {
        let r = try resolveAll("skimmed milk")
        XCTAssertEqual(r.first?.canonicalName, "skim milk")
        XCTAssertEqual(r, [
            m(5, "skim milk", "milk", "dairy", "🥛", "L", 3.5, 1, .exact),
            m(3, "2% milk", "milk", "dairy", "🥛", "L", 3.5, 4.5, .prefix),
        ])
    }

    // UK term
    func test20_plainFlour() throws {
        let r = try resolveAll("plain flour")
        XCTAssertEqual(r.first?.canonicalName, "all-purpose flour")
        XCTAssertEqual(r, [m(301, "all-purpose flour", "flour", "baking", "🌾", "bag", 4, 1, .exact)])
    }

    // colloquial
    func test21_fizzyWater() throws {
        let r = try resolveAll("fizzy water")
        XCTAssertEqual(r.first?.canonicalName, "sparkling water")
        XCTAssertEqual(r, [m(382, "sparkling water", "water", "beverages", "🫗", "pack", 6, 1, .exact)])
    }

    // UK term
    func test22_nappies() throws {
        let r = try resolveAll("nappies")
        XCTAssertEqual(r.first?.canonicalName, "diapers")
        XCTAssertEqual(r, [m(452, "diapers", "baby-care", "baby", "🍼", "pack", 25, 1, .exact)])
    }

    // genuine miss, should return nothing confident
    func test23_unicornSteaks() throws {
        let r = try resolveAll("unicorn steaks")
        XCTAssertTrue(r.isEmpty || r[0].score >= 5, "unexpected confident hit: \(r)")
        XCTAssertEqual(r, [])  // the reference engine returns no rows at all
    }
}
