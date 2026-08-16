import Catalog
import Core
import Data
import Foundation
import WidgetKit

/// What an intent needs when the app has never launched: the App Group database, the kitchen the
/// ops belong to, and the catalog. Only the app migrates (`AppDatabase.swift:21`), so a database
/// this build does not agree with is refused here, before anything can be written.
@MainActor
struct IntentContext {
    let repository: Repository
    let kitchen: Kitchen
    let catalog: ListCatalog

    // Tests point this at a temp file; nil means the App Group database the app migrates.
    static var databaseURL: URL?
    private static var cached: (url: URL, context: IntentContext)?

    static func current() throws -> IntentContext {
        let url = try databaseURL ?? appGroupURL()
        if let cached, cached.url == url { return cached.context }
        let database = try AppDatabase(url: url)
        guard try database.installedSchemaVersion() == AppDatabase.schemaVersion else {
            throw IntentRefusal.notReady
        }
        let repository = try Repository(database: database)
        guard let kitchen = try repository.kitchens().first else { throw IntentRefusal.noList }
        let context = IntentContext(repository: repository, kitchen: kitchen,
                                    catalog: ListCatalog(currencyCode: kitchen.currencyCode))
        cached = (url, context)
        return context
    }

    /// The shop the app is pointed at, exactly as `ListStore` resolves it — a saved id that no
    /// longer names a shop falls back to the first, so a spoken add lands where a typed one does.
    /// "Add milk at Trader Joe's" is a statement about where you are shopping, so it moves the
    /// list there — the row's shop, the prices quoted and the aisle order then all mean one
    /// thing. (Filing a past RECEIPT deliberately does not re-point the list: W6-P12. A receipt
    /// says where you WERE.)
    func switchActiveShop(_ shopID: ShopID) {
        UserDefaults.appGroup().set(shopID.rawValue.uuidString, forKey: AppGroup.activeShopKey)
    }

    var activeShopID: ShopID? {
        let shops = (try? repository.shops()) ?? []
        // ListStore's own key in the shared defaults; the two must not drift.
        let saved = UserDefaults.appGroup().string(forKey: AppGroup.activeShopKey)
            .flatMap(UUID.init(uuidString:)).map(ShopID.init)
        return shops.first { $0.id == saved }?.id ?? shops.first?.id
    }

    func items() throws -> [ListItem] {
        try repository.items()
    }

    func item(_ id: ListItemID) throws -> ListItem? {
        try items().first { $0.listItemID == id }
    }

    func prices() throws -> PriceLookup {
        PriceLookup(observations: try repository.priceObservations(), shopID: activeShopID,
                    catalog: catalog)
    }

    /// The only write path there is. The widget reloads in the same breath so the two surfaces
    /// cannot show different lists.
    func append(_ kinds: [Op.Kind]) throws {
        guard !kinds.isEmpty else { return }
        try repository.append(kinds, kitchenID: kitchen.id)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // BaggedApp.databaseURL() is private to the app; this is the same path by hand.
    private static func appGroupURL() throws -> URL {
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: BaggedApp.appGroupID)
            ?? URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        return container.appending(path: AppGroup.databaseFile)
    }
}
