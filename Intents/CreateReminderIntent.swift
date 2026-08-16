import AppIntents
import Catalog
import Core
import Foundation

/// "add milk", "add two pounds of chicken". The add rule is the app's — `ListDerivation.addPlan`
/// with `QuantityParser` — so a spoken add and a typed one can never mean different things.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.createReminder)
struct CreateReminderIntent {
    var title: String
    var list: ListEntity?
    var note: AttributedString?
    var isFlagged: Bool?
    var images: [IntentFile]
    var tags: Set<String>
    var urls: [URL]
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var locationTrigger: LocationTriggerEntity?
    var section: SectionEntity?

    func perform() async throws -> some ReturnsValue<ItemEntity> & ProvidesDialog {
        let text = title
        let noteText = note.map { String($0.characters) }
        let unkept = IntentVoice.notKept(unkeptParts)
        let outcome = try await MainActor.run { try CreateReminderIntent.add(text, note: noteText) }
        return .result(value: outcome.entity,
                       dialog: IntentDialog("\(IntentVoice.sentence(outcome.said, unkept))"))
    }

    /// What the reminder carried that a shopping list has nowhere to put. Saying nothing about
    /// these would be the app quietly dropping something the speaker asked for.
    private var unkeptParts: [String] {
        var parts: [String] = []
        if dueDate != nil || recurrence != nil { parts.append("due dates") }
        if locationTrigger != nil { parts.append("place reminders") }
        if isFlagged == true { parts.append("flags") }
        if !tags.isEmpty { parts.append("tags") }
        if !urls.isEmpty { parts.append("links") }
        if !images.isEmpty { parts.append("photos") }
        if section != nil { parts.append("a chosen aisle") }
        return parts
    }

    @MainActor
    private static func add(_ text: String,
                            note: String?) throws -> (entity: ItemEntity, said: String) {
        let context = try IntentContext.current()
        let parsed = QuantityParser.parse(text)
        let name = parsed.rest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw IntentRefusal.nothingToAdd }
        let items = try context.items()
        let key = Merge.normalized(name)
        let existing = items.first { Merge.normalized($0.name) == key }
        let plan = ListDerivation.addPlan(name: name, quantity: parsed.quantity, unit: parsed.unit,
                                          items: items, match: context.catalog.resolve(name),
                                          shopID: context.activeShopID)
        var ops = plan.ops
        if let note, !note.isEmpty, let id = noted(ops, existing: existing) {
            ops.append(.edit(id, [.note(note)]))
        }
        try context.append(ops)
        guard let row = try context.items().first(where: { Merge.normalized($0.name) == key }) else {
            throw IntentRefusal.couldNotWrite
        }
        return (try ItemEntity.one(row, context), IntentVoice.added(row, merged: existing != nil))
    }

    /// Which row the spoken note belongs to: the one already on the list, or the one this add
    /// is about to make.
    private static func noted(_ ops: [Op.Kind], existing: ListItem?) -> ListItemID? {
        if let existing { return existing.listItemID }
        guard let first = ops.first, case .add(let item) = first else { return nil }
        return item.listItemID
    }
}
