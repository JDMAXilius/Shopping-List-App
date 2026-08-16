import Catalog
import Core
import Data
import DesignKit
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class ListStoreTests: XCTestCase {
    private let kitchenID = KitchenID()

    private func makeStore() throws -> (ListStore, Repository) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("list-store-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        let repository = try Repository(database: database)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(UUID().uuidString)"))
        let store = try ListStore(repository: repository, kitchenID: kitchenID,
                                  catalog: ListCatalog(database: try CatalogDatabase.bundled()),
                                  defaults: defaults)
        return (store, repository)
    }

    // Somebody else's device added it: it reaches us as an op, never through our history.
    private func householdAdd(_ name: String, _ repository: Repository, _ store: ListStore) throws {
        try repository.append(.add(ListItem(name: name)), kitchenID: kitchenID)
        store.refresh()
    }

    // MARK: - The add path

    func testAddParsesQuantityAndResolvesTheItem() throws {
        let (store, _) = try makeStore()
        store.add(text: "2 lb chicken breast")

        let row = try XCTUnwrap(store.rows.first)
        XCTAssertEqual(row.item.name, "chicken breast")
        XCTAssertEqual(row.item.quantity, 2)
        XCTAssertEqual(row.item.unit, "lb")
        XCTAssertNotNil(row.item.itemID)
        XCTAssertEqual(row.category, .meat)
        // Every resolved item lands with a seeded estimate — the total works on trip one.
        XCTAssertNotEqual(row.price, .none)
    }

    func testUnknownTextStillMakesAPerfectlyGoodRow() throws {
        let (store, _) = try makeStore()
        store.add(text: "unicorn steaks")

        let row = try XCTUnwrap(store.rows.first)
        XCTAssertNil(row.item.itemID)
        XCTAssertEqual(row.price, .none)
        XCTAssertEqual(row.category, .other)
        XCTAssertEqual(store.unpriced.map(\.id), [row.id])
    }

    func testBareContainerWordStaysTheItem() throws {
        let (store, _) = try makeStore()
        store.add(text: "dozen")

        let row = try XCTUnwrap(store.rows.first)
        XCTAssertEqual(row.item.name, "dozen")
        XCTAssertEqual(row.item.quantity, 1)
    }

    // MARK: - Autocomplete

    func testSuggestionsRankPersonalThenHouseholdThenCatalog() throws {
        let (store, repository) = try makeStore()
        store.add(text: "oat milk")
        store.remove(try XCTUnwrap(store.rows.first).item)   // leaves the list, stays in our history
        try householdAdd("oatmeal", repository, store)
        try householdAdd("oat milk", repository, store)      // the same thing, from someone else

        let names = store.suggestions(for: "oat").map(\.name)
        XCTAssertEqual(names.first, "oat milk")
        XCTAssertEqual(Array(names.dropFirst().prefix(1)), ["oatmeal"])
        XCTAssertEqual(names.filter { $0 == "oat milk" }.count, 1)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertGreaterThan(names.count, 2)                 // the catalog tier follows
    }

    func testSuggestedChipsSkipWhatIsAlreadyOnTheList() throws {
        let (store, _) = try makeStore()
        XCTAssertEqual(store.suggestedChips.count, 3)
        XCTAssertEqual(store.suggestedChips.first?.name, "Butter")

        store.add(text: "Butter")
        XCTAssertFalse(store.suggestedChips.contains { $0.name == "Butter" })
    }

    // MARK: - Ops and undo

    func testToggleAndUndoProduceInverseOps() throws {
        let (store, repository) = try makeStore()
        store.add(text: "bananas")
        store.toggle(try XCTUnwrap(store.rows.first).item)
        XCTAssertTrue(try XCTUnwrap(store.rows.first).item.checked)

        store.undo()
        XCTAssertFalse(try XCTUnwrap(store.rows.first).item.checked)
        XCTAssertEqual(try repository.unpushedOps().map(\.type), ["add", "check", "uncheck"])
    }

    func testUndoOfARemoveBringsTheRowBack() throws {
        let (store, repository) = try makeStore()
        store.add(text: "bread")
        store.remove(try XCTUnwrap(store.rows.first).item)
        XCTAssertTrue(store.rows.isEmpty)

        store.undo()
        XCTAssertEqual(store.rows.map(\.item.name), ["bread"])
        XCTAssertEqual(try repository.unpushedOps().map(\.type), ["add", "delete", "add"])
    }

    func testSetPriceRecordsAMeasuredObservation() throws {
        let (store, _) = try makeStore()
        store.addShop(named: "Trader Joe's")
        store.add(text: "milk")
        store.setPrice(try XCTUnwrap(store.rows.first).item, Money(minorUnits: 479))

        XCTAssertEqual(try XCTUnwrap(store.rows.first).price,
                       PriceDisplay(amount: Money(minorUnits: 479), confidence: .trusted))
    }

    func testSetPriceOnAnUnresolvedRowGivesItAnIdentity() throws {
        let (store, _) = try makeStore()
        store.addShop(named: "Trader Joe's")
        store.add(text: "unicorn steaks")
        store.setPrice(try XCTUnwrap(store.rows.first).item, Money(minorUnits: 999))

        let row = try XCTUnwrap(store.rows.first)
        XCTAssertNotNil(row.item.itemID)
        XCTAssertEqual(row.price, PriceDisplay(amount: Money(minorUnits: 999), confidence: .trusted))
        XCTAssertTrue(store.unpriced.isEmpty)
    }

    // MARK: - Derived view state

    func testTotalBarPricesMatchTheVisibleRows() throws {
        let (store, _) = try makeStore()
        store.add(text: "bananas")
        store.add(text: "milk")
        store.add(text: "unicorn steaks")

        XCTAssertEqual(store.prices, store.rows.map(\.price))
        let summary = PriceSummary(store.prices)
        XCTAssertEqual(summary.estimatedCount, 2)
        XCTAssertEqual(summary.unpricedCount, 1)
        XCTAssertTrue(summary.isApproximate)

        // Promoted + aisle + completed is exactly the list, each row shown once.
        let shown = store.unpriced.map(\.id) + store.aisles.flatMap { $0.rows.map(\.id) }
            + store.completed.map(\.id)
        XCTAssertEqual(Set(shown), Set(store.rows.map(\.id)))
        XCTAssertEqual(shown.count, store.rows.count)
        XCTAssertEqual(store.aisles.flatMap(\.prices).count + store.unpriced.count,
                       store.prices.count)
    }

    func testCheckedRowsSinkButKeepTheirAisleSubtotal() throws {
        let (store, _) = try makeStore()
        store.add(text: "bananas")
        store.toggle(try XCTUnwrap(store.rows.first).item)

        let aisle = try XCTUnwrap(store.aisles.first)
        XCTAssertTrue(aisle.rows.isEmpty)
        XCTAssertEqual(aisle.prices.count, 1)
        XCTAssertEqual(aisle.doneCount, 1)
        XCTAssertTrue(aisle.isCollapsed)
        XCTAssertEqual(store.completed.count, 1)
        XCTAssertTrue(store.isComplete)
    }

    func testAislesFollowTheShopsWalkOrder() throws {
        let (store, _) = try makeStore()
        store.addShop(named: "Trader Joe's")
        store.add(text: "milk")
        store.add(text: "bananas")
        XCTAssertEqual(store.aisles.map(\.category), [.produce, .dairy])

        store.reorderAisles([CategoryID("dairy"), CategoryID("produce")])
        XCTAssertEqual(store.aisles.map(\.category), [.dairy, .produce])
    }

    func testPricesBelongToTheShopTheyWerePaidAt() throws {
        let (store, _) = try makeStore()
        store.addShop(named: "Trader Joe's")
        store.add(text: "milk")
        store.setPrice(try XCTUnwrap(store.rows.first).item, Money(minorUnits: 479))
        store.addShop(named: "Walmart")

        // Another shop's receipt is not this trip's price: back to the estimate, never a lie.
        XCTAssertNotEqual(try XCTUnwrap(store.rows.first).price,
                          PriceDisplay(amount: Money(minorUnits: 479), confidence: .trusted))
    }

    func testMoneyEntryRejectsWhatItCannotRead() {
        XCTAssertEqual(ItemDetailSheet.money(from: "$4.79"), Money(minorUnits: 479))
        XCTAssertEqual(ItemDetailSheet.money(from: "4,5"), Money(minorUnits: 450))
        XCTAssertEqual(ItemDetailSheet.money(from: "12"), Money(minorUnits: 1200))
        XCTAssertNil(ItemDetailSheet.money(from: ""))
        XCTAssertNil(ItemDetailSheet.money(from: "about five"))
    }

    func testCatalogIdentityRoundTrips() {
        let itemID = ListCatalog.itemID(4_321)
        XCTAssertEqual(ListCatalog.catalogID(itemID), 4_321)
        XCTAssertNil(ListCatalog.catalogID(ItemID()))   // a minted id is nobody's catalog row
    }
}
