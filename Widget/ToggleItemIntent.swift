import AppIntents
import Core
import Data
import Foundation
import WidgetKit

/// The tick on the tile. It writes the same op the app writes, through the same `Repository`,
/// with this device's own identity and clock — the op log is the only write path (ARCHITECTURE §5).
struct ToggleItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Check off an item"
    /// Not a Shortcuts action: the app's intents cluster owns that vocabulary, and a
    /// widget-internal tick offered in the Shortcuts app would be a second way to do one thing.
    static let isDiscoverable = false

    @Parameter(title: "Item") var itemID: String
    /// The row's state AS THE TILE RENDERED IT. The op written is its inverse, never a toggle
    /// read back from the file: a finger aiming at an unchecked row means "I got this", and on
    /// a tile a second behind the phone a re-read would undo somebody else's check-off instead.
    @Parameter(title: "Checked") var isChecked: Bool

    init() {}

    init(itemID: ListItemID, isChecked: Bool) {
        self.itemID = itemID.rawValue.uuidString
        self.isChecked = isChecked
    }

    func perform() async throws -> some IntentResult {
        try ToggleItemIntent.write(itemID: itemID, isChecked: isChecked, access: WidgetStore.shared())
        // The tick has to be visible now, not at the next timeline pass.
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    /// The write, apart from WidgetKit so it can be tested against a real database.
    /// A schema this build disagrees with REFUSES: writing an op through code that disagrees
    /// with the database's shape is exactly the data loss the migrate rule prevents.
    static func write(itemID: String, isChecked: Bool, access: WidgetStore.Access) throws {
        switch access {
        case .needsApp: throw ToggleFailure.needsApp
        case .unreachable, .noKitchen: throw ToggleFailure.unreachable
        case .ready(let repository, let kitchenID):
            guard let uuid = UUID(uuidString: itemID) else { throw ToggleFailure.unknownItem }
            let id = ListItemID(uuid)
            // A row that is gone would take a ghost op — valid, syncable, and about nothing.
            guard let items = try? repository.items(),
                  items.contains(where: { $0.listItemID == id }) else {
                throw ToggleFailure.unknownItem
            }
            do {
                try repository.append(isChecked ? .uncheck(id) : .check(id), kitchenID: kitchenID)
            } catch {
                // GRDB serialises writers and AppDatabase waits out a busy file for 5s, so
                // reaching here means the write genuinely did not land. Say so: a tick that
                // silently fails is worse than one that visibly does nothing.
                throw ToggleFailure.writeFailed
            }
        }
    }
}

enum ToggleFailure: Error, CustomLocalizedStringResourceConvertible {
    case needsApp
    case unreachable
    case unknownItem
    case writeFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .needsApp: return "Open Bagged to finish updating."
        case .unreachable: return "Open Bagged to see your list."
        case .unknownItem: return "That's not on the list any more."
        case .writeFailed: return "Couldn't save that just now — try again."
        }
    }
}
