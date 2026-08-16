import AppIntents
import Core
import Foundation

/// "Read me my Bagged list." In aisle order — the order the shop will be walked in, which is the
/// order the names have to arrive in to be any use standing in it. The ordering is the app's
/// (`IntentContext.walk`), never a second one.
struct ReadListIntent: AppIntent {
    static let title: LocalizedStringResource = "Read the list"
    static let description = IntentDescription("Reads out what's still to buy, aisle by aisle.")

    static var parameterSummary: some ParameterSummary { Summary("Read the list") }

    init() {}

    func perform() async throws -> some ReturnsValue<[ListItemEntity]> & ProvidesDialog {
        let outcome = try await MainActor.run { try ReadListIntent.read() }
        return .result(value: outcome.entities, dialog: IntentDialog("\(outcome.said)"))
    }

    @MainActor
    static func read() throws -> (entities: [ListItemEntity], said: String) {
        let context = try IntentContext.current()
        let aisles = try context.walk()
        let onList = try context.rows().count
        return (aisles.flatMap(\.rows).map(ListItemEntity.init),
                IntentVoice.readAloud(aisles, onList: onList))
    }
}
