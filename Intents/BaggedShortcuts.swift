import AppIntents

/// The sentences a person actually says with their hands full. Apple requires the app's name in
/// every phrase, so each one is written to survive carrying it — and none of them names a
/// parameter, because a phrase that must be said perfectly is a phrase nobody says twice.
struct BaggedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddItemIntent(),
            phrases: [
                "Add to \(.applicationName)",
                "Add something to \(.applicationName)",
                "Add to my \(.applicationName) list",
                "Put something on my \(.applicationName) list",
            ],
            shortTitle: "Add to the list",
            systemImageName: "plus")
        AppShortcut(
            intent: WhatsLeftIntent(),
            phrases: [
                "What's left in \(.applicationName)",
                "What's left on my \(.applicationName) list",
                "What do I still need in \(.applicationName)",
            ],
            shortTitle: "What's left",
            systemImageName: "checklist.unchecked")
        AppShortcut(
            intent: ReadListIntent(),
            phrases: [
                "Read my \(.applicationName) list",
                "Read me my \(.applicationName) list",
                "What's on my \(.applicationName) list",
            ],
            shortTitle: "Read the list",
            systemImageName: "speaker.wave.2")
        AppShortcut(
            intent: CheckOffIntent(),
            phrases: [
                "Check something off in \(.applicationName)",
                "Check something off my \(.applicationName) list",
                "Cross something off my \(.applicationName) list",
            ],
            shortTitle: "Check something off",
            systemImageName: "checkmark")
        AppShortcut(
            intent: UncheckItemIntent(),
            phrases: [
                "Put something back on my \(.applicationName) list",
                "Uncheck something in \(.applicationName)",
            ],
            shortTitle: "Put something back",
            systemImageName: "arrow.uturn.backward")
        AppShortcut(
            intent: RemoveItemIntent(),
            phrases: [
                "Remove something from \(.applicationName)",
                "Take something off my \(.applicationName) list",
            ],
            shortTitle: "Remove from the list",
            systemImageName: "trash")
    }
}
