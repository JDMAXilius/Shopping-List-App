import Foundation
import GRDB

public final class AppDatabase: Sendable {
    public static let schemaVersion = 5

    let pool: DatabasePool
    // Receipt photos live beside the database, so they land in the App Group container too.
    let url: URL

    // App Group path in the app, a temp path in tests. DatabasePool is WAL by construction.
    public init(url: URL) throws {
        self.url = url
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        // Widget/intent processes write to this same file; wait out their locks, don't throw BUSY.
        configuration.busyMode = .timeout(5)
        pool = try DatabasePool(path: url.path, configuration: configuration)
    }

    // Only the app migrates; the widget compares installedSchemaVersion() and renders last-known state.
    public func migrate() throws {
        try Migrations.migrator.migrate(pool)
    }

    public func installedSchemaVersion() throws -> Int {
        try pool.read { db in
            try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
        }
    }
}
