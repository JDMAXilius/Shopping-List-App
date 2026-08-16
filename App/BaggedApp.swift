import Core
import Data
import Foundation
import SwiftUI

@main
@MainActor
struct BaggedApp: App {
    // Must match the App Group entitlement on every target: app, widget, intents.
    static let appGroupID = "group.app.bagged"

    private let store: ListStore?

    init() {
        store = try? BaggedApp.openStore()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.listStore, store)
        }
    }

    private static func openStore() throws -> ListStore {
        let database = try AppDatabase(url: try databaseURL())
        // Only the app migrates; the widget renders last-known state on a version mismatch.
        try database.migrate()
        let repository = try Repository(database: database)
        let kitchens = try repository.kitchens()
        let kitchen = kitchens.first ?? Kitchen(name: "your kitchen")
        if kitchens.isEmpty { try repository.saveKitchen(kitchen) }
        return try ListStore(repository: repository, kitchenID: kitchen.id, catalog: ListCatalog())
    }

    private static func databaseURL() throws -> URL {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        return container.appending(path: "bagged.sqlite")
    }
}

extension UserDefaults {
    // The active shop and add-history live beside the database: the widget and intents
    // (wave 8) can only see the App Group, never this process's own sandbox.
    @MainActor static func appGroup() -> UserDefaults {
        UserDefaults(suiteName: BaggedApp.appGroupID) ?? .standard
    }
}
