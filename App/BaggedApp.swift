import Core
import Data
import Foundation
import SwiftUI

/// Everything the app is holding, in one place that can be rebuilt. Joining a kitchen changes
/// which kitchen every store reads, and a `let` on the App struct cannot answer that — so the
/// stores live here and `adopt(_:)` is the one path that swaps them.
@Observable @MainActor
final class AppSession {
    private(set) var list: ListStore?
    private(set) var prices: PriceStore?
    private(set) var kitchen: KitchenStore?
    private(set) var subscription: SubscriptionStore?
    private(set) var sync: SyncCoordinator?
    private(set) var kitchenID: KitchenID?
    private(set) var catalog: ListCatalog
    let places = PlaceStore()
    let repository: Repository?
    let scanBackend: any ScanBackend
    /// Built once and held. A second `KitchenServices.make()` would mint a second `KitchenAuth`
    /// over the same keychain item, and the two would race one single-use refresh token.
    private let services: KitchenServices.Services?

    init() {
        let opened = try? AppSession.open()
        repository = opened?.repository
        // A catalog built before the kitchen was read would price its seeds in a guessed
        // currency; without a database there is no kitchen, and the device's own is all there is.
        catalog = opened?.catalog ?? ListCatalog()
        services = KitchenServices.make()
        scanBackend = AppSession.makeScanBackend(auth: services?.auth)
        guard let repository, let opened else { return }
        adopt(opened.kitchen)
        // Arriving switches the list to that shop so the prices and the walk are already right.
        // The store announces it — a silent switch is how the wrong shop's prices get read.
        places.onArrival = { [weak self] shopID in self?.list?.switchShop(shopID, arrived: true) }
        kitchen = KitchenStore(repository: repository, kitchen: opened.kitchen,
                               backend: services?.backend,
                               onKitchenChange: { [weak self] id in self?.rebuild(id) },
                               // Read at the moment of sign-out, not captured: `adopt` replaces
                               // the store whenever the kitchen changes.
                               onSignOut: { [weak self] in
                                   self?.subscription?.forgetEntitlement()
                               })
    }

    /// The stores for one kitchen. Rebuilt whole rather than re-pointed: every one of them
    /// caches something keyed on the kitchen it was built for.
    private func adopt(_ kitchen: Kitchen) {
        guard let repository else { return }
        catalog = ListCatalog(currencyCode: kitchen.currencyCode)
        list = try? ListStore(repository: repository, kitchenID: kitchen.id, catalog: catalog)
        prices = list.flatMap {
            try? PriceStore(repository: repository, kitchen: kitchen, catalog: catalog, list: $0)
        }
        kitchenID = kitchen.id
        sync = SyncCoordinator(repository: repository, kitchenID: kitchen.id,
                               transport: services?.transport)
        // Entitlement reaches this device by being asked for, not only by scanning on it. The
        // read goes through `KitchenBackend` like every other server call; the store is handed a
        // closure, so nothing about Supabase reaches it.
        subscription = SubscriptionStore(defaults: .appGroup(),
                                         entitlement: { [backend = self.services?.backend] in
                                             await backend?.entitlement() ?? .unavailable
                                         })
    }

    private func rebuild(_ kitchenID: KitchenID) {
        guard let repository,
              let kitchen = (try? repository.kitchens())?.first(where: { $0.id == kitchenID })
        else { return }
        adopt(kitchen)
        sync?.start()
        sync?.kick()
        // A joiner is never paywalled: sharing is the growth loop, and the owner already paid.
        // Only a known answer moves the role; RootView adopts again when the roster lands.
        if let isGuest = self.kitchen?.isGuest { subscription?.adopt(isGuest ? .guest : .owner) }
        // Joining signs this phone in as a different user, so the cached entitlement may not be
        // this user's at all. Asked now rather than at the next foreground.
        Task { [store = self.subscription] in await store?.refreshEntitlement() }
    }

    private static func open()
        throws -> (repository: Repository, kitchen: Kitchen, catalog: ListCatalog) {
        let database = try AppDatabase(url: try BaggedApp.databaseURL())
        // Only the app migrates; the widget renders last-known state on a version mismatch.
        try database.migrate()
        let repository = try Repository(database: database)
        sweepStrandedScans(repository)
        let kitchens = try repository.kitchens()
        // The one you last used, not the alphabetically first: a guest who joined "Flat 2B"
        // would otherwise reopen into their own "your kitchen" and see an empty list.
        let kitchen = ActiveKitchen.resolve(kitchens, defaults: .appGroup())
            ?? kitchens.first ?? Kitchen(name: "your kitchen")
        if kitchens.isEmpty { try repository.saveKitchen(kitchen) }
        return (repository, kitchen, ListCatalog(currencyCode: kitchen.currencyCode))
    }

    /// Any scan not in the queue is stranded — nothing else will ever pick it up. `.parsing` is
    /// an app kill mid-read; `.failed` is an earlier build, which wrote a state nothing swept.
    /// A failure here costs a retry, never the launch.
    private static func sweepStrandedScans(_ repository: Repository) {
        for stranded in (try? repository.pendingScans()) ?? [] where stranded.state != .queued {
            try? repository.markScan(stranded.id, .queued)
        }
    }

    /// The endpoint and the anon key come from this build's Info.plist — never a literal here,
    /// and no key is committed. Absent is a normal build, not a crash.
    private static func makeScanBackend(auth: KitchenAuth?) -> any ScanBackend {
        #if DEBUG
        if ScriptedScanBackend.isRequested { return ScriptedScanBackend() }
        #endif
        guard let endpoint = BaggedApp.configuration("ScanReceiptEndpoint").flatMap(URL.init(string:)),
              let apiKey = BaggedApp.configuration("SupabaseAnonKey") else {
            return SignedOutScanBackend()
        }
        return ScanClient(endpoint: endpoint, apiKey: apiKey,
                          accessToken: { await auth?.accessToken() })
    }
}

@main
@MainActor
struct BaggedApp: App {
    // Data owns the string; the entitlement on every target must match it.
    static let appGroupID = AppGroup.identifier

    @State private var session: AppSession

    init() {
        #if DEBUG
        // UI tests launch with a clean slate; unreachable in a release build.
        if CommandLine.arguments.contains("--uitest-reset"), let url = try? BaggedApp.databaseURL() {
            try? FileManager.default.removeItem(at: url)
            UserDefaults.appGroup().removePersistentDomain(forName: BaggedApp.appGroupID)
        }
        #endif
        // Sound and haptics are process globals read at the moment a tick fires, so the switches
        // have to be applied before anything can tick — not when tab 3 first opens.
        SetupSettings.apply(UserDefaults.appGroup())
        _session = State(initialValue: AppSession())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.listStore, session.list)
                .environment(\.priceStore, session.prices)
                .environment(\.kitchenStore, session.kitchen)
                .environment(\.placeStore, session.places)
                .environment(\.subscriptionStore, session.subscription)
                .environment(\.syncCoordinator, session.sync)
                .environment(\.repository, session.repository)
                .environment(\.kitchenID, session.kitchenID)
                .environment(\.catalog, session.catalog)
                .environment(\.scanBackend, session.scanBackend)
        }
    }

    static func configuration(_ key: String) -> String? {
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

// No endpoint in this build — so the answer a signed-out caller would get from the reader is the
// true one, and the photo stays queued for when there is one.
private struct SignedOutScanBackend: ScanBackend {
    func scan(image: Foundation.Data, mediaType: ScanMediaType,
              shopHint: String?) async -> ScanOutcome {
        .unauthenticated
    }
}

extension UserDefaults {
    // The active shop and add-history live beside the database: the widget and intents
    // can only see the App Group, never this process's own sandbox.
    @MainActor static func appGroup() -> UserDefaults {
        UserDefaults(suiteName: BaggedApp.appGroupID) ?? .standard
    }
}
