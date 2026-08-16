import AppIntents
import Core
import Foundation

/// The schema can ask for a new list; Bagged has one per kitchen and no screen that could show a
/// second. So this creates nothing, ever: it hands back the list that exists when that is what
/// was asked for, and says no plainly when it isn't.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.createList)
struct CreateListIntent {
    var type: ListType
    var name: String

    func perform() async throws -> some ReturnsValue<ListEntity> & ProvidesDialog {
        let asked = name
        let list = try await MainActor.run { ListEntity(try IntentContext.current().kitchen) }
        guard Merge.normalized(list.name) == Merge.normalized(asked) else {
            throw IntentRefusal.oneListPerKitchen
        }
        return .result(value: list,
                       dialog: IntentDialog("\(list.name) is already the list here."))
    }
}
