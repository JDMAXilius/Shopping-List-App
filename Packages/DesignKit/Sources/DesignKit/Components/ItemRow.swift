import SwiftUI

/// The row anatomy, FINAL (PRODUCT.md §2): tick · tinted glyph tile · name (truncates,
/// never pushes the price) · `×N` UNDER the name (never a chip beside — the known
/// truncation bug) · dotted leader · mono price right. Checked: strike, desaturate, readable.
/// The whole row toggles (INTERACTION.md: the check-off target is far larger than 44pt).
public struct ItemRow: View {
    private let name: String
    private let quantity: Int
    private let glyph: CategoryGlyph?
    private let emoji: String
    private let price: PriceDisplay
    private let prompt: String?
    private let isChecked: Bool
    private let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        name: String,
        quantity: Int = 1,
        glyph: CategoryGlyph?,
        emoji: String = "🛒",
        price: PriceDisplay,
        prompt: String? = nil,
        isChecked: Bool = false,
        onToggle: @escaping () -> Void
    ) {
        self.name = name
        self.quantity = quantity
        self.glyph = glyph
        self.emoji = emoji
        self.price = price
        self.prompt = prompt
        self.isChecked = isChecked
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: 12) {
            tick
            if let glyph {
                GlyphTile(glyph)
            } else {
                GlyphTile(emoji: emoji)
            }
            VStack(alignment: .leading, spacing: 2) {
                itemName
                // Promoted-row anatomy (01-list, W4-C1 fix 4): when the row has no price,
                // the persimmon prompt ("tap to set what you paid") takes the ×N slot.
                // Persimmon body text is card-only (Palette rule) — rows sit on cards.
                if let prompt, price == .none {
                    Text(prompt)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.persimmon.color)
                } else if quantity > 1 {
                    Text("×\(quantity)")
                        .font(Typography.subtitle)
                        .foregroundStyle(Palette.muted.color)
                }
            }
            .layoutPriority(1)
            LeaderDots()
                .stroke(Palette.line.color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.1, 5]))
                .frame(height: 2)
                .frame(minWidth: 12, maxWidth: .infinity)
            PriceLabel(price)
                .fixedSize()
                .layoutPriority(2)
                // Desaturate only (W4-C1 fix 6): strike + muted already say "done";
                // the 0.75 opacity bought nothing but a contrast question.
                .saturation(isChecked ? 0 : 1)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        // Whole-row toggle (W4-C1 fix 9): the gesture rides the contentShape above.
        .onTapGesture { onToggle() }
        // One coherent VoiceOver phrase — name, quantity, price, state — not four fragments.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onToggle() }
    }

    /// Progressive strikethrough (W4-C1 fix 5): a rule draws 0→text-width under
    /// Motion.checkOff. Reduce Motion gets the boolean attribute strike — same end
    /// state, no drawing.
    private var itemName: some View {
        Text(name)
            .font(Typography.itemName)
            .foregroundStyle((isChecked ? Palette.muted : Palette.ink).color)
            .strikethrough(isChecked && reduceMotion, color: Palette.muted.color)
            .lineLimit(1)
            .truncationMode(.tail)
            .overlay(alignment: .leading) {
                if !reduceMotion {
                    Rectangle()
                        .fill(Palette.muted.color)
                        .frame(height: 1.5)
                        .scaleEffect(x: isChecked ? 1 : 0, anchor: .leading)
                        .animation(
                            Motion.checkOff.resolved(reduceMotion: reduceMotion),
                            value: isChecked)
                }
            }
    }

    private var tick: some View {
        Button(action: onToggle) {
            ZStack {
                Circle()
                    .strokeBorder(
                        (isChecked ? Palette.confirmed : Palette.line).color, lineWidth: 1.8)
                    .background(Circle().fill(isChecked ? Palette.confirmed.color : .clear))
                    .frame(width: 26, height: 26)
                if isChecked {
                    // Green = done, enforced here — never available as decoration.
                    Image(systemName: "checkmark")
                        .font(.system(.footnote, weight: .bold))
                        .foregroundStyle(Palette.card.color)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private var accessibilityText: String {
        var parts = [name]
        if quantity > 1 { parts.append("quantity \(quantity)") }
        // The price phrase is PriceLabel's, verbatim (W4-C1 fix 7) — defined once.
        parts.append(price.accessibilityPhrase)
        if let prompt, price == .none { parts.append(prompt) }
        parts.append(isChecked ? "checked" : "not checked")
        return parts.joined(separator: ", ")
    }
}

/// The dotted leader between name and price (A·Ledger).
struct LeaderDots: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}
