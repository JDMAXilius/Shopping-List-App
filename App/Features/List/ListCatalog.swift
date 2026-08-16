import Catalog
import Core
import DesignKit
import Foundation

// The bundled catalog as the list uses it: resolving, seeded estimates in this region's money,
// and the category names the aisles are titled with.
@MainActor
final class ListCatalog {
    struct Match: Hashable, Sendable {
        let itemID: ItemID
        let name: String
        let unit: String?
        let category: CategoryGlyph
    }

    // The empty-list grid: staples every catalog resolves, in the render's order.
    static let staples = ["Butter", "Coffee", "Bread", "Milk", "Eggs", "Bananas"]

    private let database: CatalogDatabase?
    private let regionKey: String
    private let multiplier: Double
    private var categoryNames: [String: String] = [:]
    private var categoryOrder: [String: Int] = [:]
    private var categoryCache: [Int64: CategoryGlyph] = [:]
    private var estimateCache: [Int64: Money?] = [:]
    private var itemCache: [Int64: Match?] = [:]

    init(database: CatalogDatabase? = try? CatalogDatabase.bundled(), regionKey: String = "us-national") {
        self.database = database
        self.regionKey = regionKey
        guard let database else {
            multiplier = 1
            return
        }
        multiplier = ((try? database.priceRegion(regionKey)) ?? nil)?.multiplier ?? 1
        for category in database.categories() {
            categoryNames[category.id] = category.name
            categoryOrder[category.id] = category.defaultOrder
        }
    }

    func resolve(_ text: String) -> Match? {
        matches(text, limit: 1).first
    }

    func matches(_ text: String, limit: Int = 6) -> [Match] {
        guard let database else { return [] }
        let hits = (try? Catalog.resolve(db: database, query: text, limit: limit)) ?? []
        return hits.map { hit in
            let glyph = CategoryGlyph(rawValue: hit.categoryID) ?? .other
            categoryCache[hit.id] = glyph
            if let base = hit.baseAmount, estimateCache[hit.id] == nil {
                estimateCache[hit.id] = .some(money(PriceEstimate.rounded(base * multiplier)))
            }
            return Match(itemID: .catalog(hit.id), name: display(hit.canonicalName),
                         unit: hit.defaultUnit, category: glyph)
        }
    }

    /// The catalog stores names lowercase because that is how it matches. Casing is fixed HERE,
    /// once, so what gets written to the list is exactly what the user was shown — the widget
    /// and the CSV need no display rule of their own. Only the first character moves, so a
    /// user's own "2% milk" or "TJ" survives untouched.
    private func display(_ name: String) -> String {
        guard let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }

    /// The catalog item behind an id we hold with no text — a remembered alias, a stored row.
    /// nil for a user-created item, which no catalog row can name.
    func item(for itemID: ItemID) -> Match? {
        guard let database, let catalogID = itemID.catalogID else { return nil }
        if let cached = itemCache[catalogID] { return cached }
        let match = database.item(catalogID).map { item in
            let glyph = CategoryGlyph(rawValue: item.categoryID) ?? .other
            categoryCache[item.id] = glyph
            return Match(itemID: .catalog(item.id), name: display(item.canonicalName),
                         unit: item.defaultUnit, category: glyph)
        }
        itemCache[catalogID] = .some(match)
        return match
    }

    // The seeded estimate every added item lands with — nil when the item has no seed.
    func estimate(for itemID: ItemID) -> Money? {
        guard let database, let catalogID = itemID.catalogID else { return nil }
        if let cached = estimateCache[catalogID] { return cached }
        let amount = (try? PriceEstimate.estimate(
            db: database, itemID: catalogID, regionKey: regionKey)).flatMap { $0 }
        let result = amount.map { money($0) }
        estimateCache[catalogID] = .some(result)
        return result
    }

    func category(for itemID: ItemID?) -> CategoryGlyph {
        guard let itemID, let database, let catalogID = itemID.catalogID else { return .other }
        if let cached = categoryCache[catalogID] { return cached }
        let glyph = database.category(forItem: catalogID)
            .flatMap(CategoryGlyph.init(rawValue:)) ?? .other
        categoryCache[catalogID] = glyph
        return glyph
    }

    func name(for category: CategoryGlyph) -> String {
        categoryNames[category.rawValue] ?? category.rawValue
    }

    func defaultOrder(_ category: CategoryGlyph) -> Int {
        categoryOrder[category.rawValue] ?? 999
    }

    private func money(_ amount: Double) -> Money {
        Money(minorUnits: Int((amount * 100).rounded()))
    }
}
