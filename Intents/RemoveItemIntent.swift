import AppIntents
import Core
import Foundation

/// Take something off the list. Touch always leaves an undo slot (`ListStore.remove`); a voice
/// deletion has no row to look at and no slot to tap, so it is strictly more dangerous than the
/// same action by hand. The ask before the write is what closes that — it is the way back.
struct RemoveItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove from the list"
    static let description = IntentDescription(
        "Takes something off the list, after checking that's what you meant.")

    @Parameter(title: "Item", requestValueDialog: "What should come off the list?")
    var item: ListItemEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Remove \(\.$item) from the list")
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = item.name
        try await requestConfirmation(
            result: .result(dialog: IntentDialog("\(IntentVoice.removalQuestion(name))")))
        let id = item.listItemID
        let said = try await MainActor.run { try RemoveItemIntent.remove(id) }
        return .result(dialog: IntentDialog("\(said)"))
    }

    /// One op, not N: a delete already sweeps the normalized-name GROUP the row held
    /// (ARCHITECTURE §5), and that reasoning stays in Merge.
    @MainActor
    static func remove(_ id: ListItemID) throws -> String {
        let context = try IntentContext.current()
        guard let item = try context.item(id) else { throw IntentRefusal.unknownItem }
        try context.append([.delete(id)])
        return IntentVoice.removed([item.name])
    }
}
