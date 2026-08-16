import XCTest
import Catalog

// Pinned to data/catalog/quantity.mjs — every expectation below was produced by
// running that reference. A divergence is a port bug, never a test to relax.
final class QuantityParserTests: XCTestCase {

    private func p(_ input: String) -> ParsedQuantity { QuantityParser.parse(input) }

    func testQuantityWithUnit() {
        XCTAssertEqual(p("2 lb chicken breast"), ParsedQuantity(quantity: 2, unit: "lb", rest: "chicken breast"))
        XCTAssertEqual(p("1.5 kg flour"), ParsedQuantity(quantity: 1.5, unit: "kg", rest: "flour"))
        XCTAssertEqual(p("12 pack sparkling water"), ParsedQuantity(quantity: 12, unit: "pack", rest: "sparkling water"))
        XCTAssertEqual(p("2 dozen eggs"), ParsedQuantity(quantity: 2, unit: "dozen", rest: "eggs"))
    }

    func testPluralUnitsCanonicalized() {
        XCTAssertEqual(p("2 cans tomatoes"), ParsedQuantity(quantity: 2, unit: "can", rest: "tomatoes"))
        XCTAssertEqual(p("3 bottles wine"), ParsedQuantity(quantity: 3, unit: "bottle", rest: "wine"))
        XCTAssertEqual(p("2 boxes cereal"), ParsedQuantity(quantity: 2, unit: "box", rest: "cereal"))
        XCTAssertEqual(p("2 pints of milk"), ParsedQuantity(quantity: 2, unit: "pint", rest: "milk"))
    }

    func testBareLeadingNumber() {
        XCTAssertEqual(p("3 apples"), ParsedQuantity(quantity: 3, unit: nil, rest: "apples"))
        XCTAssertEqual(p("6 eggs"), ParsedQuantity(quantity: 6, unit: nil, rest: "eggs"))
    }

    func testAttachedUnit() {
        XCTAssertEqual(p("2lb chicken"), ParsedQuantity(quantity: 2, unit: "lb", rest: "chicken"))
        XCTAssertEqual(p("500g pasta"), ParsedQuantity(quantity: 500, unit: "g", rest: "pasta"))
        XCTAssertEqual(p("1kg mince"), ParsedQuantity(quantity: 1, unit: "kg", rest: "mince"))
    }

    // The gap the 338-query demand probe exposed: containers with no number.
    func testContainerWithoutNumber() {
        XCTAssertEqual(p("carton of milk"), ParsedQuantity(quantity: 1, unit: "carton", rest: "milk"))
        XCTAssertEqual(p("bag of potatoes"), ParsedQuantity(quantity: 1, unit: "bag", rest: "potatoes"))
        XCTAssertEqual(p("punnet of strawberries"), ParsedQuantity(quantity: 1, unit: "punnet", rest: "strawberries"))
        XCTAssertEqual(p("loaf of bread"), ParsedQuantity(quantity: 1, unit: "loaf", rest: "bread"))
        XCTAssertEqual(p("dozen eggs"), ParsedQuantity(quantity: 1, unit: "dozen", rest: "eggs"))
    }

    func testWordNumbersAndHalves() {
        XCTAssertEqual(p("a loaf of bread"), ParsedQuantity(quantity: 1, unit: "loaf", rest: "bread"))
        XCTAssertEqual(p("a dozen eggs"), ParsedQuantity(quantity: 1, unit: "dozen", rest: "eggs"))
        XCTAssertEqual(p("half dozen eggs"), ParsedQuantity(quantity: 0.5, unit: "dozen", rest: "eggs"))
        XCTAssertEqual(p("three apples"), ParsedQuantity(quantity: 3, unit: nil, rest: "apples"))
        XCTAssertEqual(p("couple of bananas"), ParsedQuantity(quantity: 2, unit: nil, rest: "bananas"))
    }

    // A size word is skipped only when a container follows it.
    func testSizeBeforeContainer() {
        XCTAssertEqual(p("large tub of yoghurt"), ParsedQuantity(quantity: 1, unit: "tub", rest: "yoghurt"))
        XCTAssertEqual(p("large eggs"), ParsedQuantity(quantity: nil, unit: nil, rest: "large eggs"))
    }

    // The guard that keeps the parser from eating the item itself.
    func testNeverConsumesWholeInput() {
        XCTAssertEqual(p("loaf"), ParsedQuantity(quantity: nil, unit: nil, rest: "loaf"))
        XCTAssertEqual(p("dozen"), ParsedQuantity(quantity: nil, unit: nil, rest: "dozen"))
        XCTAssertEqual(p("bag"), ParsedQuantity(quantity: nil, unit: nil, rest: "bag"))
        XCTAssertEqual(p("2"), ParsedQuantity(quantity: nil, unit: nil, rest: "2"))
    }

    // Container words inside an item name are not units.
    func testItemsThatLookLikeContainers() {
        XCTAssertEqual(p("bin bags"), ParsedQuantity(quantity: nil, unit: nil, rest: "bin bags"))
        XCTAssertEqual(p("tea bags"), ParsedQuantity(quantity: nil, unit: nil, rest: "tea bags"))
        XCTAssertEqual(p("canned tomatoes"), ParsedQuantity(quantity: nil, unit: nil, rest: "canned tomatoes"))
        XCTAssertEqual(p("chicken breast"), ParsedQuantity(quantity: nil, unit: nil, rest: "chicken breast"))
    }

    func testNoQuantity() {
        XCTAssertEqual(p("milk"), ParsedQuantity(quantity: nil, unit: nil, rest: "milk"))
        XCTAssertEqual(p(""), ParsedQuantity(quantity: nil, unit: nil, rest: ""))
        XCTAssertEqual(p("   "), ParsedQuantity(quantity: nil, unit: nil, rest: ""))
    }

    func testRejectsNonQuantityNumbers() {
        // "nan"/"inf"/exponents must not parse as quantities.
        XCTAssertEqual(p("nan bread"), ParsedQuantity(quantity: nil, unit: nil, rest: "nan bread"))
        XCTAssertEqual(p("1e3 things"), ParsedQuantity(quantity: nil, unit: nil, rest: "1e3 things"))
        XCTAssertEqual(p("2% milk"), ParsedQuantity(quantity: nil, unit: nil, rest: "2% milk"))
    }
}
