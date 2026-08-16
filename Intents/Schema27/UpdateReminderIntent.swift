import AppIntents
import Core
import Foundation

/// Check off, put back, rename, note. Every one of them is an op — `.check`, `.uncheck`,
/// `.edit` — written in one transaction, never a table write.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.updateReminder)
struct UpdateReminderIntent {
    var target: ItemEntity
    var title: String?
    var note: AttributedString?
    var tags: Set<String>?
    var urls: [URL]?
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var isCompleted: Bool?
    var isFlagged: Bool?
    var list: ListEntity?
    var locationTrigger: LocationTriggerEntity?

    func perform() async throws -> some ReturnsValue<ItemEntity> & ProvidesDialog {
        let id = target.listItemID
        let newName = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = note.map { String($0.characters) }
        let completed = isCompleted
        let unkept = IntentVoice.notKept(unkeptParts)
        let outcome = try await MainActor.run {
            try UpdateReminderIntent.update(id, name: newName, note: noteText, completed: completed)
        }
        return .result(value: outcome.entity,
                       dialog: IntentDialog("\(IntentVoice.sentence(outcome.said, unkept))"))
    }

    private var unkeptParts: [String] {
        var parts: [String] = []
        if dueDate != nil || recurrence != nil { parts.append("due dates") }
        if locationTrigger != nil { parts.append("place reminders") }
        if isFlagged != nil { parts.append("flags") }
        if tags?.isEmpty == false { parts.append("tags") }
        if urls?.isEmpty == false { parts.append("links") }
        return parts
    }

    @MainActor
    private static func update(_ id: ListItemID, name: String?, note: String?,
                               completed: Bool?) throws -> (entity: ItemEntity, said: String) {
        let context = try IntentContext.current()
        guard let item = try context.item(id) else { throw IntentRefusal.unknownItem }
        var writes: [FieldWrite] = []
        if let name, !name.isEmpty { writes.append(.name(name)) }
        if let note { writes.append(.note(note.isEmpty ? nil : note)) }
        var ops: [Op.Kind] = []
        if !writes.isEmpty { ops.append(.edit(id, writes)) }
        if let completed { ops.append(completed ? .check(id) : .uncheck(id)) }
        try context.append(ops)
        // A rename can fold this row into a name group another row already held, and the group's
        // canonical id is Merge's to choose — so find the row again by name when the id is gone.
        let key = Merge.normalized(name ?? item.name)
        let rows = try context.items()
        guard let row = rows.first(where: { $0.listItemID == id })
            ?? rows.first(where: { Merge.normalized($0.name) == key }) else {
            throw IntentRefusal.unknownItem
        }
        let said = IntentVoice.updated(row, checked: completed, renamed: name != nil,
                                       noted: note != nil)
        return (try ItemEntity.one(row, context), said)
    }
}
