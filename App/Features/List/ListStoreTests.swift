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

    func testReAddingWhatIsOnTheListMakesItMoreNotASecondRow() throws {
        let (store, _) = try makeStore()
        store.add(text: "3 milk")
        store.toggle(try XCTUnwrap(store.rows.first).item)
        XCTAssertTrue(try XCTUnwrap(store.rows.first).item.checked)

        store.add(text: "milk")
        XCTAssertEqual(store.rows.count, 1)
        XCTAssertEqual(try XCTUnwrap(store.rows.first).item.quantity, 4)
        // Needing more of it puts it back on the active list; it never resets to ×1.
        XCTAssertFalse(try XCTUnwrap(store.rows.first).item.checked)

        store.undo()
        XCTAssertEqual(try XCTUnwrap(store.rows.first).item.quantity, 3)
        XCTAssertTrue(try XCTUnwrap(store.rows.first).item.checked)
    }

    func testTwoAddsOfTheSameNameLeaveInOneRemove() throws {
        let (store, _) = try makeStore()
        store.add(text: "bread")
        store.add(text: "bread")
        XCTAssertEqual(store.rows.count, 1)

        store.remove(try XCTUnwrap(store.rows.first).item)
        XCTAssertTrue(store.rows.isEmpty)
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
        // Every row's price sits in exactly one aisle subtotal — promoted rows included,
        // or an aisle's `≈` would come and go with a check-off.
        XCTAssertEqual(store.aisles.flatMap(\.prices).count, store.prices.count)
    }

    func testAnAisleSubtotalKeepsTheGapItsPromotedRowLeaves() throws {
        let catalog = ListCatalog(database: nil)
        let priced = ListRow(item: ListItem(name: "milk"),
                             price: .estimated(Money(minorUnits: 300)), category: .dairy)
        let gap = ListRow(item: ListItem(name: "oat milk"), price: .none, category: .dairy)
        let aisle = try XCTUnwrap(ListDerivation.aisles([priced, gap], order: [], catalog: catalog,
                                                        promoted: [gap.id]).first)
        XCTAssertEqual(aisle.rows.map(\.id), [priced.id])   // the gap renders under NO PRICE YET
        XCTAssertEqual(aisle.prices.count, 2)
        XCTAssertTrue(PriceSummary(aisle.prices).isApproximate)

        var checked = gap.item
        checked.checked = true
        let after = try XCTUnwrap(ListDerivation.aisles(
            [priced, ListRow(item: checked, price: .none, category: .dairy)],
            order: [], catalog: catalog, promoted: []).first)
        // Checking an unpriced row off moves no money and must not move the `≈` either.
        XCTAssertEqual(PriceSummary(after.prices).total, PriceSummary(aisle.prices).total)
        XCTAssertTrue(PriceSummary(after.prices).isApproximate)
    }

    func testTheEditorSavesAWalkOrderCoveringEveryAisle() throws {
        let (store, _) = try makeStore()
        store.addShop(named: "Trader Joe's")
        store.add(text: "milk")
        store.add(text: "bananas")

        let editable = store.editableAisles
        XCTAssertEqual(Array(editable.map(\.category).prefix(2)), [.produce, .dairy])
        XCTAssertEqual(Set(editable.map(\.category)), Set(CategoryGlyph.allCases))

        store.reorderAisles(editable.map { CategoryID($0.category.rawValue) })
        // A partial order would wipe every aisle that happens to be empty today.
        XCTAssertEqual(store.aisleOrder.count, CategoryGlyph.allCases.count)
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

    func testTheArrivalMomentBelongsToACheckOffNeverADelete() throws {
        let (store, _) = try makeStore()
        store.add(text: "bananas")
        store.add(text: "milk")
        store.toggle(try XCTUnwrap(store.rows.first).item)
        XCTAssertTrue(store.consumeCheckOff())
        XCTAssertFalse(store.consumeCheckOff())          // one shot, then it is spent

        store.toggle(try XCTUnwrap(store.rows.first).item)
        XCTAssertFalse(store.consumeCheckOff())          // unchecking is not an arrival

        store.toggle(try XCTUnwrap(store.rows.first).item)
        store.remove(try XCTUnwrap(store.rows.last).item)
        // The list is complete because a row left, not because it was bought.
        XCTAssertTrue(store.isComplete)
        XCTAssertFalse(store.consumeCheckOff())
    }

    func testTheSwitcherCountsOnlyPricesTheRowStillCallsMeasured() throws {
        let (store, repository) = try makeStore()
        store.addShop(named: "Trader Joe's")
        store.add(text: "milk")
        let shopID = try XCTUnwrap(store.activeShopID)
        let itemID = try XCTUnwrap(store.rows.first?.item.itemID)
        try repository.append(
            .price(PriceObservation(itemID: itemID, shopID: shopID,
                                    date: Date().addingTimeInterval(-120 * 86_400),
                                    amount: Money(minorUnits: 479), source: .manual)),
            kitchenID: kitchenID)
        store.refresh()

        // Past 90 days the row renders `~estimate`, so the sub-line must not claim "priced".
        XCTAssertEqual(try XCTUnwrap(store.rows.first).price,
                       PriceDisplay.estimated(Money(minorUnits: 479)))
        XCTAssertEqual(store.measuredCount(at: shopID), 0)
    }

    func testOneQuantityStringForEverySurface() {
        XCTAssertNil(QuantityText.label(quantity: 1, unit: nil))
        XCTAssertEqual(QuantityText.label(quantity: 2, unit: nil), "×2")
        XCTAssertEqual(QuantityText.label(quantity: 1.5, unit: "lb"), "1.5 lb")
        XCTAssertEqual(QuantityText.label(quantity: 0.5, unit: "dozen"), "½ dozen")
        // The row's Int slot never rounds a lie into place: 1.5 lb is not "×2".
        XCTAssertEqual(QuantityText.rowCount(quantity: 1.5, unit: "lb"), 1)
        XCTAssertEqual(QuantityText.rowCount(quantity: 0.5, unit: nil), 1)
        XCTAssertEqual(QuantityText.rowCount(quantity: 3, unit: nil), 3)
    }

    func testDetailSheetCommitsOnlyWhatChanged() {
        let item = ListItem(name: "milk", unit: "l")
        XCTAssertTrue(ItemDetailSheet.edits(unit: "l", note: "", item: item).isEmpty)
        XCTAssertEqual(ItemDetailSheet.edits(unit: "l", note: "the cold one", item: item),
                       [.note("the cold one")])
        XCTAssertEqual(ItemDetailSheet.edits(unit: "", note: "", item: item), [.unit(nil)])
    }

    func testMoneyEntryRejectsWhatItCannotRead() {
        XCTAssertEqual(ItemDetailSheet.money(from: "$4.79"), Money(minorUnits: 479))
        XCTAssertEqual(ItemDetailSheet.money(from: "4,5"), Money(minorUnits: 450))
        XCTAssertEqual(ItemDetailSheet.money(from: "12"), Money(minorUnits: 1200))
        XCTAssertNil(ItemDetailSheet.money(from: ""))
        XCTAssertNil(ItemDetailSheet.money(from: "about five"))
    }

    func testCatalogIdentityRoundTrips() {
        let itemID = ItemID.catalog(4_321)
        XCTAssertEqual(itemID.catalogID, 4_321)
        // Pinned: ids already on disk keep meaning, so estimates and receipts stay one price book.
        XCTAssertEqual(itemID.rawValue.uuidString, "BA60CA7A-1060-0001-0000-0000000010E1")
        XCTAssertNil(ItemID().catalogID)   // a minted id is nobody's catalog row
    }
}
