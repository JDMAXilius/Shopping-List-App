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

    // Ids and names read straight out of Resources/catalog.db, not remembered.
    func testItemByIDCarriesNameCategoryAndUnit() throws {
        let db = try CatalogDatabase.bundled()
        XCTAssertEqual(
            db.item(1),
            CatalogItem(id: 1, canonicalName: "milk", categoryID: "dairy", emoji: "🥛",
                        defaultUnit: "L"))
        XCTAssertEqual(
            db.item(150),
            CatalogItem(id: 150, canonicalName: "spinach", categoryID: "produce", emoji: "🥬",
                        defaultUnit: "bag"))
        XCTAssertEqual(
            db.item(461),
            CatalogItem(id: 461, canonicalName: "dog treats", categoryID: "pet", emoji: "🦴",
                        defaultUnit: "bag"))
        XCTAssertEqual(db.item(45)?.canonicalName, "eggs")
        XCTAssertEqual(db.item(49)?.canonicalName, "butter")
        XCTAssertEqual(db.item(122)?.canonicalName, "bananas")
        XCTAssertEqual(db.item(369)?.canonicalName, "yorkshire puddings")
    }

    func testItemForUnknownIDIsNil() throws {
        let db = try CatalogDatabase.bundled()
        XCTAssertNil(db.item(0))
        XCTAssertNil(db.item(-1))
        XCTAssertNil(db.item(462))
        XCTAssertNil(db.item(999_999))
        XCTAssertNil(db.item(.max))
    }

    /// The id an item is looked up by is the id it comes back with — the half of the
    /// `ItemID.catalog(n).catalogID == n` round trip that lives on this side of the bridge.
    func testEveryItemIsNamedAndAnsweredUnderItsOwnID() throws {
        let db = try CatalogDatabase.bundled()
        for itemID in Int64(1)...461 {
            guard let item = db.item(itemID) else { return XCTFail("no item \(itemID)") }
            XCTAssertEqual(item.id, itemID)
            XCTAssertFalse(item.canonicalName.isEmpty, "item \(itemID) has no name")
        }
    }

    func testItemAgreesWithCategoryAndResolvedName() throws {
        let db = try CatalogDatabase.bundled()
        for query in ["milk", "bananas", "coffee", "toilet paper", "eggs"] {
            guard let hit = try resolve(db: db, query: query, limit: 1).first else {
                return XCTFail("no match for \(query)")
            }
            XCTAssertEqual(db.item(hit.id)?.canonicalName, hit.canonicalName)
            XCTAssertEqual(db.item(hit.id)?.categoryID, hit.categoryID)
            XCTAssertEqual(db.item(hit.id)?.defaultUnit, hit.defaultUnit)
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
