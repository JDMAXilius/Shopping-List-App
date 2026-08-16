import Catalog
import Core
import DesignKit
import Foundation

// The bundled catalog as the list uses it. Catalog rows are Int64-keyed and Core's ItemID is a
// UUID, so the (reversible, deterministic) mapping between them lives here.
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

    init(database: CatalogDatabase? = try? CatalogDatabase.bundled(), regionKey: String = "us-national") {
        self.database = database
        self.regionKey = regionKey
        guard let database else {
            multiplier = 1
            return
        }
        multiplier = ((try? database.priceRegion(regionKey)) ?? nil)?.multiplier ?? 1
        for row in (try? database.rows("SELECT id, name, default_order FROM category")) ?? [] {
            guard let id = ListCatalog.text(row.first) else { continue }
            categoryNames[id] = ListCatalog.text(row[1]) ?? id
            categoryOrder[id] = Int(ListCatalog.integer(row[2]) ?? 999)
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
            return Match(itemID: ListCatalog.itemID(hit.id), name: hit.canonicalName,
                         unit: hit.defaultUnit, category: glyph)
        }
    }

    // The seeded estimate every added item lands with — nil when the item has no seed.
    func estimate(for itemID: ItemID) -> Money? {
        guard let database, let catalogID = ListCatalog.catalogID(itemID) else { return nil }
        if let cached = estimateCache[catalogID] { return cached }
        let amount = (try? PriceEstimate.estimate(
            db: database, itemID: catalogID, regionKey: regionKey)).flatMap { $0 }
        let result = amount.map { money($0) }
        estimateCache[catalogID] = .some(result)
        return result
    }

    func category(for itemID: ItemID?) -> CategoryGlyph {
        guard let itemID, let database, let catalogID = ListCatalog.catalogID(itemID) else { return .other }
        if let cached = categoryCache[catalogID] { return cached }
        let row = ((try? database.rows(
            "SELECT category_id FROM item WHERE id = ?", bind: [.integer(catalogID)])) ?? []).first
        let glyph = ListCatalog.text(row?.first).flatMap(CategoryGlyph.init(rawValue:)) ?? .other
        categoryCache[catalogID] = glyph
        return glyph
    }

    // SQLiteValue's accessors are internal to Catalog; its cases are public, so we read them here.
    private static func text(_ value: SQLiteValue?) -> String? {
        if case .text(let text)? = value { return text }
        return nil
    }

    private static func integer(_ value: SQLiteValue?) -> Int64? {
        if case .integer(let number)? = value { return number }
        return nil
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

    // MARK: - Catalog id ↔ ItemID

    private static let prefix: [UInt8] = [0xBA, 0x60, 0xCA, 0x7A, 0x10, 0x60, 0x00, 0x01]

    static func itemID(_ catalogID: Int64) -> ItemID {
        var b = prefix
        withUnsafeBytes(of: catalogID.bigEndian) { b.append(contentsOf: $0) }
        return ItemID(UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
                                  b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15])))
    }

    static func catalogID(_ itemID: ItemID) -> Int64? {
        let u = itemID.rawValue.uuid
        guard [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7] == prefix else { return nil }
        return [u.8, u.9, u.10, u.11, u.12, u.13, u.14, u.15]
            .reduce(Int64(0)) { ($0 << 8) | Int64($1) }
    }
}
