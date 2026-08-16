import Foundation
import GRDB

public final class AppDatabase: Sendable {
    public static let schemaVersion = 1

    let pool: DatabasePool

    // App Group path in the app, a temp path in tests. DatabasePool is WAL by construction.
    public init(url: URL) throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
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
