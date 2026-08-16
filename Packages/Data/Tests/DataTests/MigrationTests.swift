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
                         "alias", "pending_scan"] {
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
        XCTAssertEqual(try database.installedSchemaVersion(), 2)
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
