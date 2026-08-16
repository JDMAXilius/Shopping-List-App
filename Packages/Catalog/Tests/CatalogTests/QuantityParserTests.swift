import XCTest
import Catalog

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
    }

    func testBareLeadingNumber() {
        XCTAssertEqual(p("3 apples"), ParsedQuantity(quantity: 3, unit: nil, rest: "apples"))
        XCTAssertEqual(p("2"), ParsedQuantity(quantity: 2, unit: nil, rest: ""))
    }

    func testAttachedUnit() {
        XCTAssertEqual(p("2lb chicken"), ParsedQuantity(quantity: 2, unit: "lb", rest: "chicken"))
        XCTAssertEqual(p("500g pasta"), ParsedQuantity(quantity: 500, unit: "g", rest: "pasta"))
    }

    func testNoQuantity() {
        XCTAssertEqual(p("milk"), ParsedQuantity(quantity: nil, unit: nil, rest: "milk"))
        XCTAssertEqual(p("a dozen eggs"), ParsedQuantity(quantity: nil, unit: nil, rest: "a dozen eggs"))
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
