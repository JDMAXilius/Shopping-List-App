import Core
import Data
import Foundation
import SwiftUI

@main
@MainActor
struct BaggedApp: App {
    // Data owns the string; the entitlement on every target must match it.
    static let appGroupID = AppGroup.identifier

    private let store: ListStore?
    private let prices: PriceStore?
    private let repository: Repository?
    private let kitchenID: KitchenID?
    private let catalog: ListCatalog
    private let scanBackend: any ScanBackend

    init() {
        #if DEBUG
        // UI tests launch with a clean slate; unreachable in a release build.
        if CommandLine.arguments.contains("--uitest-reset"), let url = try? BaggedApp.databaseURL() {
            try? FileManager.default.removeItem(at: url)
            UserDefaults.appGroup().removePersistentDomain(forName: BaggedApp.appGroupID)
        }
        #endif
        let opened = try? BaggedApp.openStore()
        // A catalog built before the kitchen was read would price its seeds in a guessed
        // currency; without a database there is no kitchen, and the device's own is all there is.
        catalog = opened?.catalog ?? ListCatalog()
        store = opened?.store
        prices = opened?.prices
        repository = opened?.repository
        kitchenID = opened?.kitchenID
        scanBackend = BaggedApp.makeScanBackend()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.listStore, store)
                .environment(\.priceStore, prices)
                .environment(\.repository, repository)
                .environment(\.kitchenID, kitchenID)
                .environment(\.catalog, catalog)
                .environment(\.scanBackend, scanBackend)
        }
    }

    private static func openStore()
        throws -> (store: ListStore, prices: PriceStore, repository: Repository,
                   kitchenID: KitchenID, catalog: ListCatalog) {
        let database = try AppDatabase(url: try databaseURL())
        // Only the app migrates; the widget renders last-known state on a version mismatch.
        try database.migrate()
        let repository = try Repository(database: database)
        sweepStrandedScans(repository)
        let kitchens = try repository.kitchens()
        let kitchen = kitchens.first ?? Kitchen(name: "your kitchen")
        if kitchens.isEmpty { try repository.saveKitchen(kitchen) }
        let catalog = ListCatalog(currencyCode: kitchen.currencyCode)
        let store = try ListStore(repository: repository, kitchenID: kitchen.id, catalog: catalog)
        let prices = try PriceStore(repository: repository, kitchen: kitchen, catalog: catalog,
                                    list: store)
        return (store, prices, repository, kitchen.id, catalog)
    }

    /// Any scan not in the queue is stranded — nothing else will ever pick it up. `.parsing` is
    /// an app kill mid-read; `.failed` is an earlier build, which wrote a state nothing swept.
    /// A failure here costs a retry, never the launch.
    private static func sweepStrandedScans(_ repository: Repository) {
        for stranded in (try? repository.pendingScans()) ?? [] where stranded.state != .queued {
            try? repository.markScan(stranded.id, .queued)
        }
    }

    /// The endpoint and the Supabase anon key come from this build's Info.plist — never a
    /// literal here, and no key is committed. Absent is a normal build, not a crash.
    private static func makeScanBackend() -> any ScanBackend {
        #if DEBUG
        if ScriptedScanBackend.isRequested { return ScriptedScanBackend() }
        #endif
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

    // The app falls back to its own container so a build without the entitlement still runs;
    // an extension refuses instead, because for it a second database would be a silent one.
    static func databaseURL() throws -> URL {
        try AppGroup.databaseURL(in: AppGroup.containerURL() ?? URL.applicationSupportDirectory)
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
