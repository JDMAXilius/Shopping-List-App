import AppIntents
import Core
import Foundation

/// "Check off milk." Which row that is, is settled before `perform` runs: the spoken name
/// resolves through `ListItemEntityQuery` against what is actually on the list, and two rows that
/// both answer to what was said make the framework ask instead of picking one.
struct CheckOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Check something off"
    static let description = IntentDescription("Checks something off the list.")

    @Parameter(title: "Item", requestValueDialog: "What should I check off?")
    var item: ListItemEntity

    static var parameterSummary: some ParameterSummary { Summary("Check off \(\.$item)") }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = item.listItemID
        let said = try await MainActor.run { try ItemCheck.write(id, checked: true) }
        return .result(dialog: IntentDialog("\(said)"))
    }
}

/// The way back, for the thing you put in the trolley and then put down again.
struct UncheckItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Put something back on the list"
    static let description = IntentDescription("Puts something you checked off back on the list.")

    @Parameter(title: "Item", requestValueDialog: "What should go back on the list?")
    var item: ListItemEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Put \(\.$item) back on the list")
    }

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let id = item.listItemID
        let said = try await MainActor.run { try ItemCheck.write(id, checked: false) }
        return .result(dialog: IntentDialog("\(said)"))
    }
}

enum ItemCheck {
    /// The op the app writes, through the op log, or none at all: a row already in the state
    /// asked for is said, never written twice — a second `check` is an op about nothing that
    /// every other device would still have to merge.
    @MainActor
    static func write(_ id: ListItemID, checked: Bool) throws -> String {
        let context = try IntentContext.current()
        guard let item = try context.item(id) else { throw IntentRefusal.unknownItem }
        guard item.checked != checked else { return IntentVoice.already(item, checked: checked) }
        try context.append([checked ? .check(id) : .uncheck(id)])
        return IntentVoice.updated(item, checked: checked)
    }
}
