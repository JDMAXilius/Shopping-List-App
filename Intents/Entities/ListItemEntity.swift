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
    private static func detail(_ row: ListRow) -> String? {
        var parts: [String] = []
        if let quantity = QuantityText.label(quantity: row.item.quantity, unit: row.item.unit) {
            parts.append(quantity)
        }
        if row.price != .none { parts.append(row.price.accessibilityPhrase) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
        // Last: what was SAID contains a row's name. People say "the milk"; `Merge.normalized`
        // folds whitespace and case and nothing else, so without this the row is unfindable.
        return rows.filter { key.contains(Merge.normalized($0.item.name)) }
    }
}
