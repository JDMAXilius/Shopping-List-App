import AppIntents

/// The two things a person says with their hands full. Apple requires the app's name in every
/// phrase, so each one is written to survive carrying it.
struct BaggedShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        if #available(iOS 27.0, *) {
            AppShortcut(
                intent: CreateReminderIntent(),
                phrases: [
                    "Add to \(.applicationName)",
                    "Add something to \(.applicationName)",
                    "Add to my \(.applicationName) list",
                    "Put something on my \(.applicationName) list",
                ],
                shortTitle: "Add to the list",
                systemImageName: "plus")
            AppShortcut(
                intent: UpdateReminderIntent(),
                phrases: [
                    "Check something off in \(.applicationName)",
                    "Check something off my \(.applicationName) list",
                    "Cross something off my \(.applicationName) list",
                ],
                shortTitle: "Check something off",
                systemImageName: "checkmark")
        }
    }
}
