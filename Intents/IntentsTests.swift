import Catalog
import Core
import Data
import DesignKit
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class IntentsTests: XCTestCase {
    // MARK: - The add rule is the app's, not a second one

    func testAddThroughSiriWritesTheSameOpsAsTheAppsOwnAdd() throws {
        for text in ["milk", "2 lb chicken breast", "two pounds of chicken", "unicorn steaks"] {
            let app = try prepare()
            try makeStore(app).add(text: text)

            let spoken = try prepare()
            IntentContext.databaseURL = spoken.url
            _ = try AddItemIntent.add(text, shop: nil)

            XCTAssertEqual(try described(spoken.repository), try described(app.repository),
                           "\"\(text)\" means different things to Siri and to the app")
        }
    }

    func testAddingWhatIsAlreadyThereMakesItMoreNotASecondRow() throws {
        let app = try prepare()
        let store = try makeStore(app)
        store.add(text: "milk")
        store.add(text: "2 milk")

        let spoken = try prepare()
        IntentContext.databaseURL = spoken.url
        _ = try AddItemIntent.add("milk", shop: nil)
        _ = try AddItemIntent.add("2 milk", shop: nil)

        XCTAssertEqual(try described(spoken.repository), try described(app.repository))
        let context = try IntentContext.current()
        XCTAssertEqual(try context.items().count, 1)
        XCTAssertEqual(try context.items().first?.quantity, 3)
    }

    func testANamedShopIsStampedOnTheRowAndOnlyThenSaid() throws {
        let app = try prepare()
        let shop = Shop(name: "Trader Joe's")
        try app.repository.append(.shop(.upsert(shop)), kitchenID: app.kitchen.id)
        IntentContext.databaseURL = app.url

        let named = try AddItemIntent.add("oat milk", shop: ShopEntity(shop))
        XCTAssertTrue(named.said.contains("Trader Joe's"), named.said)
        XCTAssertEqual(try IntentContext.current().items().first?.shopID, shop.id)

        // Unspecified means the active shop, exactly as a typed add resolves it — and a shop
        // nobody named is a shop nobody is told about.
        let quiet = try AddItemIntent.add("bread", shop: nil)
        XCTAssertFalse(quiet.said.contains("Trader Joe's"), quiet.said)
        let bread = try XCTUnwrap(try IntentContext.current().items()
            .first { $0.name.lowercased() == "bread" })
        XCTAssertEqual(bread.shopID, shop.id)
    }

    func testAMergeWithANamedShopStampsTheRowItMergedInto() throws {
        let app = try prepare()
        let shop = Shop(name: "Aldi")
        try app.repository.append(.shop(.upsert(shop)), kitchenID: app.kitchen.id)
        try app.repository.append(.add(ListItem(name: "Milk")), kitchenID: app.kitchen.id)
        IntentContext.databaseURL = app.url

        let said = try AddItemIntent.add("milk", shop: ShopEntity(shop)).said
        XCTAssertTrue(said.contains("Aldi"), said)
        XCTAssertEqual(try IntentContext.current().items().first?.shopID, shop.id)
    }

    // MARK: - Only the app migrates

    func testASchemaMismatchWritesNothingAndAnswersNothing() throws {
        let url = temporaryURL()
        // Created, never migrated: user_version 0 against the version this build writes for.
        _ = try AppDatabase(url: url)
        IntentContext.databaseURL = url

        refuses { _ = try AddItemIntent.add("milk", shop: nil) }
        refuses { _ = try ItemCheck.write(ListItemID(), checked: true) }
        refuses { _ = try ItemCheck.write(ListItemID(), checked: false) }
        refuses { _ = try RemoveItemIntent.remove(ListItemID()) }
        refuses { _ = try WhatsLeftIntent.left() }
        refuses { _ = try ReadListIntent.read() }

        let database = try AppDatabase(url: url)
        try database.migrate()
        XCTAssertTrue(try Repository(database: database).unpushedOps().isEmpty)
    }

    // MARK: - Money, said out loud

    func testTheSpokenPriceIsDesignKitsOneAndNotASecond() throws {
        let app = try prepare()
        let shop = Shop(name: "Corner")
        try app.repository.append(.shop(.upsert(shop)), kitchenID: app.kitchen.id)
        IntentContext.databaseURL = app.url
        _ = try AddItemIntent.add("milk", shop: nil)

        let context = try IntentContext.current()
        let seeded = try XCTUnwrap(try context.rows().first)
        let estimated = seeded.price.accessibilityPhrase
        XCTAssertTrue(estimated.hasPrefix("about"), estimated)
        XCTAssertTrue(estimated.hasSuffix("estimated"), estimated)
        XCTAssertEqual(ListItemEntity(seeded).detail?.hasSuffix(estimated), true)

        let itemID = try XCTUnwrap(seeded.item.itemID)
        try app.repository.append(
            .price(PriceObservation(itemID: itemID, shopID: shop.id, date: Date(),
                                    amount: Money(minorUnits: 449, currencyCode: "USD"),
                                    source: .manual)),
            kitchenID: app.kitchen.id)

        let priced = try XCTUnwrap(try context.rows().first)
        let measured = priced.price.accessibilityPhrase
        XCTAssertNotEqual(measured, estimated)
        XCTAssertFalse(measured.contains("about"), measured)
        XCTAssertFalse(measured.contains("estimated"), measured)
        XCTAssertEqual(ListItemEntity(priced).detail?.hasSuffix(measured), true)
    }

    /// The rule the lock screen was given this same wave, said out loud: the figure and what
    /// makes it approximate arrive together, or the figure does not arrive.
    func testATotalIsNeverSpokenBareWhenSomethingAboutItIsAGuess() {
        let measured = PriceDisplay(amount: Money(minorUnits: 449, currencyCode: "USD"),
                                    confidence: .trusted)
        let estimated = PriceDisplay.estimated(Money(minorUnits: 500, currencyCode: "USD"))
        let gap = PriceDisplay.none
        // Quantities included: the sentence must hold for a basket of fours and halves too.
        let combinations: [[PriceLine]] = [
            [], [gap.line(quantity: 1)], [gap.line(quantity: 3), gap.line(quantity: 1)],
            [measured.line(quantity: 1)], [measured.line(quantity: 4), measured.line(quantity: 2)],
            [estimated.line(quantity: 0.5)], [measured.line(quantity: 4),
                                              estimated.line(quantity: 1)],
            [measured.line(quantity: 2), gap.line(quantity: 1)],
            [measured.line(quantity: 4), estimated.line(quantity: 0.5),
             gap.line(quantity: 1), gap.line(quantity: 6)],
        ]
        for prices in combinations {
            let summary = PriceSummary(prices)
            let said = IntentVoice.total(summary)
            guard summary.hasPricedItems else {
                // Nothing is priced, so there is no figure to say — $0.00 would be a claim.
                XCTAssertFalse(said.contains("$"), said)
                continue
            }
            XCTAssertTrue(said.contains(summary.spokenTotal), said)
            XCTAssertFalse(said.contains("≈"), said)
            guard summary.isApproximate else {
                XCTAssertFalse(said.lowercased().contains("about"), said)
                continue
            }
            XCTAssertTrue(said.hasPrefix("about"), said)
            XCTAssertTrue(said.contains("estimated") || said.contains("no price yet"), said)
        }
    }

    func testWhatsLeftSpeaksTheUncheckedRowsAndQualifiesTheirTotal() throws {
        let app = try prepare()
        IntentContext.databaseURL = app.url
        _ = try AddItemIntent.add("milk", shop: nil)   // a seeded estimate
        _ = try AddItemIntent.add("bread", shop: nil)
        // No item identity, so no price at any shop and none in the catalog either.
        try app.repository.append(.add(ListItem(name: "Suet")), kitchenID: app.kitchen.id)

        let context = try IntentContext.current()
        let bread = try XCTUnwrap(try context.items().first { $0.name.lowercased() == "bread" })
        _ = try ItemCheck.write(bread.listItemID, checked: true)

        let left = try WhatsLeftIntent.left()
        XCTAssertEqual(left.entities.count, 2)
        XCTAssertFalse(left.said.lowercased().contains("bread"), left.said)
        XCTAssertTrue(left.said.contains("2 things left"), left.said)
        XCTAssertTrue(left.said.lowercased().contains("about"), left.said)
        XCTAssertTrue(left.said.contains("no price yet"), left.said)
    }

    /// "What it comes to" is what the trolley will hold (W8-P5 ruling 1). Four milks at a
    /// measured $3.50 comes to $14.00; Siri said $3.50 until this test existed.
    func testWhatItComesToCountsTheQuantitiesTheListSays() throws {
        let app = try prepare()
        let shop = Shop(name: "Corner")
        try app.repository.append(.shop(.upsert(shop)), kitchenID: app.kitchen.id)
        IntentContext.databaseURL = app.url
        _ = try AddItemIntent.add("4 milk", shop: nil)

        let context = try IntentContext.current()
        let milk = try XCTUnwrap(try context.items().first)
        let itemID = try XCTUnwrap(milk.itemID)
        XCTAssertEqual(milk.quantity, 4)
        try app.repository.append(
            .price(PriceObservation(itemID: itemID, shopID: shop.id, date: Date(),
                                    amount: Money(minorUnits: 350, currencyCode: "USD"),
                                    source: .manual)),
            kitchenID: app.kitchen.id)

        let said = try WhatsLeftIntent.left().said
        XCTAssertTrue(said.contains("$14.00"), said)
        XCTAssertFalse(said.contains("$3.50"), said)
        // All measured, so nothing is hedged.
        XCTAssertFalse(said.lowercased().contains("about"), said)
    }

    /// Ruling 5: `×4 · $3.50` read as four milks costing three fifty. The subtitle says
    /// which number is which, or it does not say both.
    func testASubtitleNeverLetsAUnitPriceReadAsALineTotal() throws {
        let app = try prepare()
        let shop = Shop(name: "Corner")
        try app.repository.append(.shop(.upsert(shop)), kitchenID: app.kitchen.id)
        IntentContext.databaseURL = app.url
        _ = try AddItemIntent.add("4 milk", shop: nil)
        let itemID = try XCTUnwrap(try XCTUnwrap(try IntentContext.current().items().first).itemID)
        try app.repository.append(
            .price(PriceObservation(itemID: itemID, shopID: shop.id, date: Date(),
                                    amount: Money(minorUnits: 350, currencyCode: "USD"),
                                    source: .manual)),
            kitchenID: app.kitchen.id)

        let row = try XCTUnwrap(try IntentContext.current().rows().first)
        let detail = try XCTUnwrap(ListItemEntity(row).detail)
        XCTAssertEqual(detail, "×4 at $3.50")
        XCTAssertFalse(detail.contains("×4 · $3.50"), detail)
        // The price is still DesignKit's one phrase, unforked.
        XCTAssertTrue(detail.hasSuffix(row.price.accessibilityPhrase), detail)
    }

    /// One of something says the price plainly: there is no multiplier to be confused with.
    func testASubtitleForOneOfSomethingIsJustThePrice() throws {
        let app = try prepare()
        IntentContext.databaseURL = app.url
        _ = try AddItemIntent.add("milk", shop: nil)
        let row = try XCTUnwrap(try IntentContext.current().rows().first)
        XCTAssertEqual(ListItemEntity(row).detail, row.price.accessibilityPhrase)
    }

    func testAnEmptyListAndAFinishedListAreDifferentSentences() throws {
        let app = try prepare()
        IntentContext.databaseURL = app.url
        XCTAssertEqual(try WhatsLeftIntent.left().said, "The list is empty.")

        _ = try AddItemIntent.add("milk", shop: nil)
        let milk = try XCTUnwrap(try IntentContext.current().items().first)
        _ = try ItemCheck.write(milk.listItemID, checked: true)
        XCTAssertEqual(try WhatsLeftIntent.left().said, "Everything's checked off.")
    }

    // MARK: - The walk order is the app's

    func testReadAloudFollowsTheOrderTheScreenShows() throws {
        let app = try prepare()
        let shop = Shop(name: "Corner")
        try app.repository.append(.shop(.upsert(shop)), kitchenID: app.kitchen.id)
        IntentContext.databaseURL = app.url
        for text in ["milk", "bananas", "bread", "eggs"] {
            _ = try AddItemIntent.add(text, shop: nil)
        }
        // A walk order the app saved, deliberately not the catalog's default one.
        let reversed = CategoryGlyph.allCases.reversed().map { CategoryID($0.rawValue) }
        let order = AisleOrder(shopID: shop.id, ordered: reversed)
        try app.repository.append(.shop(.aisleOrder(order)), kitchenID: app.kitchen.id)

        let store = try makeStore(app)
        let onScreen = store.aisles.filter { !$0.rows.isEmpty }.map(\.title)
        let spoken = try IntentContext.current().walk().map(\.title)
        XCTAssertFalse(onScreen.isEmpty)
        // Every aisle the screen shows is spoken, in the screen's order. The spoken walk may
        // hold one more: a row the screen promoted to NO PRICE YET is still in its aisle here.
        XCTAssertEqual(spoken.filter { onScreen.contains($0) }, onScreen)

        // And they are said in that order — the read-back is the walk.
        let said = try ReadListIntent.read().said
        var cursor = said.startIndex
        for title in spoken {
            let found = try XCTUnwrap(said.range(of: "\(title):", range: cursor..<said.endIndex),
                                      "\(title) out of order in: \(said)")
            cursor = found.upperBound
        }
    }

    // MARK: - An ambiguous name asks

    func testAnExactNameIsAnAnswerAndAnythingElseIsOfferedForTheAsk() throws {
        let rows = [row("Milk"), row("Oat milk"), row("Rye bread"), row("White bread")]
        XCTAssertEqual(ListItemEntityQuery.matching("milk", in: rows).map(\.item.name), ["Milk"])
        XCTAssertEqual(ListItemEntityQuery.matching("bread", in: rows).map(\.item.name),
                       ["Rye bread", "White bread"])
        XCTAssertTrue(ListItemEntityQuery.matching("saffron", in: rows).isEmpty)
        XCTAssertTrue(ListItemEntityQuery.matching("   ", in: rows).isEmpty)
        // People say "the milk", and nothing between Siri and here strips the article.
        XCTAssertEqual(ListItemEntityQuery.matching("the milk", in: rows).map(\.item.name),
                       ["Milk"])
        XCTAssertEqual(ListItemEntityQuery.matching("some rye bread", in: rows).map(\.item.name),
                       ["Rye bread"])
    }

    // MARK: - Check off, put back, remove

    func testCheckingOffWritesOneCheckOpAndSayingItTwiceWritesNothingMore() throws {
        let app = try prepare()
        IntentContext.databaseURL = app.url
        _ = try AddItemIntent.add("milk", shop: nil)
        let milk = try XCTUnwrap(try IntentContext.current().items().first)

        XCTAssertEqual(try ItemCheck.write(milk.listItemID, checked: true),
                       "Checked off \(milk.name).")
        XCTAssertEqual(try ItemCheck.write(milk.listItemID, checked: true),
                       "\(milk.name) was already checked off.")
        XCTAssertEqual(try app.repository.unpushedOps().map(\.type), ["add", "check"])

        XCTAssertEqual(try ItemCheck.write(milk.listItemID, checked: false),
                       "\(milk.name) is back on the list.")
        XCTAssertEqual(try app.repository.unpushedOps().map(\.type), ["add", "check", "uncheck"])
    }

    func testRemovingSaysWhatItRemovedAndWritesOneDeleteOp() throws {
        let app = try prepare()
        IntentContext.databaseURL = app.url
        _ = try AddItemIntent.add("milk", shop: nil)
        let milk = try XCTUnwrap(try IntentContext.current().items().first)

        XCTAssertEqual(try RemoveItemIntent.remove(milk.listItemID), "Removed \(milk.name).")
        XCTAssertTrue(try IntentContext.current().items().isEmpty)
        XCTAssertEqual(try app.repository.unpushedOps().filter { $0.type == "delete" }.count, 1)
        // A row that is gone takes no op: a ghost delete is valid, syncable and about nothing.
        refuses { _ = try RemoveItemIntent.remove(milk.listItemID) }
        XCTAssertEqual(try app.repository.unpushedOps().filter { $0.type == "delete" }.count, 1)
    }

    func testTheDeletionQuestionIsAQuestion() {
        XCTAssertEqual(IntentVoice.removalQuestion("Milk"), "Remove Milk from the list?")
    }

    // MARK: - The voice

    func testNothingSpokenPraisesOrExclaims() {
        let item = ListItem(name: "Milk", quantity: 2)
        let rows = [row("Milk"), row("Bread")]
        let sentences = [
            IntentVoice.added(item, merged: false), IntentVoice.added(item, merged: true),
            IntentVoice.added(item, merged: false, shop: "Aldi"),
            IntentVoice.updated(item, checked: true), IntentVoice.updated(item, checked: false),
            IntentVoice.already(item, checked: true), IntentVoice.already(item, checked: false),
            IntentVoice.removed(["milk"]), IntentVoice.removalQuestion("Milk"),
            IntentVoice.whatsLeft(rows, onList: 4), IntentVoice.whatsLeft([], onList: 4),
            IntentVoice.whatsLeft([], onList: 0),
            IntentVoice.total(PriceSummary(rows.map(\.line))),
        ]
        for sentence in sentences {
            XCTAssertFalse(sentence.contains("!"), sentence)
            for banned in ["great", "nice", "well done", "streak", "keep it up", "almost there",
                           "🎉"] {
                XCTAssertFalse(sentence.lowercased().contains(banned), sentence)
            }
        }
    }

    func testNamesAreJoinedTheWayAPersonWouldSayThem() {
        XCTAssertEqual(IntentVoice.names([]), "nothing")
        XCTAssertEqual(IntentVoice.names(["milk"]), "milk")
        XCTAssertEqual(IntentVoice.names(["milk", "bread"]), "milk and bread")
        XCTAssertEqual(IntentVoice.names(["milk", "bread", "eggs"]), "milk, bread and eggs")
    }

    // MARK: - Plumbing

    private func refuses(_ body: () throws -> Void, line: UInt = #line) {
        XCTAssertThrowsError(try body(), line: line) { error in
            XCTAssertTrue(error is IntentRefusal, "\(error)", line: line)
        }
    }

    private func row(_ name: String, price: PriceDisplay = .none) -> ListRow {
        ListRow(item: ListItem(name: name), price: price, category: .other)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("intents-\(UUID().uuidString).sqlite")
    }

    /// A phone the app has been opened on once: migrated, one kitchen, nothing on the list.
    private func prepare() throws -> (url: URL, repository: Repository, kitchen: Kitchen) {
        let url = temporaryURL()
        let database = try AppDatabase(url: url)
        try database.migrate()
        let repository = try Repository(database: database)
        let kitchen = Kitchen(name: "Home", currencyCode: "USD")
        try repository.saveKitchen(kitchen)
        return (url, repository, kitchen)
    }

    private func makeStore(_ app: (url: URL, repository: Repository,
                                  kitchen: Kitchen)) throws -> ListStore {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(UUID().uuidString)"))
        return try ListStore(repository: app.repository, kitchenID: app.kitchen.id,
                             catalog: ListCatalog(database: try CatalogDatabase.bundled(),
                                                  currencyCode: "USD"),
                             defaults: defaults)
    }

    /// What was written, never which UUID it landed under.
    private func described(_ repository: Repository) throws -> [String] {
        try repository.unpushedOps().map { op in
            switch op.kind {
            case .add(let item):
                return "add name=\(item.name) q=\(item.quantity) unit=\(item.unit ?? "-") "
                    + "item=\(item.itemID.map { described($0) } ?? "-") "
                    + "shop=\(item.shopID == nil ? "-" : "set")"
            case .edit(_, let writes):
                return "edit \(writes.map { described($0) }.sorted().joined(separator: ","))"
            default:
                return op.type
            }
        }
    }

    private func described(_ itemID: ItemID) -> String {
        itemID.catalogID.map { "catalog:\($0)" } ?? "own"
    }

    private func described(_ write: FieldWrite) -> String {
        switch write {
        case .itemID(let value): return "itemID=\(value.map { described($0) } ?? "-")"
        case .name(let value): return "name=\(value)"
        case .quantity(let value): return "quantity=\(value)"
        case .unit(let value): return "unit=\(value ?? "-")"
        case .note(let value): return "note=\(value ?? "-")"
        case .checked(let value): return "checked=\(value)"
        case .shopID(let value): return "shopID=\(value == nil ? "-" : "set")"
        }
    }
}
