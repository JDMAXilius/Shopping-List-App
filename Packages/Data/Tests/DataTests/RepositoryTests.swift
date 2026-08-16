import Core
import GRDB
import XCTest
@testable import Data

final class RepositoryTests: XCTestCase {
    private let kitchenID = KitchenID()

    private func makeStack() throws -> (AppDatabase, Repository) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("repository-tests-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        return (database, try Repository(database: database))
    }

    private func snapshot(_ database: AppDatabase) throws -> [String: [Row]] {
        let orders = ["list_item": "id", "shop": "id", "aisle_order": "shop_id, position",
                      "price_observation": "op_id"]
        return try database.pool.read { db in
            var tables: [String: [Row]] = [:]
            for (table, order) in orders {
                tables[table] = try Row.fetchAll(db, sql: "SELECT * FROM \(table) ORDER BY \(order)")
            }
            return tables
        }
    }

    // The wave's invariant: incrementally-maintained tables == full-replay tables.
    private func assertRebuildEquivalent(_ database: AppDatabase, _ repository: Repository,
                                         file: StaticString = #filePath, line: UInt = #line) throws {
        let incremental = try snapshot(database)
        try repository.rebuild()
        let replayed = try snapshot(database)
        XCTAssertEqual(incremental, replayed, "incremental state diverged from full replay",
                       file: file, line: line)
    }

    private func allOps(_ database: AppDatabase) throws -> [Op] {
        try database.pool.read { db in
            try OpRecord.fetchAll(db, sql: "SELECT * FROM op ORDER BY clock, op_id")
                .map { try OpCoding.op(from: $0) }
        }
    }

    private func stripped(_ item: ListItem) -> ListItem {
        var copy = item
        copy.updatedFields = [:]
        return copy
    }

    func testEveryOpTypeRoundTrips() throws {
        let (database, repository) = try makeStack()
        let item = ListItem(name: "Milk")
        let shop = Shop(name: "Trader Joe's", branch: "Court St", wakeRadius: 200, wakeEnabled: true)
        let observation = PriceObservation(itemID: ItemID(), shopID: shop.id, date: Date(),
                                           amount: Money(minorUnits: 449), source: .receipt)
        let order = AisleOrder(shopID: shop.id, ordered: [CategoryID("produce"), CategoryID("dairy")])
        let appended = [
            try repository.append(.add(item), kitchenID: kitchenID),
            try repository.append(.check(item.listItemID), kitchenID: kitchenID),
            try repository.append(.uncheck(item.listItemID), kitchenID: kitchenID),
            try repository.append(.edit(item.listItemID, [.quantity(2), .note("2%")]),
                                  kitchenID: kitchenID),
            try repository.append(.price(observation), kitchenID: kitchenID),
            try repository.append(.shop(.upsert(shop)), kitchenID: kitchenID),
            try repository.append(.shop(.aisleOrder(order)), kitchenID: kitchenID),
            try repository.append(.delete(item.listItemID), kitchenID: kitchenID),
        ]
        XCTAssertEqual(try repository.unpushedOps(), appended,
                       "every op kind round-trips through storage unchanged")
        XCTAssertEqual(try repository.shops(), [shop])
        XCTAssertEqual(try repository.aisleOrder(for: shop.id), order)
        XCTAssertEqual(try repository.priceObservations().count, 1)
        try assertRebuildEquivalent(database, repository)
    }

    func testReAddAfterDeleteResurrects() throws {
        let (database, repository) = try makeStack()
        let first = ListItem(name: "Milk")
        try repository.append(.add(first), kitchenID: kitchenID)
        try repository.append(.check(first.listItemID), kitchenID: kitchenID)
        try repository.append(.delete(first.listItemID), kitchenID: kitchenID)
        let again = ListItem(name: " milk ")
        try repository.append(.add(again), kitchenID: kitchenID)
        let items = try repository.items()
        XCTAssertEqual(items.map(\.name), ["milk"], "a later add of a deleted name resurrects")
        XCTAssertEqual(items.first?.listItemID, again.listItemID)
        XCTAssertEqual(items.first?.checked, false, "a re-added item arrives unchecked")
        try assertRebuildEquivalent(database, repository)
    }

    func testRenameCollisionCollapsesToOneRow() throws {
        let (database, repository) = try makeStack()
        let bread = ListItem(name: "Bread")
        let milk = ListItem(name: "Milk")
        try repository.append(.add(bread), kitchenID: kitchenID)
        try repository.append(.add(milk), kitchenID: kitchenID)
        try repository.append(.edit(milk.listItemID, [.note("2%")]), kitchenID: kitchenID)
        try repository.append(.edit(bread.listItemID, [.name("Milk")]), kitchenID: kitchenID)
        let items = try repository.items()
        XCTAssertEqual(items.map(\.name), ["Milk"], "renaming into an existing name is one row")
        XCTAssertEqual(items.first?.listItemID, bread.listItemID, "earlier createdAt keeps identity")
        XCTAssertEqual(items.first?.note, "2%", "fields from both rows merge into the collapsed row")
        try assertRebuildEquivalent(database, repository)
    }

    func testDeletingACrossDeviceTwinHoldsThroughRebuild() throws {
        let (_, remote) = try makeStack()
        let (database, repository) = try makeStack()
        let mine = ListItem(name: "Bread", createdAt: Date(msSince1970: 10_000))
        let theirs = ListItem(name: " bread ", createdAt: Date(msSince1970: 20_000))
        try repository.append(.add(mine), kitchenID: kitchenID)
        try remote.append(.add(theirs), kitchenID: kitchenID)
        let theirOps = try remote.unpushedOps()
        try repository.applyRemote(theirOps, cursor: 1, kitchenID: kitchenID)
        XCTAssertEqual(try repository.items().map(\.listItemID), [mine.listItemID],
                       "the twin collapses into the canonical row")
        try assertRebuildEquivalent(database, repository)

        try repository.append(.delete(mine.listItemID), kitchenID: kitchenID)
        XCTAssertTrue(try repository.items().isEmpty, "one delete removes the twin too")
        try assertRebuildEquivalent(database, repository)

        let again = ListItem(name: "Bread", createdAt: Date(msSince1970: 900_000))
        try repository.append(.add(again), kitchenID: kitchenID)
        XCTAssertEqual(try repository.items().map(\.listItemID), [again.listItemID],
                       "a later add of the swept name resurrects it")
        try assertRebuildEquivalent(database, repository)

        let everyOp = try allOps(database)
        let state = Merge.apply(everyOp, to: ListState())
        XCTAssertEqual(try repository.items(), state.items.map(stripped),
                       "the materialized list is exactly Core's projection")
    }

    func testDuplicatePriceLinesBothSurvive() throws {
        let (database, repository) = try makeStack()
        let observation = PriceObservation(itemID: ItemID(), shopID: ShopID(), date: Date(),
                                           amount: Money(minorUnits: 379), source: .receipt)
        try repository.append(.price(observation), kitchenID: kitchenID)
        try repository.append(.price(observation), kitchenID: kitchenID)
        XCTAssertEqual(try repository.priceObservations().count, 2,
                       "two identical receipt lines are two observations")
        try assertRebuildEquivalent(database, repository)
    }

    func testNormalizedNameGroupingMatchesCore() throws {
        let (database, repository) = try makeStack()
        try repository.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)
        try repository.append(.add(ListItem(name: "  milk ")), kitchenID: kitchenID)
        try repository.append(.add(ListItem(name: "MILK")), kitchenID: kitchenID)
        try repository.append(.add(ListItem(name: "Bread")), kitchenID: kitchenID)
        let items = try repository.items()
        XCTAssertEqual(items.count, 2)
        let normalized = try database.pool.read { db in
            try String.fetchAll(db, sql: "SELECT normalized_name FROM list_item")
        }
        XCTAssertEqual(normalized.count, Set(normalized).count,
                       "materialized normalized names are unique")
        let state = Merge.apply(try repository.unpushedOps(), to: ListState())
        XCTAssertEqual(items, state.items.map(stripped),
                       "the materialized list is exactly Core's projection")
        try assertRebuildEquivalent(database, repository)
    }

    func testDuplicatePullAdvancesCursorWithoutChurn() throws {
        let (_, remote) = try makeStack()
        let (database, repository) = try makeStack()
        try remote.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)
        let ops = try remote.unpushedOps()
        try repository.applyRemote(ops, cursor: 1, kitchenID: kitchenID)

        // A sentinel rowid: any projection rewrite would recreate the row without it.
        try database.pool.write { try $0.execute(sql: "UPDATE list_item SET rowid = 100") }
        let before = try rowidSnapshot(database)

        try repository.applyRemote(ops, cursor: 2, kitchenID: kitchenID)
        XCTAssertEqual(try rowidSnapshot(database), before,
                       "a duplicate-only pull leaves projection rows untouched")
        try repository.applyRemote([], cursor: 3, kitchenID: kitchenID)
        XCTAssertEqual(try rowidSnapshot(database), before,
                       "an empty pull leaves projection rows untouched")
        XCTAssertEqual(try repository.syncCursor(kitchenID: kitchenID), 3)
        XCTAssertEqual(try repository.items().map(\.name), ["Milk"])
    }

    @MainActor
    func testObservedRefreshSeesOtherPoolWrites() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("observed-tests-\(UUID().uuidString).sqlite")
        let databaseA = try AppDatabase(url: url)
        try databaseA.migrate()
        let observed = try Repository(database: databaseA).observedItems()
        XCTAssertTrue(observed.value.isEmpty)

        // A second pool on the same file stands in for the widget process.
        let repoB = try Repository(database: try AppDatabase(url: url))
        try repoB.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)

        observed.refresh()
        XCTAssertEqual(observed.value.map(\.name), ["Milk"],
                       "refresh() re-fetches writes ValueObservation cannot see")
    }

    private func rowidSnapshot(_ database: AppDatabase) throws -> [String: [Row]] {
        try database.pool.read { db in
            var tables: [String: [Row]] = [:]
            for table in ["list_item", "shop", "aisle_order", "price_observation"] {
                tables[table] = try Row.fetchAll(db,
                                                 sql: "SELECT rowid, * FROM \(table) ORDER BY rowid")
            }
            return tables
        }
    }
}
