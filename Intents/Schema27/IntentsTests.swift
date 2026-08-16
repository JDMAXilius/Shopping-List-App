import Catalog
import Core
import Data
import DesignKit
import Foundation
import XCTest

@testable import Bagged

@available(iOS 27.0, *)
@MainActor
final class IntentsTests: XCTestCase {
    // MARK: - The add rule is the app's, not a second one

    func testAddThroughTheIntentWritesTheSameOpsAsTheAppsOwnAdd() async throws {
        for text in ["milk", "2 lb chicken breast", "two pounds of chicken", "unicorn steaks"] {
            let app = try prepare()
            try makeStore(app).add(text: text)

            let spoken = try prepare()
            IntentContext.databaseURL = spoken.url
            try await add(text)

            XCTAssertEqual(try described(spoken.repository), try described(app.repository),
                           "\"\(text)\" means different things to Siri and to the app")
        }
    }

    func testAddingWhatIsAlreadyThereMakesItMoreNotASecondRow() async throws {
        let app = try prepare()
        let store = try makeStore(app)
        store.add(text: "milk")
        store.add(text: "2 milk")

        let spoken = try prepare()
        IntentContext.databaseURL = spoken.url
        try await add("milk")
        try await add("2 milk")

        XCTAssertEqual(try described(spoken.repository), try described(app.repository))
        let context = try IntentContext.current()
        XCTAssertEqual(try context.items().count, 1)
        XCTAssertEqual(try context.items().first?.quantity, 3)
    }

    // MARK: - Only the app migrates

    func testASchemaMismatchWritesNothing() async throws {
        let url = temporaryURL()
        // Created, never migrated: user_version 0 against the version this build writes for.
        _ = try AppDatabase(url: url)
        IntentContext.databaseURL = url

        var intent = CreateReminderIntent()
        intent.title = "milk"
        do {
            _ = try await intent.perform()
            XCTFail("an intent must refuse a database this build does not agree with")
        } catch {
            XCTAssertTrue(error is IntentRefusal)
        }

        let database = try AppDatabase(url: url)
        try database.migrate()
        XCTAssertTrue(try Repository(database: database).unpushedOps().isEmpty)
    }

    // MARK: - Prices survive being spoken

    func testAnUnmeasuredPriceIsSpokenAsAnEstimate() async throws {
        let app = try prepare()
        IntentContext.databaseURL = app.url
        try await add("milk")

        let context = try IntentContext.current()
        let item = try XCTUnwrap(try context.items().first)
        let detail = try XCTUnwrap(try ItemEntity.one(item, context).detail)
        let phrase = try context.prices().display(item.itemID).accessibilityPhrase
        XCTAssertTrue(phrase.hasPrefix("about"), phrase)
        XCTAssertTrue(phrase.hasSuffix("estimated"), phrase)
        XCTAssertTrue(detail.hasSuffix(phrase), detail)
    }

    func testAMeasuredPriceIsSpokenAsItself() async throws {
        let app = try prepare()
        let shop = Shop(name: "Corner")
        try app.repository.append(.shop(.upsert(shop)), kitchenID: app.kitchen.id)
        IntentContext.databaseURL = app.url
        try await add("milk")

        let context = try IntentContext.current()
        let itemID = try XCTUnwrap(try context.items().first?.itemID)
        let estimated = try context.prices().display(itemID).accessibilityPhrase
        try app.repository.append(
            .price(PriceObservation(itemID: itemID, shopID: shop.id, date: Date(),
                                    amount: Money(minorUnits: 449, currencyCode: "USD"),
                                    source: .manual)),
            kitchenID: app.kitchen.id)

        let item = try XCTUnwrap(try context.items().first)
        let detail = try XCTUnwrap(try ItemEntity.one(item, context).detail)
        let measured = try context.prices().display(itemID).accessibilityPhrase
        XCTAssertNotEqual(measured, estimated)
        XCTAssertFalse(measured.contains("about"), measured)
        XCTAssertFalse(measured.contains("estimated"), measured)
        XCTAssertTrue(detail.hasSuffix(measured), detail)
    }

    // MARK: - Check off and delete are ops

    func testCheckingOffWritesACheckOp() async throws {
        let app = try prepare()
        IntentContext.databaseURL = app.url
        try await add("milk")

        let context = try IntentContext.current()
        var intent = UpdateReminderIntent()
        intent.target = try ItemEntity.one(try XCTUnwrap(try context.items().first), context)
        intent.isCompleted = true
        _ = try await intent.perform()

        XCTAssertEqual(try app.repository.unpushedOps().map(\.type), ["add", "check"])
        XCTAssertEqual(try context.items().first?.checked, true)
    }

    /// One op, not N: a delete sweeps the normalized-name group the row held (ARCHITECTURE §5),
    /// and that reasoning stays in Merge.
    func testDeletingRemovesTheWholeNameGroupWithOneOp() async throws {
        let app = try prepare()
        try app.repository.append(.add(ListItem(name: "Bread")), kitchenID: app.kitchen.id)
        try app.repository.append(.add(ListItem(name: "bread")), kitchenID: app.kitchen.id)
        IntentContext.databaseURL = app.url

        let context = try IntentContext.current()
        XCTAssertEqual(try context.items().count, 1)
        var intent = DeleteRemindersIntent()
        intent.entities = [try ItemEntity.one(try XCTUnwrap(try context.items().first), context)]
        _ = try await intent.perform()

        XCTAssertTrue(try context.items().isEmpty)
        XCTAssertEqual(try app.repository.unpushedOps().filter { $0.type == "delete" }.count, 1)
    }

    func testASecondListIsRefusedAndWritesNothing() async throws {
        let app = try prepare()
        IntentContext.databaseURL = app.url

        var intent = CreateListIntent()
        intent.type = .standard
        intent.name = "Camping"
        do {
            _ = try await intent.perform()
            XCTFail("Bagged has one list per kitchen and must say so")
        } catch {
            XCTAssertTrue(error is IntentRefusal)
        }
        XCTAssertTrue(try app.repository.unpushedOps().isEmpty)
    }

    // MARK: - The voice

    func testWhatCannotBeKeptIsSaidNotDropped() {
        XCTAssertNil(IntentVoice.notKept([]))
        XCTAssertEqual(IntentVoice.notKept(["due dates"]), "Bagged doesn't keep due dates.")
        XCTAssertEqual(IntentVoice.notKept(["due dates", "flags"]),
                       "Bagged doesn't keep due dates or flags.")
    }

    func testNothingSpokenPraisesOrExclaims() {
        let item = ListItem(name: "Milk", quantity: 2)
        let sentences = [
            IntentVoice.added(item, merged: false), IntentVoice.added(item, merged: true),
            IntentVoice.updated(item, checked: true, renamed: false, noted: false),
            IntentVoice.updated(item, checked: false, renamed: false, noted: false),
            IntentVoice.removed(["milk"]), IntentVoice.removed(["milk", "bread"]),
            IntentVoice.removed(["a", "b", "c"]),
        ]
        for sentence in sentences {
            XCTAssertFalse(sentence.contains("!"), sentence)
            for banned in ["great", "nice", "well done", "streak", "keep it up", "🎉"] {
                XCTAssertFalse(sentence.lowercased().contains(banned), sentence)
            }
        }
    }

    // MARK: - Plumbing

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

    private func add(_ text: String) async throws {
        var intent = CreateReminderIntent()
        intent.title = text
        _ = try await intent.perform()
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
