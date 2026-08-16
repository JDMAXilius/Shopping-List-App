import SwiftUI

/// The way back from an action that changed something quietly — a merge, a removal, an
/// ignored receipt line, a discarded scan. One definition (W6-P1) so two screens cannot
/// drift apart in padding, dwell or wording; wave 5 built this inline in ListScreen and
/// wave 6 would otherwise have copied it into receipt review.
///
/// Calm by construction: it sits in the flow, covers nothing, takes no focus, and it is
/// **absent rather than disabled** when there is nothing to undo — `phrase == nil` renders
/// nothing at all, and there is no `isEnabled` parameter for a greyed-out undo to exist in.
/// It leaves on its own after `dwell`; every other write is expected to clear it upstream.
public struct UndoBar: View {
    private let phrase: String?
    private let surface: Palette.Surface
    private let dwell: Duration
    private let onUndo: () -> Void
    private let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    /// - Parameters:
    ///   - phrase: what tapping restores, named — "bread back on the list". `nil` or blank
    ///     means there is no offer, and nothing draws. Never "Undo" alone: two different
    ///     restores would read identically.
    ///   - surface: the ground the pill SITS ON — not its fill. The fill inverts against it
    ///     (`Palette.Surface.insetFill`), because a card pill inside a card bottom bar is
    ///     invisible. Passing the surface is what makes that inversion a contract rather
    ///     than a per-screen guess.
    ///   - dwell: how long the offer stands. Defaults to the contract, `Motion.undoDwell`.
    ///   - onUndo: perform the inverse. The haptic is already fired for you.
    ///   - onDismiss: the offer expired untaken — drop it upstream so it cannot come back.
    public init(
        phrase: String?,
        on surface: Palette.Surface,
        dwell: Duration = Motion.undoDwell,
        onUndo: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.phrase = phrase
        self.surface = surface
        self.dwell = dwell
        self.onUndo = onUndo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        Group {
            if let visible = UndoBarSemantics.visiblePhrase(phrase) {
                pill(visible)
                    // Opacity only: the offer appearing is not a thing the user moved.
                    .transition(.opacity)
            }
        }
        // Owned here so no caller has to remember it. Reduce Motion resolves to nil —
        // the pill appears and goes instantly, same end state (INTERACTION.md §3).
        .animation(Motion.undoReturn.resolved(reduceMotion: reduceMotion), value: phrase)
    }

    private func pill(_ visible: String) -> some View {
        Button {
            // The haptic belongs to the affordance, not to the screen: exactly one
            // impactLight per undo, wherever an undo lives (INTERACTION.md §4).
            Haptics.play(.undo)
            onUndo()
        } label: {
            (Text(UndoBarSemantics.actionWord)
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Palette.ink.color)
             + Text(UndoBarSemantics.separator + visible)
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color))
                // One calm line at reading sizes; at accessibility sizes the phrase wraps
                // rather than truncating, because "bread back on the li…" does not name
                // what comes back — and naming it is the whole reason the phrase exists.
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(surface.insetFill.color))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(UndoBarSemantics.accessibilityLabel(visible))
        // Keyed on the phrase: a newer offer restarts the clock, and a cancelled task means
        // a newer action already owns the slot — clearing then would take away its turn.
        .task(id: visible) {
            try? await Task.sleep(for: dwell)
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }
}

/// UndoBar's promises, pure: the wording and the absence rule, testable without a harness.
enum UndoBarSemantics {

    /// The action word, once. Both the pixels and the spoken label read it from here.
    static let actionWord = "Undo"
    static let separator = " · "

    /// Absence, not disablement. A blank phrase is nothing to undo — it must never become
    /// a bare "Undo ·" with a dangling separator, and it must never become a bare "Undo"
    /// standing in for whichever of two restores happened last.
    static func visiblePhrase(_ phrase: String?) -> String? {
        guard let phrase else { return nil }
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The line the pill reads: `Undo · bread back on the list`. The view draws it in two
    /// weights, from these same two constants, so the wording cannot fork.
    static func line(_ phrase: String) -> String { actionWord + separator + phrase }

    /// Spoken as one phrase, in the same order as it is written.
    static func accessibilityLabel(_ phrase: String) -> String { "\(actionWord), \(phrase)" }
}
