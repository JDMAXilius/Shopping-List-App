import Catalog
import Core
import Data
import DesignKit
import Foundation

@Observable @MainActor
final class ListStore {
    private static let activeShopKey = "bagged.activeShopID"
    private static let historyKey = "bagged.deviceHistory"

    private let repository: Repository
    private let catalog: ListCatalog
    private let kitchenID: KitchenID
    private let defaults: UserDefaults
    private let observedItems: Observed<[ListItem]>
    private let observedShops: Observed<[Shop]>
    private let observedPrices: Observed<[PriceObservation]>
    private var undoStack: [Op.Kind] = []
    private var deviceHistory: [String]

    private(set) var activeShopID: ShopID?
    private(set) var aisleOrder: [CategoryID] = []
    // Fed by the SyncEngine once a transport exists (wave 9); until then always .synced.
    var syncStatus: SyncStatus = .synced

    init(repository: Repository, kitchenID: KitchenID, catalog: ListCatalog,
         defaults: UserDefaults = .standard) throws {
        self.repository = repository
        self.kitchenID = kitchenID
        self.catalog = catalog
        self.defaults = defaults
        observedItems = try repository.observedItems()
        observedShops = try repository.observedShops()
        observedPrices = try repository.observedPriceObservations()
        deviceHistory = defaults.stringArray(forKey: ListStore.historyKey) ?? []
        let saved = defaults.string(forKey: ListStore.activeShopKey)
            .flatMap(UUID.init(uuidString:)).map(ShopID.init)
        activeShopID = observedShops.value.first { $0.id == saved }?.id ?? observedShops.value.first?.id
        loadAisleOrder()
    }

    // MARK: - Derived state

    var shops: [Shop] { observedShops.value }
    var activeShop: Shop? { shops.first { $0.id == activeShopID } }

    var rows: [ListRow] {
        let lookup = priceLookup
        return observedItems.value.map {
            ListRow(item: $0, price: lookup.display($0.itemID),
                    category: catalog.category(for: $0.itemID))
        }
    }

    /// The one array TotalBar, the sub-line and every aisle subtotal derive from.
    var prices: [PriceDisplay] { rows.map(\.price) }
    var unpriced: [ListRow] { rows.filter { $0.price == .none && !$0.item.checked } }
    var completed: [ListRow] { rows.filter(\.item.checked) }
    var remainingCount: Int { rows.count - completed.count }
    var isComplete: Bool { !rows.isEmpty && completed.count == rows.count }

    var aisles: [AisleSection] {
        let promoted = Set(unpriced.map(\.id))
        return ListDerivation.aisles(rows.filter { !promoted.contains($0.id) },
                                     order: aisleOrder, catalog: catalog)
    }

    /// How many rows carry a measured price at that shop — the switcher's honest sub-line.
    func measuredCount(at shopID: ShopID) -> Int {
        let lookup = PriceLookup(observations: observedPrices.value, shopID: shopID, catalog: catalog)
        return observedItems.value.filter { item in
            item.itemID.flatMap { lookup.measured($0) } != nil
        }.count
    }

    func hasAisleOrder(_ shopID: ShopID) -> Bool {
        ((try? repository.aisleOrder(for: shopID)) ?? nil) != nil
    }

    func suggestions(for text: String) -> [ItemSuggestion] {
        ListDerivation.suggestions(query: text, history: deviceHistory,
                                   onList: rows.map(\.item.name), catalog: catalog,
                                   lookup: priceLookup)
    }

    var suggestedChips: [ItemSuggestion] {
        ListDerivation.chips(history: deviceHistory, onList: rows.map(\.item.name),
                             catalog: catalog, lookup: priceLookup)
    }

    // MARK: - Actions

    func add(text: String) {
        let parsed = QuantityParser.parse(text)
        let name = parsed.rest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let match = catalog.resolve(name)
        // A miss is a perfectly good row: no item id, no price, category `other`.
        let item = ListItem(itemID: match?.itemID, name: name, quantity: parsed.quantity ?? 1,
                            unit: parsed.unit ?? match?.unit, shopID: activeShopID)
        append(.add(item), undo: .delete(item.listItemID))
        remember(name)
        Haptics.play(.add)
    }

    func toggle(_ item: ListItem) {
        let id = item.listItemID
        append(item.checked ? .uncheck(id) : .check(id),
               undo: item.checked ? .check(id) : .uncheck(id))
        Haptics.play(item.checked ? .uncheck : .checkOff)
        if !item.checked { Sound.play(.check) }
    }

    /// The measured-price moment. Observations accumulate — there is no inverse op to undo.
    func setPrice(_ item: ListItem, _ amount: Money) {
        guard let shopID = activeShopID else { return }
        let itemID = item.itemID ?? ItemID()
        if item.itemID == nil { append(.edit(item.listItemID, [.itemID(itemID)]), undo: nil) }
        append(.price(PriceObservation(itemID: itemID, shopID: shopID, date: Date(),
                                       amount: amount, source: .manual)), undo: nil)
    }

    func edit(_ item: ListItem, _ writes: [FieldWrite]) {
        append(.edit(item.listItemID, writes), undo: nil)
    }

    func remove(_ item: ListItem) {
        append(.delete(item.listItemID), undo: .add(item))
        Haptics.play(.delete)
    }

    func undo() {
        guard let inverse = undoStack.popLast() else { return }
        try? repository.append(inverse, kitchenID: kitchenID)
        refresh()
        Haptics.play(.undo)
    }

    func switchShop(_ shopID: ShopID) {
        activeShopID = shopID
        defaults.set(shopID.rawValue.uuidString, forKey: ListStore.activeShopKey)
        loadAisleOrder()
    }

    func addShop(named name: String) {
        let shop = Shop(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !shop.name.isEmpty else { return }
        append(.shop(.upsert(shop)), undo: nil)
        switchShop(shop.id)
    }

    func reorderAisles(_ ordered: [CategoryID]) {
        guard let shopID = activeShopID else { return }
        append(.shop(.aisleOrder(AisleOrder(shopID: shopID, ordered: ordered))), undo: nil)
        aisleOrder = ordered
    }

    /// The pool's observation fires asynchronously, and the widget or an intent may have written
    /// while we were away — re-read after our own writes and on scene activation.
    func refresh() {
        observedItems.refresh()
        observedShops.refresh()
        observedPrices.refresh()
    }

    // MARK: - Plumbing

    private var priceLookup: PriceLookup {
        PriceLookup(observations: observedPrices.value, shopID: activeShopID, catalog: catalog)
    }

    private func loadAisleOrder() {
        aisleOrder = activeShopID.flatMap { try? repository.aisleOrder(for: $0) }?.ordered ?? []
    }

    private func append(_ kind: Op.Kind, undo inverse: Op.Kind?) {
        guard (try? repository.append(kind, kitchenID: kitchenID)) != nil else { return }
        refresh()
        guard let inverse else { return }
        undoStack.append(inverse)
        if undoStack.count > 20 { undoStack.removeFirst() }
    }

    private func remember(_ name: String) {
        deviceHistory.removeAll { Merge.normalized($0) == Merge.normalized(name) }
        deviceHistory = Array(([name] + deviceHistory).prefix(50))
        defaults.set(deviceHistory, forKey: ListStore.historyKey)
    }
}
