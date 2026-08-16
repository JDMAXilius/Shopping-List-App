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
    private let repository: Repository?
    private let kitchenID: KitchenID?
    private let catalog: ListCatalog
    private let scanBackend: any ScanBackend

    init() {
        let catalog = ListCatalog()
        let opened = try? BaggedApp.openStore(catalog: catalog)
        self.catalog = catalog
        store = opened?.store
        repository = opened?.repository
        kitchenID = opened?.kitchenID
        scanBackend = BaggedApp.makeScanBackend()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.listStore, store)
                .environment(\.repository, repository)
                .environment(\.kitchenID, kitchenID)
                .environment(\.catalog, catalog)
                .environment(\.scanBackend, scanBackend)
        }
    }

    private static func openStore(catalog: ListCatalog)
        throws -> (store: ListStore, repository: Repository, kitchenID: KitchenID) {
        let database = try AppDatabase(url: try databaseURL())
        // Only the app migrates; the widget renders last-known state on a version mismatch.
        try database.migrate()
        let repository = try Repository(database: database)
        sweepStrandedScans(repository)
        let kitchens = try repository.kitchens()
        let kitchen = kitchens.first ?? Kitchen(name: "your kitchen")
        if kitchens.isEmpty { try repository.saveKitchen(kitchen) }
        let store = try ListStore(repository: repository, kitchenID: kitchen.id, catalog: catalog)
        return (store, repository, kitchen.id)
    }

    /// A scan left `parsing` by a killed app is stranded — nothing else will ever pick it up,
    /// and a failure here costs a retry, never the launch.
    private static func sweepStrandedScans(_ repository: Repository) {
        for stranded in (try? repository.pendingScans()) ?? [] where stranded.state == .parsing {
            try? repository.markScan(stranded.id, .queued)
        }
    }

    /// The endpoint and the Supabase anon key come from this build's Info.plist — never a
    /// literal here, and no key is committed. Absent is a normal build, not a crash.
    private static func makeScanBackend() -> any ScanBackend {
        guard let endpoint = configuration("ScanReceiptEndpoint").flatMap(URL.init(string:)),
              let apiKey = configuration("SupabaseAnonKey") else { return SignedOutScanBackend() }
        // Wave 9 owns sign-in. With no session there is no token, so the client answers
        // `.unauthenticated` without sending anything — the true state, not a stub.
        return ScanClient(endpoint: endpoint, apiKey: apiKey, accessToken: { nil })
    }

    private static func configuration(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }

    private static func databaseURL() throws -> URL {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        return container.appending(path: "bagged.sqlite")
    }
}

// No endpoint in this build, and no account either until wave 9 — so the answer a signed-out
// caller would get from the reader is the true one, and the photo stays queued for when there is.
private struct SignedOutScanBackend: ScanBackend {
    func scan(image: Foundation.Data, mediaType: ScanMediaType,
              shopHint: String?) async -> ScanOutcome {
        .unauthenticated
    }
}

extension UserDefaults {
    // The active shop and add-history live beside the database: the widget and intents
    // (wave 8) can only see the App Group, never this process's own sandbox.
    @MainActor static func appGroup() -> UserDefaults {
        UserDefaults(suiteName: BaggedApp.appGroupID) ?? .standard
    }
}
