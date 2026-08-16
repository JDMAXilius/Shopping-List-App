import AppIntents
import Core
import Foundation

/// Take things off the list. One `.delete` op per row and no more reasoning than that: Merge
/// already widens a delete to the normalized-name GROUP that row held (ARCHITECTURE §5).
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.deleteReminders)
struct DeleteRemindersIntent: DeleteIntent {
    var entities: [ItemEntity]

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ids = entities.map(\.listItemID)
        let said = try await MainActor.run { try DeleteRemindersIntent.remove(ids) }
        return .result(dialog: IntentDialog("\(said)"))
    }

    @MainActor
    private static func remove(_ ids: [ListItemID]) throws -> String {
        let context = try IntentContext.current()
        let items = try context.items()
        let doomed = ids.compactMap { id in items.first { $0.listItemID == id } }
        try context.append(doomed.map { Op.Kind.delete($0.listItemID) })
        return IntentVoice.removed(doomed.map(\.name))
    }
}
