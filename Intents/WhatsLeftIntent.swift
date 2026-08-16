import AppIntents
import Core
import Foundation

/// "What's left on my Bagged list?" — the third of PRODUCT.md:173 that the assistant schema
/// could not answer at all. It reads; it writes nothing.
struct WhatsLeftIntent: AppIntent {
    static let title: LocalizedStringResource = "What's left"
    static let description = IntentDescription("Says what's still to buy, and what it comes to.")

    static var parameterSummary: some ParameterSummary { Summary("What's left on the list") }

    init() {}

    func perform() async throws -> some ReturnsValue<[ListItemEntity]> & ProvidesDialog {
        let outcome = try await MainActor.run { try WhatsLeftIntent.left() }
        return .result(value: outcome.entities, dialog: IntentDialog("\(outcome.said)"))
    }

    @MainActor
    static func left() throws -> (entities: [ListItemEntity], said: String) {
        let context = try IntentContext.current()
        let rows = try context.rows()
        let remaining = rows.filter { !$0.item.checked }
        return (remaining.map(ListItemEntity.init),
                IntentVoice.whatsLeft(remaining, onList: rows.count))
    }
}
