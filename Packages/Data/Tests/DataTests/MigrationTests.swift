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
                         "price_observation", "receipt", "sync_state", "device"] {
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
}
