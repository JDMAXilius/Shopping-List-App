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

    private func makeStore(currencyCode: String? = nil) throws -> (ListStore, Repository) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("list-store-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        let repository = try Repository(database: database)
        if let currencyCode {
            try repository.saveKitchen(Kitchen(id: kitchenID, name: "Home",
                                               currencyCode: currencyCode))
        }
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

    /// The merge is the one add that changes a row you may not be looking at — and it can take
    /// a check-off away. It gets the same inline row a remove gets, saying what it restores.
    func testAReAddThatMergesIsUndoableThroughTheSameInlineRow() throws {
        let (store, _) = try makeStore()
        store.add(text: "unicorn steaks")            // no catalog match: no unit of its own
        store.toggle(try XCTUnwrap(store.rows.first).item)

        store.add(text: "unicorn steaks")
        XCTAssertFalse(try XCTUnwrap(store.rows.first).item.checked)
        XCTAssertEqual(store.pendingUndo?.phrase, "unicorn steaks back to ×1, checked")

        store.undo()
        let after = try XCTUnwrap(store.rows.first).item
        XCTAssertEqual(after.quantity, 1)
        XCTAssertTrue(after.checked)                 // the check-off it silently spent
        XCTAssertNil(store.pendingUndo)              // the affordance goes when it fires
    }

    func testAMergeIntoAnUncheckedRowOffersTheQuantityItLeaves() throws {
        let (store, _) = try makeStore()
        store.add(text: "2 unicorn steaks")

        store.add(text: "unicorn steaks")
        XCTAssertEqual(try XCTUnwrap(store.rows.first).item.quantity, 3)
        // Nothing was checked, so the phrase claims no check back — it says only what it does.
        XCTAssertEqual(store.pendingUndo?.phrase, "unicorn steaks back to ×2")
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

    func testACheckOffIsItsOwnWayBackAndTakesNoUndoSlot() throws {
        let (store, repository) = try makeStore()
        store.add(text: "bananas")
        store.toggle(try XCTUnwrap(store.rows.first).item)
        XCTAssertTrue(try XCTUnwrap(store.rows.first).item.checked)
        XCTAssertNil(store.pendingUndo)

        store.undo()
        XCTAssertTrue(try XCTUnwrap(store.rows.first).item.checked)   // no row offered one
        store.toggle(try XCTUnwrap(store.rows.first).item)            // the tick is the undo
        XCTAssertFalse(try XCTUnwrap(store.rows.first).item.checked)
        XCTAssertEqual(try repository.unpushedOps().map(\.type), ["add", "check", "uncheck"])
    }

    func testUndoOfARemoveBringsTheRowBack() throws {
        let (store, repository) = try makeStore()
        store.add(text: "2 lb bread")
        store.edit(try XCTUnwrap(store.rows.first).item, [.note("the seeded one")])
        let before = try XCTUnwrap(store.rows.first).item
        store.remove(before)
        XCTAssertTrue(store.rows.isEmpty)
        // The inline affordance says what the tap will do, not what happened.
        XCTAssertEqual(store.pendingUndo?.phrase, "bread back on the list")

        store.undo()
        let after = try XCTUnwrap(store.rows.first).item
        XCTAssertEqual(after.name, "bread")
        XCTAssertEqual(after.quantity, 2)
        XCTAssertEqual(after.unit, "lb")
        XCTAssertEqual(after.note, "the seeded one")
        XCTAssertEqual(after.itemID, before.itemID)
        // Resurrection is by name: reusing the deleted id would land under the tombstone.
        XCTAssertNotEqual(after.listItemID, before.listItemID)
        XCTAssertFalse(after.checked)                    // it is back on the list to buy
        XCTAssertNil(store.pendingUndo)                  // the affordance goes when it fires
        XCTAssertEqual(try repository.unpushedOps().map(\.type),
                       ["add", "edit", "delete", "add"])
    }

    /// The slot holds exactly what a row can offer, and only until the next write: an inverse
    /// no affordance renders would be an undo the user cannot invoke.
    func testTheUndoSlotHoldsOnlyWhatTheInlineRowOffers() throws {
        let (store, _) = try makeStore()
        store.add(text: "bread")
        XCTAssertNil(store.pendingUndo)                  // a brand-new row is its own way back
        store.toggle(try XCTUnwrap(store.rows.first).item)
        XCTAssertNil(store.pendingUndo)                  // the tick reverses itself

        store.remove(try XCTUnwrap(store.rows.first).item)
        XCTAssertEqual(store.pendingUndo?.phrase, "bread back on the list")
        store.add(text: "milk")
        XCTAssertNil(store.pendingUndo)                  // the next action takes the offer away
        store.undo()
        XCTAssertEqual(store.rows.map(\.item.name), ["milk"])
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
        // One of something WITH a unit is worth saying, and the row can say it now (W5-P9):
        // the Int slot it replaced dropped "1 lb" and rounded "1.5 lb" into a lie.
        XCTAssertEqual(QuantityText.label(quantity: 1, unit: "lb"), "1 lb")
    }

    func testDetailSheetCommitsOnlyWhatChanged() {
        let item = ListItem(name: "milk", unit: "l")
        XCTAssertTrue(ItemDetailSheet.edits(unit: "l", note: "", item: item).isEmpty)
        XCTAssertEqual(ItemDetailSheet.edits(unit: "l", note: "the cold one", item: item),
                       [.note("the cold one")])
        XCTAssertEqual(ItemDetailSheet.edits(unit: "", note: "", item: item), [.unit(nil)])
    }

    func testMoneyEntryRejectsWhatItCannotRead() {
        XCTAssertEqual(MoneyText.money(from: "$4.79", currencyCode: "USD"), Money(minorUnits: 479))
        XCTAssertEqual(MoneyText.money(from: "4,5", currencyCode: "USD"), Money(minorUnits: 450))
        XCTAssertEqual(MoneyText.money(from: "12", currencyCode: "USD"), Money(minorUnits: 1_200))
        XCTAssertNil(MoneyText.money(from: "", currencyCode: "USD"))
        XCTAssertNil(MoneyText.money(from: "about five", currencyCode: "USD"))
    }

    /// W7 P1-B: there is exactly one typed-money parser, and the detail sheet uses it. A second
    /// one that hardcoded `Money(whole * 100)` made every price typed in a EUR, GBP, JPY or KWD
    /// kitchen a `currencyMismatch` the store then swallowed.
    func testTheDetailSheetHasNoParserOfItsOwn() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let source = try String(contentsOf: directory.appendingPathComponent("ItemDetailSheet.swift"),
                                encoding: .utf8)
        XCTAssertFalse(source.contains("* 100"), "the exponent comes from Money, never a literal")
        XCTAssertFalse(source.contains("static func money"),
                       "one parser for the whole app: MoneyText")
        XCTAssertEqual(MoneyText.money(from: "4,79", currencyCode: "EUR"),
                       Money(minorUnits: 479, currencyCode: "EUR"))
        XCTAssertEqual(MoneyText.money(from: "500", currencyCode: "JPY"),
                       Money(minorUnits: 500, currencyCode: "JPY"), "¥500 is never ¥5.00")
        XCTAssertEqual(MoneyText.money(from: "1,500", currencyCode: "KWD"),
                       Money(minorUnits: 1_500, currencyCode: "KWD"), "the dinar divides by 1000")
    }

    /// The bug as executed: a EUR kitchen, "4,79" typed, save tapped — and no error, no toast,
    /// no row change, forever. What is typed is now in the kitchen's own money and it lands.
    func testATypedPriceInANonUSDKitchenIsActuallySaved() throws {
        let (store, _) = try makeStore(currencyCode: "EUR")
        store.addShop(named: "Mercadona")
        store.add(text: "milk")
        let amount = try XCTUnwrap(MoneyText.money(from: "4,79", currencyCode: store.currencyCode))

        XCTAssertEqual(store.currencyCode, "EUR")
        XCTAssertTrue(store.setPrice(try XCTUnwrap(store.rows.first).item, amount),
                      "the write reports what it did, and it did it")
        XCTAssertEqual(try XCTUnwrap(store.rows.first).price,
                       PriceDisplay(amount: Money(minorUnits: 479, currencyCode: "EUR"),
                                    confidence: .trusted))
    }

    /// A write that fails is never silent, and never half-lands: the row keeps no identity and
    /// no taught name bought by a price the database refused.
    func testARefusedPriceChangesNothingAtAllAndSaysSo() throws {
        let (store, repository) = try makeStore(currencyCode: "EUR")
        store.addShop(named: "Mercadona")
        store.add(text: "unicorn steaks")
        let row = try XCTUnwrap(store.rows.first)

        // USD into a EUR kitchen: exactly what the old sheet built out of "4,79".
        XCTAssertFalse(store.setPrice(row.item, Money(minorUnits: 479, currencyCode: "USD")))

        let after = try XCTUnwrap(store.rows.first)
        XCTAssertNil(after.item.itemID, "no identity for a price that was never written")
        XCTAssertTrue(try repository.itemNames().isEmpty, "and no name taught for it either")
        XCTAssertTrue(try repository.priceObservations().isEmpty)
        XCTAssertEqual(after.price, .none)
    }

    /// W7 P3: the list and the price book call an item the same thing, and it is the user's word.
    func testTheNameTheUserGaveItWinsWhereverOneExists() throws {
        let catalog = ListCatalog(database: try CatalogDatabase.bundled())
        let match = try XCTUnwrap(catalog.resolve("oat milk"))
        let taught = [match.itemID: "Oatly barista"]

        XCTAssertEqual(catalog.displayName(for: match.itemID, kitchenNames: taught,
                                           listName: "tj oat milk", fallback: "TJ OAT BEV"),
                       "tj oat milk", "the row's own words beat everything")
        XCTAssertEqual(catalog.displayName(for: match.itemID, kitchenNames: taught,
                                           listName: nil, fallback: "TJ OAT BEV"),
                       "Oatly barista", "then what this kitchen was taught")
        // The case the order was catalog-first for: a receipt line with no list row must still
        // read as the catalog's name, never as till text.
        XCTAssertEqual(catalog.displayName(for: match.itemID, kitchenNames: [:], listName: nil,
                                           fallback: "TJ ORG BABY SPNC"),
                       match.name)
        // An item no catalog knows and nobody named: the raw text is all there is.
        XCTAssertEqual(catalog.displayName(for: ItemID(), kitchenNames: [:], listName: nil,
                                           fallback: "TJ ORG BABY SPNC"),
                       "TJ ORG BABY SPNC")
    }

    func testCatalogIdentityRoundTrips() {
        let itemID = ItemID.catalog(4_321)
        XCTAssertEqual(itemID.catalogID, 4_321)
        // Pinned: ids already on disk keep meaning, so estimates and receipts stay one price book.
        XCTAssertEqual(itemID.rawValue.uuidString, "BA60CA7A-1060-0001-0000-0000000010E1")
        XCTAssertNil(ItemID().catalogID)   // a minted id is nobody's catalog row
    }
}

extension ListStoreTests {
    /// The catalog gives butter `default_unit: "250 g"`, so the old rule rendered quantity 1 as
    /// "1 250 g" — which reads as 1250 g. Any unit opening with a digit collided the same way.
    func testAPackSizeIsNeverGluedToTheCountThatWouldChangeIt() {
        XCTAssertEqual(QuantityText.label(quantity: 1, unit: "250 g"), "250 g")
        XCTAssertEqual(QuantityText.label(quantity: 2, unit: "250 g"), "×2 · 250 g")
        XCTAssertEqual(QuantityText.label(quantity: 0.5, unit: "500 ml"), "×½ · 500 ml")
        // A measure unit is unchanged: it cannot be misread as part of the number.
        XCTAssertEqual(QuantityText.label(quantity: 2, unit: "lb"), "2 lb")
        XCTAssertEqual(QuantityText.label(quantity: 1, unit: "dozen"), "1 dozen")
        XCTAssertEqual(QuantityText.label(quantity: 1, unit: nil), nil)
        XCTAssertEqual(QuantityText.label(quantity: 3, unit: nil), "×3")
    }
}
