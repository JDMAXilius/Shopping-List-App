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
    let rows: [ListRow]         // unchecked only — checked rows sink into COMPLETED
    let prices: [PriceDisplay]  // the whole aisle, checked included: the subtotal is the aisle's
    let doneCount: Int
    let totalCount: Int
    var id: String { category.rawValue }
    var isCollapsed: Bool { doneCount == totalCount }
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
    let observations: [PriceObservation]
    let shopID: ShopID?
    let catalog: ListCatalog

    func display(_ itemID: ItemID?) -> PriceDisplay {
        guard let itemID else { return .none }
        if let measured = measured(itemID) {
            return PriceDisplay(amount: measured.amount, confidence: measured.confidence())
        }
        return catalog.estimate(for: itemID).map(PriceDisplay.estimated) ?? .none
    }

    func measured(_ itemID: ItemID) -> PriceObservation? {
        guard let shopID else { return nil }
        return observations.last { $0.itemID == itemID && $0.shopID == shopID }
    }

    func recordedCount(_ itemID: ItemID) -> Int {
        observations.filter { $0.itemID == itemID }.count
    }
}

// Pure view-state assembly over rows the store already holds. This is the part that moves
// into a package the day the widget needs the same sections.
@MainActor
enum ListDerivation {
    static func aisles(_ rows: [ListRow], order: [CategoryID], catalog: ListCatalog) -> [AisleSection] {
        var grouped: [CategoryGlyph: [ListRow]] = [:]
        for row in rows { grouped[row.category, default: []].append(row) }
        func rank(_ category: CategoryGlyph) -> Int {
            order.firstIndex(of: CategoryID(category.rawValue))
                ?? (1000 + catalog.defaultOrder(category))
        }
        return grouped.keys.sorted { rank($0) < rank($1) }.compactMap { category in
            guard let group = grouped[category] else { return nil }
            return AisleSection(
                category: category, title: catalog.name(for: category),
                rows: group.filter { !$0.item.checked }, prices: group.map(\.price),
                doneCount: group.filter(\.item.checked).count, totalCount: group.count)
        }
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
