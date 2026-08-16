import Core
import Data
import DesignKit
import Foundation
import Synchronization
import WidgetKit

/// The widget's own handle on the App Group database — its own process, so its own pool.
enum WidgetStore {
    /// Must equal the App Group entitlement on every target and `BaggedApp.appGroupID`.
    static let appGroupID = "group.app.bagged"
    /// Written by `ListStore` under this key; only the App Group can see it.
    private static let activeShopKey = "bagged.activeShopID"

    /// What this process can honestly do with the file right now — every failure named.
    enum Access {
        case ready(Repository, KitchenID)
        case noKitchen
        case needsApp
        case unreachable
    }

    struct Connection: Sendable {
        let database: AppDatabase
        let repository: Repository
    }

    // One pool for the life of the process: a DatabasePool per lock-screen tap is a real cost,
    // and every tap and every timeline pass wants the same file.
    private static let cache = Mutex<Connection?>(nil)

    static func shared() -> Access {
        if let connection = cache.withLock({ $0 }) { return access(connection) }
        guard let url = databaseURL() else { return .unreachable }
        let (state, connection) = connect(url)
        if let connection { cache.withLock { $0 = connection } }
        return state
    }

    /// Opens the shared file and NEVER creates or migrates it. A widget that created the
    /// database would hand the app an empty list; one that migrated it would be data loss.
    static func connect(_ url: URL) -> (Access, Connection?) {
        guard FileManager.default.fileExists(atPath: url.path),
              let database = try? AppDatabase(url: url) else { return (.unreachable, nil) }
        // The line this whole target turns on (AppDatabase.swift:21): only the app migrates,
        // so on a version this build disagrees with the widget reads nothing and writes nothing.
        guard (try? database.installedSchemaVersion()) == AppDatabase.schemaVersion else {
            return (.needsApp, nil)
        }
        guard let repository = try? Repository(database: database) else { return (.unreachable, nil) }
        let connection = Connection(database: database, repository: repository)
        return (access(connection), connection)
    }

    /// Re-read every pass: the app may have migrated since this process opened the file, so
    /// the version answer is the one thing that must never come from the cache.
    private static func access(_ connection: Connection) -> Access {
        guard (try? connection.database.installedSchemaVersion()) == AppDatabase.schemaVersion else {
            return .needsApp
        }
        guard let kitchen = (try? connection.repository.kitchens())?.first else { return .noKitchen }
        return .ready(connection.repository, kitchen.id)
    }

    /// nil when the container is unreachable. `BaggedApp` falls back to its own Application
    /// Support directory; this process must not — that is a different file, and always empty.
    static func databaseURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "bagged.sqlite")
    }

    /// The shop the app is shopping at: a measured price is that shop's own (`PriceLookup`).
    static func activeShopID(_ defaults: UserDefaults?) -> ShopID? {
        defaults?.string(forKey: activeShopKey).flatMap(UUID.init(uuidString:)).map(ShopID.init)
    }
}

struct WidgetRow: Identifiable, Hashable, Sendable {
    let id: ListItemID
    let name: String
    let isChecked: Bool
}

struct WidgetList: Hashable, Sendable {
    /// The prefix this family has room for — never the whole list.
    let rows: [WidgetRow]
    let remaining: Int
    let total: Int
    /// Over the WHOLE list, exactly as the app's `TotalBar`: the tile's figure and the app's
    /// figure are the same claim about the same basket.
    let summary: PriceSummary

    var hidden: Int { max(0, remaining - rows.filter { !$0.isChecked }.count) }
}

enum WidgetState: Hashable, Sendable {
    case list(WidgetList)
    case noKitchen
    case needsApp
    case unreachable
}

struct ListEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

enum WidgetSnapshot {
    /// Checked rows sink, exactly as they do on the list screen (`ListDerivation.aisles`), and
    /// the tile takes the first `limit` of what is left. No second ordering rule.
    static func list(items: [ListItem], observations: [PriceObservation], shopID: ShopID?,
                     limit: Int) -> WidgetList {
        let latest = measured(observations, at: shopID)
        let ordered = items.filter { !$0.checked } + items.filter(\.checked)
        return WidgetList(
            rows: ordered.prefix(limit).map {
                WidgetRow(id: $0.listItemID, name: $0.name, isChecked: $0.checked)
            },
            remaining: items.filter { !$0.checked }.count,
            total: items.count,
            summary: PriceSummary(items.map { display($0.itemID, latest) }))
    }

    /// `PriceLookup`'s rule for the measured tier, unchanged: this shop's own latest
    /// observation, and past 90 days Core has already demoted it to an estimate.
    private static func measured(_ observations: [PriceObservation],
                                 at shopID: ShopID?) -> [ItemID: PriceObservation] {
        var latest: [ItemID: PriceObservation] = [:]
        for observation in observations where observation.shopID == shopID {
            latest[observation.itemID] = observation
        }
        return latest
    }

    /// The seeded estimate tier is missing here and nowhere else: it lives behind `ListCatalog`,
    /// an app-target type an .appex cannot link, so an unmeasured row is `—` and counts as
    /// unpriced — which is what puts the `≈` on the total (see the report's contract gap).
    private static func display(_ itemID: ItemID?,
                                _ latest: [ItemID: PriceObservation]) -> PriceDisplay {
        guard let itemID, let observation = latest[itemID] else { return PriceDisplay.none }
        return PriceDisplay(amount: observation.amount, confidence: observation.confidence())
    }
}

struct WidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ListEntry {
        ListEntry(date: Date(), state: WidgetProvider.sample(limit: limit(context.family)))
    }

    func getSnapshot(in context: Context, completion: @escaping (ListEntry) -> Void) {
        // The gallery has no business reading someone's list; every other pass reads the truth.
        guard !context.isPreview else { return completion(placeholder(in: context)) }
        completion(entry(for: context.family))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ListEntry>) -> Void) {
        // A list changes when a person changes it, never on a clock: the app and
        // ToggleItemIntent request a reload after each write, so any refresh policy would only
        // spend this widget's budget re-rendering a list nobody touched.
        completion(Timeline(entries: [entry(for: context.family)], policy: .never))
    }

    /// From design/app/28-widget.png: three rows on the lock screen, two on the small tile.
    private func limit(_ family: WidgetFamily) -> Int {
        family == .accessoryRectangular ? 3 : 2
    }

    private func entry(for family: WidgetFamily) -> ListEntry {
        ListEntry(date: Date(),
                  state: WidgetProvider.state(WidgetStore.shared(),
                                              shopID: WidgetStore.activeShopID(
                                                  UserDefaults(suiteName: WidgetStore.appGroupID)),
                                              limit: limit(family)))
    }

    /// Four honest states and no fifth: no database, a schema this build disagrees with, no
    /// kitchen, or the list itself (empty included). Never a spinner, never a blank tile.
    static func state(_ access: WidgetStore.Access, shopID: ShopID?, limit: Int) -> WidgetState {
        switch access {
        case .unreachable: return .unreachable
        case .needsApp: return .needsApp
        case .noKitchen: return .noKitchen
        case .ready(let repository, _):
            guard let items = try? repository.items(),
                  let observations = try? repository.priceObservations() else { return .unreachable }
            return .list(WidgetSnapshot.list(items: items, observations: observations,
                                             shopID: shopID, limit: limit))
        }
    }

    /// The gallery tile: names with no money behind them, so the summary carries no prices
    /// and the figure renders `—`. A sample price would be a number nobody has ever paid.
    static func sample(limit: Int) -> WidgetState {
        let names = ["Bananas", "Oat milk", "Eggs"]
        let rows = names.prefix(limit).map { WidgetRow(id: ListItemID(), name: $0, isChecked: false) }
        return .list(WidgetList(rows: Array(rows), remaining: 5, total: 7,
                                summary: PriceSummary(Array(repeating: PriceDisplay.none, count: 7))))
    }
}
