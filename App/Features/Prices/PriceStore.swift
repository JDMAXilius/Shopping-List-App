import Core
import Data
import DesignKit
import Foundation

@Observable @MainActor
final class PriceStore {
    private let repository: Repository
    private let catalog: ListCatalog
    // The walk order belongs to the list (ARCHITECTURE §3), so the book asks the store that
    // owns it instead of re-deriving it from the same defaults key under a second name.
    private let list: ListStore
    // One kitchen shops in one currency; it is what a figure with no observation behind it
    // — a delta, a receipt total — is stated in.
    private let currencyCode: String
    private let observedPrices: Observed<[PriceObservation]>
    private let observedShops: Observed<[Shop]>
    private let observedItems: Observed<[ListItem]>
    private let observedNames: Observed<[ItemID: String]>
    @ObservationIgnored private var bookCache: (key: BookKey, book: Book, expires: Date)?

    private let observedReceipts: Observed<[Receipt]>
    var query = ""

    /// The month total is made entirely of these, so a receipt landing from sync while the
    /// screen is open has to move the number rather than wait for the tab to be left.
    var receipts: [Receipt] { observedReceipts.value }

    init(repository: Repository, kitchen: Kitchen, catalog: ListCatalog, list: ListStore) throws {
        self.repository = repository
        self.catalog = catalog
        self.list = list
        currencyCode = kitchen.currencyCode
        observedPrices = try repository.observedPriceObservations()
        observedShops = try repository.observedShops()
        observedItems = try repository.observedItems()
        observedNames = try repository.observedItemNames()
        observedReceipts = try repository.observedReceipts()
    }

    // MARK: - The book

    var stats: PriceBookStats { PriceDerivation.stats(observedPrices.value) }

    var aisles: [PriceBookAisle] {
        PriceDerivation.aisles(PriceDerivation.filter(book.entries, query: query),
                               order: list.aisleOrder, catalog: catalog)
    }

    /// The five newest, and only while nothing is being searched for — a search asks a
    /// question that a recency list does not answer.
    var recent: [PriceBookEntry] {
        isSearching ? [] : PriceDerivation.recent(book.entries)
    }

    var receiptRows: [ReceiptRow] {
        isSearching ? [] : PriceDerivation.receiptRows(receipts, shops: shopNames,
                                                       currencyCode: currencyCode, now: Date())
    }

    /// Ids the naming rule could not answer for. Never zero in a healthy kitchen; the screen
    /// states the count rather than heading a row with a UUID.
    var unnamedCount: Int { book.unnamed }

    var isEmpty: Bool { book.entries.isEmpty }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A kitchen with estimates but no observation at all has an empty price book in the only
    /// sense that matters: nothing here came from a receipt.
    var hasRecordedPrices: Bool { !observedPrices.value.isEmpty }

    // MARK: - The two pushed screens

    func history(for itemID: ItemID) -> ItemHistory? {
        PriceDerivation.history(for: itemID, observations: observedPrices.value,
                                names: observedNames.value,
                                listNames: PriceDerivation.names(of: observedItems.value),
                                shops: shopNames, catalog: catalog, now: Date())
    }

    var month: MonthSpend {
        PriceDerivation.month(observations: observedPrices.value, receipts: receipts,
                              shops: shopNames, catalog: catalog,
                              currencyCode: currencyCode, now: Date())
    }

    // MARK: - Plumbing

    /// The pool's observation fires asynchronously — re-read on scene activation and when a
    /// capture closes, in case the widget or an intent wrote while we were away.
    func refresh() {
        observedPrices.refresh()
        observedShops.refresh()
        observedItems.refresh()
        observedNames.refresh()
        observedReceipts.refresh()
    }

    private var shopNames: [ShopID: String] {
        Dictionary(observedShops.value.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    // Rebuilding 400 items on every body pass made scrolling the book quadratic; the inputs
    // are compared instead, plus an expiry, because two things here age: the words ("today")
    // and the tier (30 and 90 days).
    private var book: Book {
        let now = Date()
        let key = BookKey(observations: observedPrices.value, items: observedItems.value,
                          names: observedNames.value)
        // A day-wide key froze each entry's tier for up to 24 hours, so the book could print a
        // 90-day-old price in solid ink while its own history screen called it an estimate.
        // The cache lives until the first observation actually crosses 30 or 90 days.
        if let cached = bookCache, cached.key == key, now < cached.expires { return cached.book }
        let built = PriceDerivation.book(observations: key.observations, items: key.items,
                                         names: key.names, shops: shopNames,
                                         catalog: catalog, now: now)
        let book = Book(entries: built.entries, unnamed: built.unnamed)
        bookCache = (key, book, PriceStore.expiry(key.observations, after: now))
        return book
    }

    /// The soonest moment this book stops being true: an observation crossing 30 or 90 days,
    /// or midnight, after which "today" means yesterday. Past 90 days a price never moves again.
    static func expiry(_ observations: [PriceObservation], after now: Date) -> Date {
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        let crossings = observations.flatMap { [$0.date.addingTimeInterval(30 * 86_400),
                                                $0.date.addingTimeInterval(90 * 86_400)] }
        return min(midnight, crossings.filter { $0 > now }.min() ?? .distantFuture)
    }
}

private struct Book {
    let entries: [PriceBookEntry]
    let unnamed: Int
}

private struct BookKey: Equatable {
    let observations: [PriceObservation]
    let items: [ListItem]
    let names: [ItemID: String]
}
