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
    private var deviceHistory: [String]
    /// The KITCHEN's currency — it took the device's locale when it was created, and every price
    /// typed anywhere in the app is parsed and written in it. With no kitchen row there is no
    /// claim to make, so USD stands.
    let currencyCode: String
    // Set by a check-off, cleared by every other write: the arrival tone is never a
    // reward for deleting the last row.
    @ObservationIgnored private var checkedOff = false
    @ObservationIgnored private var rowCache: (key: RowKey, rows: [ListRow])?

    private(set) var activeShopID: ShopID?
    private(set) var aisleOrder: [CategoryID] = []
    /// One slot, not a stack: the newest inverse, offered only in the moment after the action
    /// that made it. Only an action with no other one-tap way back earns one — a check-off is
    /// reversed by its own tick, and a brand-new row by the row you are looking at.
    private(set) var pendingUndo: PendingUndo?
    // Fed by the SyncEngine once a transport exists (wave 9); until then always .synced.
    var syncStatus: SyncStatus = .synced

    init(repository: Repository, kitchenID: KitchenID, catalog: ListCatalog,
         defaults: UserDefaults = .appGroup()) throws {
        self.repository = repository
        self.kitchenID = kitchenID
        self.catalog = catalog
        self.defaults = defaults
        observedItems = try repository.observedItems()
        observedShops = try repository.observedShops()
        observedPrices = try repository.observedPriceObservations()
        deviceHistory = defaults.stringArray(forKey: ListStore.historyKey) ?? []
        currencyCode = ((try? repository.kitchens()) ?? [])
            .first { $0.id == kitchenID }?.currencyCode ?? "USD"
        let saved = defaults.string(forKey: ListStore.activeShopKey)
            .flatMap(UUID.init(uuidString:)).map(ShopID.init)
        activeShopID = observedShops.value.first { $0.id == saved }?.id ?? observedShops.value.first?.id
        loadAisleOrder()
    }

    // MARK: - Derived state

    var shops: [Shop] { observedShops.value }
    var activeShop: Shop? { shops.first { $0.id == activeShopID } }

    var rows: [ListRow] {
        let key = RowKey(items: observedItems.value, observations: observedPrices.value,
                         shopID: activeShopID)
        if let cached = rowCache, cached.key == key { return cached.rows }
        let lookup = priceLookup
        let rows = key.items.map {
            ListRow(item: $0, price: lookup.display($0.itemID),
                    category: catalog.category(for: $0.itemID))
        }
        rowCache = (key, rows)
        return rows
    }

    /// The one array TotalBar, the sub-line and every aisle subtotal derive from.
    var prices: [PriceDisplay] { rows.map(\.price) }
    var unpriced: [ListRow] { rows.filter { $0.price == .none && !$0.item.checked } }
    var completed: [ListRow] { rows.filter(\.item.checked) }
    var remainingCount: Int { rows.count - completed.count }
    var isComplete: Bool { !rows.isEmpty && completed.count == rows.count }

    var aisles: [AisleSection] {
        ListDerivation.aisles(rows, order: aisleOrder, catalog: catalog,
                              promoted: Set(unpriced.map(\.id)))
    }

    /// Every aisle, today's first — the walk order the editor saves must be total.
    var editableAisles: [AisleSection] {
        ListDerivation.allAisles(present: aisles, order: aisleOrder, catalog: catalog)
    }

    /// How many rows carry a measured price at that shop — the switcher's honest sub-line.
    func measuredCount(at shopID: ShopID) -> Int {
        let lookup = PriceLookup(observations: observedPrices.value, shopID: shopID, catalog: catalog)
        return observedItems.value.filter { lookup.isMeasured($0.itemID) }.count
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

    @discardableResult
    func add(text: String) -> Bool {
        let parsed = QuantityParser.parse(text)
        let name = parsed.rest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        let plan = ListDerivation.addPlan(name: name, quantity: parsed.quantity, unit: parsed.unit,
                                          items: observedItems.value, match: catalog.resolve(name),
                                          shopID: activeShopID)
        guard let first = plan.ops.first, append(first) else { return false }
        for kind in plan.ops.dropFirst() { append(kind) }
        // After the whole plan lands: every append clears the slot, and a merge's uncheck
        // would take the offer away in the same breath that earned it.
        pendingUndo = plan.undo
        remember(name)
        Haptics.play(.add)
        return true
    }

    func toggle(_ item: ListItem) {
        // No undo slot: the tick that checked it off is the same tap that unchecks it.
        let id = item.listItemID
        guard append(item.checked ? .uncheck(id) : .check(id)) else { return }
        checkedOff = !item.checked
        Haptics.play(item.checked ? .uncheck : .checkOff)
        if !item.checked { Sound.play(.check) }
    }

    /// True once per check-off, and only then: ListScreen's arrival moment reads it.
    func consumeCheckOff() -> Bool {
        defer { checkedOff = false }
        return checkedOff
    }

    /// The measured-price moment. Observations accumulate — there is no inverse op to undo.
    /// All three ops or none of them: a price the database refuses must not leave the row with
    /// an identity and a taught name it never earned, and the caller is told either way.
    @discardableResult
    func setPrice(_ item: ListItem, _ amount: Money) -> Bool {
        guard let shopID = activeShopID else { return false }
        let itemID = item.itemID ?? ItemID()
        var kinds: [Op.Kind] = []
        if item.itemID == nil {
            // A price whose identity never landed would belong to nobody — and an identity the
            // catalog cannot name is nameless the moment this row is deleted, so teach it too.
            kinds.append(.edit(item.listItemID, [.itemID(itemID)]))
            if itemID.catalogID == nil { kinds.append(.name(itemID, item.name)) }
        }
        kinds.append(.price(PriceObservation(itemID: itemID, shopID: shopID, date: Date(),
                                             amount: amount, source: .manual)))
        return append(kinds)
    }

    func edit(_ item: ListItem, _ writes: [FieldWrite]) {
        append(.edit(item.listItemID, writes))
    }

    func remove(_ item: ListItem) {
        let undo = ListDerivation.removalUndo(item)
        guard append(.delete(item.listItemID)) else { return }
        pendingUndo = undo
        Haptics.play(.delete)
    }

    func undo() {
        guard let pending = pendingUndo else { return }
        guard append(pending.inverse) else {
            // Nothing was written, so the offer still stands — append cleared it on the way in.
            pendingUndo = pending
            return
        }
        Haptics.play(.undo)
    }

    func dismissUndo() {
        pendingUndo = nil
    }

    func switchShop(_ shopID: ShopID) {
        activeShopID = shopID
        defaults.set(shopID.rawValue.uuidString, forKey: ListStore.activeShopKey)
        loadAisleOrder()
    }

    /// Makes a shop without making it the active one — filing a receipt at a shop you have not
    /// shopped at yet must not re-point the list you are standing in front of.
    func createShop(named name: String) -> ShopID? {
        let shop = Shop(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !shop.name.isEmpty, append(.shop(.upsert(shop))) else { return nil }
        return shop.id
    }

    func addShop(named name: String) {
        guard let shopID = createShop(named: name) else { return }
        switchShop(shopID)
    }

    func reorderAisles(_ ordered: [CategoryID]) {
        guard let shopID = activeShopID else { return }
        // The order the screen shows is the order that reached the database, or neither.
        guard append(.shop(.aisleOrder(AisleOrder(shopID: shopID, ordered: ordered)))) else { return }
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

    /// Every write clears the undo slot; the two actions that earn one set it afterwards.
    @discardableResult
    private func append(_ kind: Op.Kind) -> Bool {
        append([kind])
    }

    // One transaction for the whole group, so a refusal leaves nothing behind.
    @discardableResult
    private func append(_ kinds: [Op.Kind]) -> Bool {
        checkedOff = false
        pendingUndo = nil
        guard (try? repository.append(kinds, kitchenID: kitchenID)) != nil else { return false }
        refresh()
        return true
    }

    private func remember(_ name: String) {
        deviceHistory.removeAll { Merge.normalized($0) == Merge.normalized(name) }
        deviceHistory = Array(([name] + deviceHistory).prefix(50))
        defaults.set(deviceHistory, forKey: ListStore.historyKey)
    }
}

// What the rows were built from: unchanged inputs mean the built rows still stand.
private struct RowKey: Equatable {
    let items: [ListItem]
    let observations: [PriceObservation]
    let shopID: ShopID?
}
