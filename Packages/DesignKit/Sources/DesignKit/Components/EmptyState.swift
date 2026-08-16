import SwiftUI

/// Empty states carry per-context copy passed in by the caller (the Tiimo lesson:
/// every empty state in its own voice, INTERACTION.md §7). Nothing here is generic.
public struct EmptyState: View {
    private let glyph: CategoryGlyph?
    private let emoji: String?
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        glyph: CategoryGlyph? = nil,
        emoji: String? = nil,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.glyph = glyph
        self.emoji = emoji
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let glyph {
                GlyphTile(glyph)
            } else if let emoji {
                GlyphTile(emoji: emoji)
            }
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Palette.muted.color)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Palette.card.color)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                        // Persimmon as a fill behind white text — the on-paper-safe form.
                        .background(Capsule().fill(Palette.persimmon.color))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }
}
