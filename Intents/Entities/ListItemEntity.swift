import AppIntents
import Core
import DesignKit
import Foundation

/// A row on the list, as Siri and Shortcuts hand it around. `detail` is what makes it worth
/// hearing — how much, and the price in DesignKit's ONE spoken form, so an estimate stays an
/// estimate wherever it is read.
struct ListItemEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item")
    static let defaultQuery = ListItemEntityQuery()

    let id: UUID
    let name: String
    let detail: String?
    let isChecked: Bool

    var listItemID: ListItemID { ListItemID(id) }

    var displayRepresentation: DisplayRepresentation {
        guard let detail else { return DisplayRepresentation(title: "\(name)") }
        return DisplayRepresentation(title: "\(name)", subtitle: "\(detail)")
    }

    init(_ row: ListRow) {
        id = row.item.listItemID.rawValue
        name = row.item.name
        isChecked = row.item.checked
        detail = ListItemEntity.detail(row)
    }

    /// No price yet is said by saying nothing, exactly as the row draws `—`.
    ///
    /// "×4 at $3.50", never "×4 · $3.50" (W8-P5 ruling 5): the separator read as four milks
    /// costing three fifty. The price here is the price of ONE — the row's own figure,
    /// unforked — and "at" is the word that says so in both English and arithmetic.
    private static func detail(_ row: ListRow) -> String? {
        // The bare multiplier, not the row's unit label: "4 L at $3.50" reads as four
        // litres costing $3.50, which is the very misreading ruling 5 exists to kill.
        // "at" needs a count on its left; the unit vocabulary stays on the list row.
        let count = row.item.quantity == 1 ? nil : "×\(QuantityText.number(row.item.quantity))"
        let price = row.price == .none ? nil : row.price.accessibilityPhrase
        guard let count else { return price }
        guard let price else { return count }
        return "\(count) at \(price)"
    }
}

struct ListItemEntityQuery: EntityStringQuery {
    func entities(for identifiers: [ListItemEntity.ID]) async throws -> [ListItemEntity] {
        let wanted = Set(identifiers)
        return try await MainActor.run {
            try IntentContext.current().rows()
                .filter { wanted.contains($0.item.listItemID.rawValue) }
                .map(ListItemEntity.init)
        }
    }

    /// A spoken name arrives as the speaker said it, and is matched against what is actually on
    /// the list. Several answers are returned rather than narrowed to one: the framework then
    /// asks which, which is the entire reason this is a query and not a string parameter.
    func entities(matching string: String) async throws -> [ListItemEntity] {
        try await MainActor.run {
            let rows = try IntentContext.current().rows()
            return ListItemEntityQuery.matching(string, in: rows).map(ListItemEntity.init)
        }
    }

    func suggestedEntities() async throws -> [ListItemEntity] {
        try await MainActor.run {
            try IntentContext.current().rows().filter { !$0.item.checked }.map(ListItemEntity.init)
        }
    }

    /// Matched the way the list itself dedupes — on the normalized name (`Merge`), never the
    /// string. An exact name is an answer, not an ambiguity: with "milk" and "oat milk" both on
    /// the list, "milk" named a row. Only when nothing is named exactly is everything that
    /// contains what was said offered for the ask.
    static func matching(_ text: String, in rows: [ListRow]) -> [ListRow] {
        let key = Merge.normalized(text)
        guard !key.isEmpty else { return [] }
        let exact = rows.filter { Merge.normalized($0.item.name) == key }
        guard exact.isEmpty else { return exact }
        let contained = rows.filter { Merge.normalized($0.item.name).contains(key) }
        guard contained.isEmpty else { return contained }
        // Last: what was SAID contains a row's name — people say "the milk". On WHOLE WORDS
        // only: an unanchored substring made "check off steak" find Tea, and check it off, with
        // no ask and no confirmation, because "tea" is inside "steak" and one match is not an
        // ambiguity. "champagne" found Ham; "tin foil" found Oil.
        let said = key.split(separator: " ").map(String.init)
        return rows.filter { row in
            let name = Merge.normalized(row.item.name).split(separator: " ").map(String.init)
            guard !name.isEmpty else { return false }
            return said.indices.contains { start in
                start + name.count <= said.count
                    && Array(said[start..<(start + name.count)]) == name
            }
        }
    }
}
