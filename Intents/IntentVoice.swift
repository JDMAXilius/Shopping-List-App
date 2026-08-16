import Core
import Foundation

/// Every no this cluster can say, as a plain sentence. Nothing is written on any of these paths.
enum IntentRefusal: Error, CustomLocalizedStringResourceConvertible {
    case notReady
    case noList
    case nothingToAdd
    case unknownItem
    case oneListPerKitchen
    case aislesAreFixed
    case couldNotWrite

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady:
            return "Open Bagged once to finish updating, then try again."
        case .noList:
            return "There's no list on this phone yet. Open Bagged once."
        case .nothingToAdd:
            return "I didn't catch what to add."
        case .unknownItem:
            return "That's not on the list."
        case .oneListPerKitchen:
            return "Bagged keeps one list per kitchen, so it can't make another."
        case .aislesAreFixed:
            return "Bagged files things into its own aisles, so it can't make a new one."
        case .couldNotWrite:
            return "That didn't get written down. Try again."
        }
    }
}

/// What the cluster says out loud. Plain, brief, no exclamation, no praise — and what a reminder
/// carried that Bagged has nowhere to keep is said, never quietly dropped.
enum IntentVoice {
    static func added(_ item: ListItem, merged: Bool) -> String {
        merged ? "\(item.name) is now \(amount(item))." : "Added \(described(item))."
    }

    static func updated(_ item: ListItem, checked: Bool?, renamed: Bool, noted: Bool) -> String {
        if checked == true { return "Checked off \(item.name)." }
        if checked == false { return "\(item.name) is back on the list." }
        if renamed { return "That's \(item.name) now." }
        if noted { return "Noted on \(item.name)." }
        return "Nothing to change on \(item.name)."
    }

    static func removed(_ names: [String]) -> String {
        switch names.count {
        case 0: return "Nothing to remove."
        case 1: return "Removed \(names[0])."
        case 2: return "Removed \(names[0]) and \(names[1])."
        default: return "Removed \(names.count) things."
        }
    }

    /// nil when the reminder asked for nothing Bagged has to refuse.
    static func notKept(_ parts: [String]) -> String? {
        guard let last = parts.last else { return nil }
        guard parts.count > 1 else { return "Bagged doesn't keep \(last)." }
        return "Bagged doesn't keep \(parts.dropLast().joined(separator: ", ")) or \(last)."
    }

    static func sentence(_ parts: String?...) -> String {
        parts.compactMap { $0 }.joined(separator: " ")
    }

    private static func described(_ item: ListItem) -> String {
        guard let label = QuantityText.label(quantity: item.quantity, unit: item.unit) else {
            return item.name
        }
        return item.unit == nil ? "\(item.name) \(label)" : "\(label) \(item.name)"
    }

    private static func amount(_ item: ListItem) -> String {
        QuantityText.label(quantity: item.quantity, unit: item.unit)
            ?? "×\(QuantityText.number(item.quantity))"
    }
}
