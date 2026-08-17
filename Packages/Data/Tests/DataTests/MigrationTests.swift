import GRDB
import XCTest
@testable import Data

final class MigrationTests: XCTestCase {
    private func makeDatabase() throws -> AppDatabase {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-tests-\(UUID().uuidString).sqlite")
        return try AppDatabase(url: url)
    }

    func testFreshMigrationCreatesSchema() throws {
        let database = try makeDatabase()
        try database.migrate()
        let tables = try database.pool.read { db in
            Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'"))
        }
        for expected in ["op", "list_item", "kitchen", "member", "shop", "aisle_order",
                         "price_observation", "receipt", "sync_state", "device",
                         "alias", "pending_scan", "item_name"] {
            XCTAssertTrue(tables.contains(expected), "missing table \(expected)")
        }
        let indexes = try database.pool.read { db in
            Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'index'"))
        }
        for expected in ["list_item_normalized_name", "price_observation_item_shop_date",
                         "op_unpushed"] {
            XCTAssertTrue(indexes.contains(expected), "missing index \(expected)")
        }
    }

    func testSchemaVersionExposed() throws {
        let database = try makeDatabase()
        XCTAssertEqual(try database.installedSchemaVersion(), 0, "unmigrated database reads 0")
        try database.migrate()
        XCTAssertEqual(try database.installedSchemaVersion(), AppDatabase.schemaVersion)
    }

    func testMigrateIsIdempotent() throws {
        let database = try makeDatabase()
        try database.migrate()
        try database.migrate()
        XCTAssertEqual(try database.installedSchemaVersion(), AppDatabase.schemaVersion)
        let opColumns = try database.pool.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(op)").map { $0["name"] as String }
        }
        XCTAssertEqual(Set(opColumns), ["op_id", "kitchen_id", "device_id", "clock", "wall_clock",
                                        "type", "payload", "origin", "pushed_at"])
    }

    func testPendingScanAndAliasArriveInV2() throws {
        let database = try makeDatabase()
        try Migrations.migrator.migrate(database.pool, upTo: "v1")
        let v1Tables = try tables(database)
        XCTAssertFalse(v1Tables.contains("pending_scan"), "pending_scan is a v2 table")
        XCTAssertFalse(v1Tables.contains("alias"))
        XCTAssertEqual(try database.installedSchemaVersion(), 1)

        // A row written under v1 must still be there after the upgrade.
        try database.pool.write { db in
            try db.execute(sql: "INSERT INTO kitchen (id, name) VALUES (?, ?)",
                           arguments: [UUID().uuidString, "Home"])
        }
        try database.migrate()
        XCTAssertEqual(try database.installedSchemaVersion(), AppDatabase.schemaVersion)
        XCTAssertTrue(try tables(database).isSuperset(of: ["alias", "pending_scan"]))
        let kitchens = try database.pool.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM kitchen")
        }
        XCTAssertEqual(kitchens, ["Home"], "the v1 → v2 upgrade preserves existing rows")

        let columns = try database.pool.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(pending_scan)").map { $0["name"] as String }
        }
        XCTAssertEqual(Set(columns), ["id", "shop_id", "captured_at", "photo_path", "state"])
    }

    func testPendingScanShopRelaxesToNullInV3() throws {
        let database = try makeDatabase()
        try Migrations.migrator.migrate(database.pool, upTo: "v2")
        let scanID = UUID().uuidString
        let shopID = UUID().uuidString
        try database.pool.write { db in
            try db.execute(sql: """
                INSERT INTO pending_scan (id, shop_id, captured_at, photo_path, state) \
                VALUES (?, ?, 7, '/tmp/a.jpg', 'queued')
                """, arguments: [scanID, shopID])
        }
        XCTAssertThrowsError(try insertShoplessScan(database), "shop_id is NOT NULL under v2")

        try database.migrate()
        let rows = try database.pool.read { db in
            try Row.fetchAll(db, sql: "SELECT id, shop_id FROM pending_scan")
        }
        XCTAssertEqual(rows.count, 1, "the v2 → v3 upgrade preserves queued captures")
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row["id"] as String, scanID)
        XCTAssertEqual(row["shop_id"] as String, shopID, "a scan that had a shop keeps it")
        XCTAssertNoThrow(try insertShoplessScan(database),
                         "a capture at the till has no shop yet — review resolves it")

        // The receipt a scan eventually becomes still requires a shop: a trip happened somewhere.
        let receiptShopNotNull = try database.pool.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(receipt)")
                .first { ($0["name"] as String) == "shop_id" }
                .map { $0["notnull"] as Int }
        }
        XCTAssertEqual(receiptShopNotNull, 1)
    }

    private func insertShoplessScan(_ database: AppDatabase) throws {
        try database.pool.write { db in
            try db.execute(sql: """
                INSERT INTO pending_scan (id, shop_id, captured_at, photo_path, state) \
                VALUES (?, NULL, 8, '/tmp/b.jpg', 'queued')
                """, arguments: [UUID().uuidString])
        }
    }

    func testItemNameAndKitchenCurrencyArriveInV4() throws {
        let database = try makeDatabase()
        try Migrations.migrator.migrate(database.pool, upTo: "v3")
        XCTAssertFalse(try tables(database).contains("item_name"), "item_name is a v4 table")
        XCTAssertEqual(try database.installedSchemaVersion(), 3,
                       "a database stopped at v3 must not claim to be v4")

        let kitchenID = UUID().uuidString
        try database.pool.write { db in
            try db.execute(sql: "INSERT INTO kitchen (id, name) VALUES (?, ?)",
                           arguments: [kitchenID, "Home"])
        }
        try database.migrate()
        XCTAssertEqual(try database.installedSchemaVersion(), AppDatabase.schemaVersion)
        XCTAssertTrue(try tables(database).contains("item_name"))

        let rows = try database.pool.read { db in
            try Row.fetchAll(db, sql: "SELECT id, name, currency_code FROM kitchen")
        }
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(rows.count, 1, "the v3 → v4 upgrade preserves the kitchen")
        XCTAssertEqual(row["name"] as String, "Home")
        XCTAssertEqual(row["currency_code"] as String, "USD",
                       "an existing kitchen's prices were minted as USD — the column says so, "
                       + "rather than relabelling them from today's locale")

        let columns = try database.pool.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(item_name)").map { $0["name"] as String }
        }
        XCTAssertEqual(Set(columns), ["item_id", "name"])
    }

    // W7 RULING 1: a receipt with no printed total must be able to say so in the database.
    func testTheReceiptTotalRelaxesToNullInV5() throws {
        let database = try makeDatabase()
        try Migrations.migrator.migrate(database.pool, upTo: "v4")
        XCTAssertEqual(try database.installedSchemaVersion(), 4,
                       "a database stopped at v4 must not claim to be v5")
        let receiptID = UUID().uuidString
        try database.pool.write { db in
            try db.execute(sql: """
                INSERT INTO receipt (id, shop_id, captured_at, line_count, total_minor, photo_path) \
                VALUES (?, ?, 9, 14, 8450, '/tmp/r.jpg')
                """, arguments: [receiptID, UUID().uuidString])
        }
        XCTAssertThrowsError(try insertTotallessReceipt(database), "total_minor is NOT NULL in v4")

        try database.migrate()

        XCTAssertEqual(try database.installedSchemaVersion(), AppDatabase.schemaVersion)
        let rows = try database.pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM receipt")
        }
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(rows.count, 1, "the v4 → v5 upgrade preserves captured trips")
        XCTAssertEqual(row["id"] as String, receiptID)
        XCTAssertEqual(row["total_minor"] as Int?, 8_450, "a stored total is not thrown away")
        XCTAssertNil(row["recorded_minor"] as Int?, "and nothing is invented for the new column")
        XCTAssertEqual(row["photo_path"] as String?, "/tmp/r.jpg")
        XCTAssertNoThrow(try insertTotallessReceipt(database),
                         "a receipt whose till total was never read stores none")
        // A trip still happened somewhere: relaxing the total must not relax the shop.
        let shopNotNull = try database.pool.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(receipt)")
                .first { ($0["name"] as String) == "shop_id" }
                .map { $0["notnull"] as Int }
        }
        XCTAssertEqual(shopNotNull, 1)
    }

    // W9 RULING 2: a price observation records how many were bought — and one written before
    // that must go on meaning one unit, not be silently rewritten into a count nobody made.
    func testThePriceQuantityArrivesInV6AndInventsNoCountForOldRows() throws {
        let database = try makeDatabase()
        try Migrations.migrator.migrate(database.pool, upTo: "v5")
        XCTAssertEqual(try database.installedSchemaVersion(), 5,
                       "a database stopped at v5 must not claim to be v6 — each migration "
                       + "stamps its own number")
        let opID = UUID().uuidString
        try database.pool.write { db in
            try db.execute(sql: """
                INSERT INTO price_observation \
                (op_id, item_id, shop_id, observed_at, amount_minor, currency, source) \
                VALUES (?, ?, ?, 1755300000000, 350, 'USD', 'receipt')
                """, arguments: [opID, UUID().uuidString, UUID().uuidString])
        }

        try database.migrate()

        XCTAssertEqual(try database.installedSchemaVersion(), AppDatabase.schemaVersion)
        let columns = try database.pool.read { db in
            try Row.fetchAll(db, sql: "PRAGMA table_info(price_observation)")
        }
        let added = try XCTUnwrap(columns.first { ($0["name"] as String) == "quantity_milli" })
        XCTAssertEqual(added["notnull"] as Int, 0, "an unrecorded count must be storable")
        XCTAssertNil(added["dflt_value"] as String?,
                     "a default of 1 would turn 'nobody counted' into 'one was bought'")

        let rows = try database.pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM price_observation")
        }
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(rows.count, 1, "the v5 → v6 upgrade preserves recorded prices")
        XCTAssertEqual(row["op_id"] as String, opID)
        XCTAssertEqual(row["amount_minor"] as Int, 350, "the price of one is not touched")
        XCTAssertNil(row["quantity_milli"] as Int?, "and no count is invented for it")
    }

    private func insertTotallessReceipt(_ database: AppDatabase) throws {
        try database.pool.write { db in
            try db.execute(sql: """
                INSERT INTO receipt (id, shop_id, captured_at, line_count, total_minor) \
                VALUES (?, ?, 10, 7, NULL)
                """, arguments: [UUID().uuidString, UUID().uuidString])
        }
    }

    func testPendingScanStateIsConstrained() throws {
        let database = try makeDatabase()
        try database.migrate()
        XCTAssertThrowsError(try database.pool.write { db in
            try db.execute(sql: """
                INSERT INTO pending_scan (id, shop_id, captured_at, photo_path, state) \
                VALUES (?, ?, 0, '/tmp/a.jpg', 'parsed')
                """, arguments: [UUID().uuidString, UUID().uuidString])
        }, "state is queued | parsing | failed and nothing else")
    }

    private func tables(_ database: AppDatabase) throws -> Set<String> {
        try database.pool.read { db in
            Set(try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table'"))
        }
    }
}

extension MigrationTests {
    /// A shop syncs; where it is does not. `wake_radius`/`wake_enabled` were syncing fields for
    /// device-local data — a field that still exists is a field the next packet will set, and
    /// setting it would arm a wake-up on a phone with no pin and tell the household which shops
    /// someone watches.
    func testTheGeofenceColumnsAreGoneInV7() throws {
        let database = try makeDatabase()
        try database.migrate()
        try database.pool.read { db in
            let columns = try db.columns(in: "shop").map(\.name)
            XCTAssertFalse(columns.contains("wake_radius"), "a pin must not ride an op")
            XCTAssertFalse(columns.contains("wake_enabled"))
            XCTAssertTrue(columns.contains("name"))
        }
        XCTAssertEqual(try database.installedSchemaVersion(), 7)
        XCTAssertEqual(AppDatabase.schemaVersion, 7)
    }
}
