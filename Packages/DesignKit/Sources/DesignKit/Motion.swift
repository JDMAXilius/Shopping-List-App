import SwiftUI

/// A semantic animation token: the spring plus its named Reduce Motion equivalent.
/// `nil` reduced means "instant state change". SwiftUI springs are interruptible by
/// default — a second tap retargets mid-flight, never queues (INTERACTION.md §3).
public struct MotionToken: Sendable {
    public let animation: Animation
    public let reduced: Animation?

    public init(_ animation: Animation, reduced: Animation?) {
        self.animation = animation
        self.reduced = reduced
    }

    /// Pass `EnvironmentValues.accessibilityReduceMotion`; returns what to animate with.
    public func resolved(reduceMotion: Bool) -> Animation? {
        reduceMotion ? reduced : animation
    }
}

// State changes 150–250ms, screen transitions ≤350ms, one thing at a time,
// nothing moves that the user didn't cause. The inventory is INTERACTION.md §3.
public enum Motion {

    /// The Reduce Motion cross-fade path (~100ms) shared by tokens that fade instead of move.
    public static let crossFade = Animation.easeInOut(duration: 0.10)

    /// Item added: row springs into its sorted position. Reduced: fade in, no tint.
    public static let itemAdded = MotionToken(
        .spring(response: 0.25, dampingFraction: 0.85), reduced: crossFade)

    /// Check off: strikethrough draws ~180ms, row desaturates. Reduced: instant strike.
    public static let checkOff = MotionToken(
        .spring(response: 0.18, dampingFraction: 0.9), reduced: nil)

    /// Uncheck: the exact reverse — reversibility is the point. Reduced: instant.
    public static let uncheck = MotionToken(
        .spring(response: 0.18, dampingFraction: 0.9), reduced: nil)

    /// Checked row sinks to COMPLETED. Reduced: instant move.
    public static let rowSink = MotionToken(
        .spring(response: 0.25, dampingFraction: 0.9), reduced: nil)

    /// Undo: row returns along the path it left by. Reduced: instant reappear.
    public static let undoReturn = MotionToken(
        .spring(response: 0.22, dampingFraction: 0.85), reduced: nil)

    /// Total updates: digits roll ~200ms, no bounce. Reduced: instant.
    public static let totalRoll = MotionToken(
        .easeOut(duration: 0.20), reduced: nil)

    /// Aisle collapse: height animates, contents fade. Reduced: instant.
    public static let sectionCollapse = MotionToken(
        .spring(response: 0.22, dampingFraction: 0.9), reduced: nil)

    /// Sync arriving — the gentlest one in the app: a soft tint, no toast, no banner.
    /// Reduced: the tint appears without animating.
    public static let syncTint = MotionToken(
        .easeInOut(duration: 0.25), reduced: nil)

    /// Tab selection capsule slide. Reduced: cross-fade.
    public static let tabChange = MotionToken(
        .spring(response: 0.22, dampingFraction: 0.9), reduced: crossFade)

    /// Screen transitions: up to 350ms, never more. Reduced: cross-fade.
    public static let screenTransition = MotionToken(
        .spring(response: 0.32, dampingFraction: 0.9), reduced: crossFade)
}
