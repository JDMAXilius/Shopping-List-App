import XCTest
import Catalog

// Expected values pinned by running the JS reference (resolve.mjs) directly.
final class NormalizerTests: XCTestCase {

    func testNormalize() {
        XCTAssertEqual(Normalizer.normalize("Café au Lait!"), "cafe au lait")
        XCTAssertEqual(Normalizer.normalize("JALAPEÑOS"), "jalapenos")
        XCTAssertEqual(Normalizer.normalize("2% milk"), "2% milk")
        XCTAssertEqual(Normalizer.normalize("semi-skimmed"), "semi-skimmed")
        XCTAssertEqual(Normalizer.normalize("  a  b  "), "a b")
        XCTAssertEqual(Normalizer.normalize("ﬁsh ﬁllet"), "fish fillet")  // NFKD ligature
        XCTAssertEqual(Normalizer.normalize("crème fraîche"), "creme fraiche")
        XCTAssertEqual(Normalizer.normalize(""), "")
        // JS lowercases BEFORE NFKD, so №'s decomposed capital N is dropped.
        XCTAssertEqual(Normalizer.normalize("naïve №5"), "naive o5")
    }

    func testStripQualifiers() {
        func ns(_ s: String) -> String { Normalizer.strip(Normalizer.normalize(s)) }
        XCTAssertEqual(ns("a large ripe avocado"), "avocado")
        XCTAssertEqual(ns("free range free-range eggs"), "eggs")
        XCTAssertEqual(ns("fat free milk"), "milk")
        XCTAssertEqual(ns("large"), "")
        // replaceAll consumes the shared space — consecutive repeats survive.
        XCTAssertEqual(ns("organic organic milk"), "organic milk")
        XCTAssertEqual(ns("a a milk"), "a milk")
    }

    func testSingularize() {
        // irregulars
        XCTAssertEqual(Normalizer.singularize("mangoes"), "mango")
        XCTAssertEqual(Normalizer.singularize("leaves"), "leaf")
        XCTAssertEqual(Normalizer.singularize("tomatoes"), "tomato")
        XCTAssertEqual(Normalizer.singularize("berries"), "berry")
        // rules
        XCTAssertEqual(Normalizer.singularize("heroes"), "hero")
        XCTAssertEqual(Normalizer.singularize("dishes"), "dish")
        XCTAssertEqual(Normalizer.singularize("boxes"), "box")
        XCTAssertEqual(Normalizer.singularize("pies"), "py")  // JS quirk, ported
        XCTAssertEqual(Normalizer.singularize("buses"), "buse")  // JS quirk, ported
        // guards: short words, -ss, -us
        XCTAssertEqual(Normalizer.singularize("glass"), "glass")
        XCTAssertEqual(Normalizer.singularize("gas"), "gas")
        XCTAssertEqual(Normalizer.singularize("ies"), "ies")
        XCTAssertEqual(Normalizer.singularize("us"), "us")
        XCTAssertEqual(Normalizer.singularize("bus"), "bus")
        XCTAssertEqual(Normalizer.singularize("s"), "s")
        XCTAssertEqual(Normalizer.singularize("as"), "as")
    }

    func testSingularizeWords() {
        XCTAssertEqual(Normalizer.singularizeWords("spring onions"), "spring onion")
        XCTAssertEqual(Normalizer.singularizeWords("mangoes"), "mango")
    }
}
