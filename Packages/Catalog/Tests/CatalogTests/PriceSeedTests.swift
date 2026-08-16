import XCTest
import Catalog

final class PriceSeedTests: XCTestCase {

    // Estimates round hard to the nearest $0.50, ties up — Core/Money's rule.
    func testRounding() {
        XCTAssertEqual(PriceEstimate.rounded(4.37), 4.5)  // never 4.37
        XCTAssertEqual(PriceEstimate.rounded(4.24), 4.0)
        XCTAssertEqual(PriceEstimate.rounded(4.26), 4.5)
        XCTAssertEqual(PriceEstimate.rounded(4.25), 4.5)  // tie rounds up, as Core does
        XCTAssertEqual(PriceEstimate.rounded(4.75), 5.0)
        XCTAssertEqual(PriceEstimate.rounded(9.8), 10.0)
        XCTAssertEqual(PriceEstimate.rounded(10.0), 10.0)
        XCTAssertEqual(PriceEstimate.rounded(12.2), 12.0)
        XCTAssertEqual(PriceEstimate.rounded(12.4), 12.5)
        XCTAssertEqual(PriceEstimate.rounded(0.4), 0.5)
    }

    func testPriceSeedLookup() throws {
        let db = try CatalogDatabase.bundled()
        XCTAssertEqual(
            try db.priceSeed(itemID: 2),  // whole milk
            PriceSeed(itemID: 2, baseAmount: 3.5, currency: "USD", baseUnit: "L", compiledYear: 2026))
        XCTAssertEqual(
            try db.priceSeed(itemID: 369),  // toilet paper
            PriceSeed(itemID: 369, baseAmount: 13, currency: "USD", baseUnit: "pack", compiledYear: 2026))
        XCTAssertNil(try db.priceSeed(itemID: 999_999))
    }

    func testRegionLookup() throws {
        let db = try CatalogDatabase.bundled()
        XCTAssertEqual(
            try db.priceRegion("us-west"),
            PriceRegion(key: "us-west", label: "US West", multiplier: 1.15))
        XCTAssertEqual(
            try db.priceRegion("uk"),
            PriceRegion(key: "uk", label: "United Kingdom", multiplier: 0.92))
        XCTAssertNil(try db.priceRegion("mars"))
    }

    func testEstimate() throws {
        let db = try CatalogDatabase.bundled()
        // whole milk 3.5 × 1.15 = 4.025 → 4.0
        XCTAssertEqual(try PriceEstimate.estimate(db: db, itemID: 2, regionKey: "us-west"), 4.0)
        // whole milk 3.5 × 0.92 = 3.22 → 3.0
        XCTAssertEqual(try PriceEstimate.estimate(db: db, itemID: 2, regionKey: "uk"), 3.0)
        // toilet paper 13 × 1.18 = 15.34 → 15.5
        XCTAssertEqual(try PriceEstimate.estimate(db: db, itemID: 369, regionKey: "ca"), 15.5)
        XCTAssertNil(try PriceEstimate.estimate(db: db, itemID: 999_999, regionKey: "us-west"))
        XCTAssertNil(try PriceEstimate.estimate(db: db, itemID: 2, regionKey: "mars"))
    }
}
