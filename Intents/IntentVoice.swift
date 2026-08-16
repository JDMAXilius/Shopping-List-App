import Core
import DesignKit
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
    /// `shop` is said only when the speaker named one — an unnamed add lands on the shop the app
    /// is already pointed at, and announcing that would be telling someone where they are.
    static func added(_ item: ListItem, merged: Bool, shop: String? = nil) -> String {
        let at = shop.map { ", for \($0)" } ?? ""
        return merged ? "\(item.name) is now \(amount(item))\(at)."
                      : "Added \(described(item))\(at)."
    }

    static func updated(_ item: ListItem, checked: Bool?, renamed: Bool = false,
                        noted: Bool = false) -> String {
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

    static func already(_ item: ListItem, checked: Bool) -> String {
        checked ? "\(item.name) was already checked off." : "\(item.name) was already on the list."
    }

    static func removalQuestion(_ name: String) -> String {
        "Remove \(name) from the list?"
    }

    /// What's left, and what it costs. The count comes first because it is the answer that is
    /// always true; the figure comes last because it is the one that has to be qualified.
    static func whatsLeft(_ rows: [ListRow], onList: Int) -> String {
        guard !rows.isEmpty else { return nothingLeft(onList) }
        let count = rows.count == 1 ? "One thing left" : "\(rows.count) things left"
        let money = capitalizing(total(PriceSummary(rows.map(\.price))))
        return "\(count): \(names(rows.map(\.item.name))). \(money)"
    }

    /// The list in the order it will be walked. No money here: a read-back is long, and a figure
    /// arriving after twenty names is a figure nobody heard the qualifier on.
    static func readAloud(_ aisles: [AisleSection], onList: Int) -> String {
        guard !aisles.isEmpty else { return nothingLeft(onList) }
        return aisles.map { "\($0.title): \(names($0.rows.map(\.item.name)))." }
            .joined(separator: " ")
    }

    /// An empty list and a finished one are different facts, and neither is congratulated.
    private static func nothingLeft(_ onList: Int) -> String {
        onList == 0 ? "The list is empty." : "Everything's checked off."
    }

    static func capitalizing(_ clause: String) -> String {
        guard let first = clause.first else { return clause }
        return first.uppercased() + String(clause.dropFirst())
    }

    /// A clause, lower-case, for whoever is building the sentence — and the ONE rule for saying
    /// money out loud. The figure is `PriceSummary`'s, because `≈` is not a word, and it is only
    /// ever said in the same breath as what makes it approximate: "about twelve forty" for a
    /// basket that will cost thirty is a worse answer than the count of what has no price yet.
    /// So the qualifier is not optional — where there is none to say, there was nothing to say
    /// it about.
    static func total(_ summary: PriceSummary) -> String {
        guard summary.hasPricedItems else { return "nothing here has a price yet." }
        guard let qualifier = approximation(summary) else { return "\(summary.spokenTotal)." }
        return "\(summary.spokenTotal), and \(qualifier)."
    }

    /// nil exactly when the figure is exact — every estimate and every gap is named.
    private static func approximation(_ summary: PriceSummary) -> String? {
        var parts: [String] = []
        if summary.estimatedCount > 0 {
            parts.append(summary.estimatedCount == 1
                ? "one price is estimated" : "\(summary.estimatedCount) prices are estimated")
        }
        if summary.unpricedCount > 0 {
            parts.append(summary.unpricedCount == 1 ? "one thing has no price yet"
                : "\(summary.unpricedCount) things have no price yet")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " and ")
    }

    static func names(_ names: [String]) -> String {
        guard let last = names.last else { return "nothing" }
        guard names.count > 1 else { return last }
        return "\(names.dropLast().joined(separator: ", ")) and \(last)"
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
