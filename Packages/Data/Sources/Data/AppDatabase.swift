import Core
import Foundation
import GRDB

/// The strings four processes need to agree on to be looking at the same list. They were
/// re-declared by hand in the app, the widget and the intents — rename one there and the others
/// go on opening a different, empty database, silently and forever.
public enum AppGroup {
    public static let identifier = "group.app.bagged"
    public static let databaseFile = "bagged.sqlite"
    public static let activeShopKey = "bagged.activeShopID"

    /// nil when the entitlement is missing. Callers decide what that means: the app falls back to
    /// its own container so a simulator build still runs, an extension refuses — a second
    /// database is worse than no database.
    public static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    /// Which shop the phone is pointed at. The rule, not just the key: a saved id that names no
    /// surviving shop falls back to the first, and so does no saved id at all — `createShop`
    /// deliberately makes a shop without switching to it, so a kitchen whose only shop was born
    /// in the capture flow has never written the key. The app, the widget and the intents each
    /// had their own version of this; the widget's had no fallback, so on exactly that kitchen it
    /// found no shop, matched no observation, and quietly demoted every measured price on the
    /// tile to an estimate.
    public static func activeShopID(_ defaults: UserDefaults, shops: [Shop]) -> ShopID? {
        let saved = defaults.string(forKey: activeShopKey)
            .flatMap(UUID.init(uuidString:)).map(ShopID.init)
        return shops.first { $0.id == saved }?.id ?? shops.first?.id
    }

    public static func databaseURL(in container: URL) throws -> URL {
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        return container.appending(path: databaseFile)
    }
}

public final class AppDatabase: Sendable {
    public static let schemaVersion = 6

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
