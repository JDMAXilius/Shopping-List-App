import AppIntents
import Core
import DesignKit
import Foundation

/// A row on the list, wearing the reminder schema. The fields Bagged has no fact for stay nil:
/// a grocery row has no due date, no repeat, no alarm, and nothing records the moment one was
/// checked off — a guess there would be an invented fact.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.reminder)
struct ItemEntity {
    static let defaultQuery = ItemEntityQuery()

    let id: UUID

    var title: String
    var note: AttributedString?
    var tags: Set<String>
    var urls: [URL]
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var isCompleted: Bool
    var isFlagged: Bool?
    var creationDate: Date?
    var completionDate: Date?
    var list: ListEntity
    var locationTrigger: LocationTriggerEntity?

    /// Quantity and price as the row shows them. The price comes from DesignKit's one spoken
    /// form, so an estimate read aloud stays "about $4, estimated" and never becomes a fact.
    let detail: String?

    var displayRepresentation: DisplayRepresentation {
        guard let detail else { return DisplayRepresentation(title: "\(title)") }
        return DisplayRepresentation(title: "\(title)", subtitle: "\(detail)")
    }
}

@available(iOS 27.0, *)
extension ItemEntity {
    var listItemID: ListItemID { ListItemID(id) }

    init(_ item: ListItem, price: PriceDisplay, list: ListEntity) {
        id = item.listItemID.rawValue
        title = item.name
        note = item.note.map(AttributedString.init)
        tags = []
        urls = []
        dueDate = nil
        recurrence = nil
        isCompleted = item.checked
        isFlagged = nil
        creationDate = item.createdAt
        completionDate = nil
        self.list = list
        locationTrigger = nil
        detail = ItemEntity.detail(item, price)
    }

    @MainActor
    static func all(_ items: [ListItem], _ context: IntentContext) throws -> [ItemEntity] {
        let prices = try context.prices()
        let list = ListEntity(context.kitchen)
        return items.map { ItemEntity($0, price: prices.display($0.itemID), list: list) }
    }

    @MainActor
    static func one(_ item: ListItem, _ context: IntentContext) throws -> ItemEntity {
        ItemEntity(item, price: try context.prices().display(item.itemID),
                   list: ListEntity(context.kitchen))
    }

    private static func detail(_ item: ListItem, _ price: PriceDisplay) -> String? {
        var parts: [String] = []
        if let quantity = QuantityText.label(quantity: item.quantity, unit: item.unit) {
            parts.append(quantity)
        }
        // No price yet is said by saying nothing, exactly as the row draws `—`.
        if price != .none { parts.append(price.accessibilityPhrase) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

@available(iOS 27.0, *)
struct ItemEntityQuery: EntityStringQuery {
    func entities(for identifiers: [ItemEntity.ID]) async throws -> [ItemEntity] {
        let wanted = Set(identifiers)
        return try await MainActor.run {
            let context = try IntentContext.current()
            return try ItemEntity.all(context.items().filter { wanted.contains($0.listItemID.rawValue) },
                                      context)
        }
    }

    /// Spoken names arrive as the speaker said them, so match the way the list dedupes: on the
    /// normalized name, not the string.
    func entities(matching string: String) async throws -> [ItemEntity] {
        try await MainActor.run {
            let context = try IntentContext.current()
            let key = Merge.normalized(string)
            let matched = try context.items().filter { Merge.normalized($0.name).contains(key) }
            return try ItemEntity.all(matched, context)
        }
    }

    func suggestedEntities() async throws -> [ItemEntity] {
        try await MainActor.run {
            let context = try IntentContext.current()
            return try ItemEntity.all(context.items().filter { !$0.checked }, context)
        }
    }
}
