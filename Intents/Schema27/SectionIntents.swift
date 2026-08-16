import AppIntents
import Core
import Foundation

/// Sections are aisles, and Bagged's aisles come with the catalog — a person reorders them, they
/// don't invent them. So this creates nothing: it names the aisle that already exists, or says no.
@available(iOS 27.0, *)
@AppIntent(schema: .reminders.createSection)
struct CreateSectionIntent {
    var name: String
    var list: ListEntity

    func perform() async throws -> some ReturnsValue<SectionEntity> & ProvidesDialog {
        let asked = name
        let existing = try await MainActor.run { try SectionEntity.named(asked) }
        guard let existing else { throw IntentRefusal.aislesAreFixed }
        return .result(value: existing,
                       dialog: IntentDialog("\(existing.name) is already an aisle in Bagged."))
    }
}
