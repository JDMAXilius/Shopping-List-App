import Core
import DesignKit
import Foundation

struct ListRow: Identifiable, Hashable {
    let item: ListItem
    let price: PriceDisplay
    let category: CategoryGlyph
    var id: ListItemID { item.listItemID }
}

struct AisleSection: Identifiable {
    let category: CategoryGlyph
    let title: String
    let rows: [ListRow]         // what renders here: checked rows sink, promoted rows rise
    let prices: [PriceDisplay]  // the whole aisle, checked and promoted included
    let doneCount: Int
    let totalCount: Int
    var id: String { category.rawValue }
    var isCollapsed: Bool { doneCount == totalCount }
    var isEmpty: Bool { rows.isEmpty && doneCount == 0 }
}

struct ItemSuggestion: Identifiable, Hashable {
    let name: String
    let detail: String?
    let price: PriceDisplay
    let category: CategoryGlyph
    var id: String { Merge.normalized(name) }
}

// The one place a price becomes a tier: measured only from this shop's own observations,
// then the catalog's seeded estimate, then nothing. `—` beats a guess.
@MainActor
struct PriceLookup {
    let catalog: ListCatalog
    // Indexed once per build: a scan per row made the list O(rows × observations).
    private let latest: [ItemID: PriceObservation]
    private let counts: [ItemID: Int]

    init(observations: [PriceObservation], shopID: ShopID?, catalog: ListCatalog) {
        self.catalog = catalog
        var latest: [ItemID: PriceObservation] = [:]
        var counts: [ItemID: Int] = [:]
        for observation in observations {
            counts[observation.itemID, default: 0] += 1
            if observation.shopID == shopID { latest[observation.itemID] = observation }
        }
        self.latest = latest
        self.counts = counts
    }

    func display(_ itemID: ItemID?) -> PriceDisplay {
        guard let itemID else { return .none }
        if let measured = latest[itemID] {
            return PriceDisplay(amount: measured.amount, confidence: measured.confidence())
        }
        return catalog.estimate(for: itemID).map(PriceDisplay.estimated) ?? .none
    }

    /// "Priced" exactly as the row renders it: past 90 days an observation has demoted
    /// itself to an estimate, so counting it as measured would contradict the row.
    func isMeasured(_ itemID: ItemID?) -> Bool {
        guard let itemID, let observation = latest[itemID] else { return false }
        return observation.confidence() != .estimate
    }

    func recordedCount(_ itemID: ItemID) -> Int {
        counts[itemID] ?? 0
    }
}

// One quantity string for every surface: "×2", "1.5 lb", "½ dozen". The row, the detail
// sheet and VoiceOver must never disagree about how much of something you need.
enum QuantityText {
    /// Nil when there is nothing to say — one of something, no unit.
    static func label(quantity: Double, unit: String?) -> String? {
        let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !unit.isEmpty else { return quantity == 1 ? nil : "×\(number(quantity))" }
        return "\(number(quantity)) \(unit)"
    }

    static func number(_ value: Double) -> String {
        if let fraction = QuantityText.fractions[value] { return fraction }
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%g", value)
    }

    private static let fractions: [Double: String] = [0.25: "¼", 0.5: "½", 0.75: "¾"]
}

// Pure view-state assembly over rows the store already holds. This is the part that moves
// into a package the day the widget needs the same sections.
@MainActor
enum ListDerivation {
    /// What an add means for a list that may already hold the name: MORE of that row, never
    /// a second one that unchecks it and resets its quantity. The first op carries the undo.
    static func addPlan(name: String, quantity: Double?, unit: String?, items: [ListItem],
                        match: ListCatalog.Match?,
                        shopID: ShopID?) -> (ops: [Op.Kind], undo: Op.Kind) {
        let key = Merge.normalized(name)
        guard let existing = items.first(where: { Merge.normalized($0.name) == key }) else {
            // A miss is a perfectly good row: no item id, no price, category `other`.
            let item = ListItem(itemID: match?.itemID, name: name, quantity: quantity ?? 1,
                                unit: unit ?? match?.unit, shopID: shopID)
            return ([.add(item)], .delete(item.listItemID))
        }
        let id = existing.listItemID
        var ops: [Op.Kind] = [.edit(id, [.quantity(existing.quantity + (quantity ?? 1))])]
        // Needing more of something you already bought puts it back on the active list.
        if existing.checked { ops.append(.uncheck(id)) }
        return (ops, .edit(id, [.quantity(existing.quantity), .checked(existing.checked)]))
    }

    static func aisles(_ rows: [ListRow], order: [CategoryID], catalog: ListCatalog,
                       promoted: Set<ListItemID>) -> [AisleSection] {
        var grouped: [CategoryGlyph: [ListRow]] = [:]
        for row in rows { grouped[row.category, default: []].append(row) }
        return grouped.keys.sorted { rank($0, order, catalog) < rank($1, order, catalog) }
            .compactMap { category in
                guard let group = grouped[category] else { return nil }
                return AisleSection(
                    category: category, title: catalog.name(for: category),
                    // A promoted row renders under NO PRICE YET, but its gap still belongs to
                    // this aisle's subtotal — otherwise checking it off would invent an `≈`.
                    rows: group.filter { !$0.item.checked && !promoted.contains($0.id) },
                    prices: group.map(\.price),
                    doneCount: group.filter(\.item.checked).count, totalCount: group.count)
            }
    }

    /// The editor edits a shop's WHOLE walk order: an order carrying only today's aisles
    /// would wipe every aisle that happens to be empty this trip.
    static func allAisles(present: [AisleSection], order: [CategoryID],
                          catalog: ListCatalog) -> [AisleSection] {
        let shown = Set(present.map(\.category))
        let rest = CategoryGlyph.allCases.filter { !shown.contains($0) }
            .sorted { rank($0, order, catalog) < rank($1, order, catalog) }
        return present + rest.map {
            AisleSection(category: $0, title: catalog.name(for: $0), rows: [], prices: [],
                         doneCount: 0, totalCount: 0)
        }
    }

    private static func rank(_ category: CategoryGlyph, _ order: [CategoryID],
                             _ catalog: ListCatalog) -> Int {
        order.firstIndex(of: CategoryID(category.rawValue)) ?? (1000 + catalog.defaultOrder(category))
    }

    /// Yours beats the household's beats the catalog, deduped by normalized name.
    static func suggestions(query: String, history: [String], onList: [String],
                            catalog: ListCatalog, lookup: PriceLookup) -> [ItemSuggestion] {
        let normalized = Merge.normalized(query)
        var seen: Set<String> = []
        var out: [ItemSuggestion] = []
        func take(_ name: String, filtered: Bool) {
            let key = Merge.normalized(name)
            guard !key.isEmpty, !seen.contains(key), !filtered || key.contains(normalized) else { return }
            seen.insert(key)
            out.append(suggestion(named: name, catalog: catalog, lookup: lookup))
        }
        let filtered = !normalized.isEmpty
        history.forEach { take($0, filtered: filtered) }
        onList.forEach { take($0, filtered: filtered) }
        if filtered { catalog.matches(normalized).forEach { take($0.name, filtered: false) } }
        return Array(out.prefix(6))
    }

    /// SUGGESTED FOR YOU: one row of three, never something already on the list.
    static func chips(history: [String], onList: [String],
                      catalog: ListCatalog, lookup: PriceLookup) -> [ItemSuggestion] {
        var seen = Set(onList.map(Merge.normalized))
        var out: [ItemSuggestion] = []
        for name in history + ListCatalog.staples where out.count < 3 {
            guard seen.insert(Merge.normalized(name)).inserted else { continue }
            out.append(suggestion(named: name, catalog: catalog, lookup: lookup))
        }
        return out
    }

    private static func suggestion(named name: String, catalog: ListCatalog,
                                   lookup: PriceLookup) -> ItemSuggestion {
        // The name stays the caller's: a history row is what the user called it, never a rename.
        guard let match = catalog.resolve(name) else {
            return ItemSuggestion(name: name, detail: nil, price: .none, category: .other)
        }
        let recorded = lookup.recordedCount(match.itemID)
        return ItemSuggestion(
            name: name,
            detail: recorded == 0 ? nil : "\(recorded) price\(recorded == 1 ? "" : "s") recorded",
            price: lookup.display(match.itemID), category: match.category)
    }
}
