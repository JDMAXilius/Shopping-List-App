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
    @ObservationIgnored private var bookCache: (key: BookKey, book: Book)?

    /// Not an op and not observed: the receipt index is bookkeeping, re-read on refresh.
    private(set) var receipts: [Receipt] = []
    var query = ""

    init(repository: Repository, kitchen: Kitchen, catalog: ListCatalog, list: ListStore) throws {
        self.repository = repository
        self.catalog = catalog
        self.list = list
        currencyCode = kitchen.currencyCode
        observedPrices = try repository.observedPriceObservations()
        observedShops = try repository.observedShops()
        observedItems = try repository.observedItems()
        observedNames = try repository.observedItemNames()
        receipts = (try? repository.receipts()) ?? []
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

    /// The pool's observation fires asynchronously and the receipt index is not observed at
    /// all — re-read on scene activation and when a capture closes.
    func refresh() {
        observedPrices.refresh()
        observedShops.refresh()
        observedItems.refresh()
        observedNames.refresh()
        receipts = (try? repository.receipts()) ?? []
    }

    private var shopNames: [ShopID: String] {
        Dictionary(observedShops.value.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    // Rebuilding 400 items on every body pass made scrolling the book quadratic; the inputs
    // are compared instead, the day included so "today" stops meaning yesterday.
    private var book: Book {
        let key = BookKey(observations: observedPrices.value, items: observedItems.value,
                          names: observedNames.value,
                          day: Calendar.current.startOfDay(for: Date()))
        if let cached = bookCache, cached.key == key { return cached.book }
        let built = PriceDerivation.book(observations: key.observations, items: key.items,
                                         names: key.names, shops: shopNames,
                                         catalog: catalog, now: Date())
        let book = Book(entries: built.entries, unnamed: built.unnamed)
        bookCache = (key, book)
        return book
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
    let day: Date
}
