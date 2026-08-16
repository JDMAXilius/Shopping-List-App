import Catalog
import XCTest

final class CatalogDatabaseTests: XCTestCase {
    func testCategoriesAreTheTwentyTwoInAisleOrder() throws {
        let categories = try CatalogDatabase.bundled().categories()
        XCTAssertEqual(categories.count, 22)
        XCTAssertEqual(
            categories.map(\.id),
            [
                "produce", "bakery", "deli", "meat", "seafood", "dairy", "plant-milk", "frozen",
                "breakfast", "pantry-dry", "canned", "condiments", "baking", "spices", "snacks",
                "beverages", "coffee-tea", "household", "personal-care", "baby", "pet", "other",
            ])
        XCTAssertEqual(
            categories.first, CatalogCategory(id: "produce", name: "Produce", emoji: "🥬", defaultOrder: 10))
        XCTAssertEqual(
            categories.last, CatalogCategory(id: "other", name: "Other", emoji: "🛒", defaultOrder: 999))
        XCTAssertEqual(categories.map(\.defaultOrder), categories.map(\.defaultOrder).sorted())
        XCTAssertTrue(categories.allSatisfy { !$0.name.isEmpty && $0.emoji?.isEmpty == false })
        XCTAssertEqual(Set(categories.map(\.id)).count, 22)
    }

    func testCategoriesAreStableAcrossCalls() throws {
        let db = try CatalogDatabase.bundled()
        XCTAssertEqual(db.categories(), db.categories())
        XCTAssertEqual(db.categories(), try CatalogDatabase.bundled().categories())
    }

    func testCategoryForItem() throws {
        let db = try CatalogDatabase.bundled()
        XCTAssertEqual(db.category(forItem: 1), "dairy")  // milk
        XCTAssertEqual(db.category(forItem: 2), "dairy")  // whole milk
        XCTAssertEqual(db.category(forItem: 369), "frozen")  // yorkshire puddings
    }

    func testCategoryForUnknownItemIsNil() throws {
        let db = try CatalogDatabase.bundled()
        XCTAssertNil(db.category(forItem: 0))
        XCTAssertNil(db.category(forItem: -1))
        XCTAssertNil(db.category(forItem: 999_999))
        XCTAssertNil(db.category(forItem: .max))
    }

    func testEveryItemsCategoryIsAKnownCategory() throws {
        let db = try CatalogDatabase.bundled()
        let known = Set(db.categories().map(\.id))
        for itemID in Int64(1)...461 {
            let category = db.category(forItem: itemID)
            XCTAssertNotNil(category, "item \(itemID) has no category")
            XCTAssertTrue(known.contains(category ?? ""), "item \(itemID): \(category ?? "nil")")
        }
    }

    func testResolvedMatchAgreesWithCategoryLookup() throws {
        let db = try CatalogDatabase.bundled()
        for query in ["milk", "bananas", "coffee", "toilet paper", "eggs"] {
            guard let hit = try resolve(db: db, query: query, limit: 1).first else {
                return XCTFail("no match for \(query)")
            }
            XCTAssertEqual(db.category(forItem: hit.id), hit.categoryID)
        }
    }
}
