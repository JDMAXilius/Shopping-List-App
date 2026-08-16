import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Every event that earns a haptic. Scroll, navigation and sheets are deliberately
/// absent — haptics mark state changes, never movement (INTERACTION.md §4).
public enum HapticEvent: Sendable {
    case checkOff      // impactLight — fires 20–40×/trip, must stay light
    case uncheck       // selection — deliberately smaller than checking
    case add           // selection
    case delete        // impactMedium — weightier because destructive
    case undo          // impactLight
    case dragPickup    // impactLight
    case dragDrop      // selection
    case listComplete  // notificationSuccess — the one moment that earns it
    case error         // notificationError — rare by design
}

@MainActor
public enum Haptics {

    /// The single settings toggle (INTERACTION.md §4). System haptic settings are
    /// respected automatically by UIKit; this is ours on top.
    public static var isEnabled = true

    // Structural, matching Sound: a widget or an intent process has no haptic engine, so a
    // check-off from the lock screen is deliberately silent rather than silent by accident.
    private static var isAppExtension: Bool { Bundle.main.bundlePath.hasSuffix(".appex") }

    #if canImport(UIKit)
    // One generator per type, kept warm across a trip.
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()
    #endif

    /// Call before a burst of interaction (e.g. the list appearing) to remove first-tap latency.
    public static func prepare() {
        #if canImport(UIKit)
        impactLight.prepare()
        selection.prepare()
        #endif
    }

    /// One haptic per user action, never stacked; nothing the user didn't cause —
    /// a remote sync must never buzz someone's pocket.
    public static func play(_ event: HapticEvent) {
        guard isEnabled, !isAppExtension else { return }
        #if canImport(UIKit)
        switch event {
        case .checkOff, .undo, .dragPickup:
            impactLight.impactOccurred()
            impactLight.prepare()
        case .uncheck, .add, .dragDrop:
            selection.selectionChanged()
            selection.prepare()
        case .delete:
            impactMedium.impactOccurred()
            impactMedium.prepare()
        case .listComplete:
            notification.notificationOccurred(.success)
        case .error:
            notification.notificationOccurred(.error)
        }
        #endif
    }
}
