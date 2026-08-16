import SwiftUI

/// The row anatomy, FINAL (PRODUCT.md §2): tick · tinted glyph tile · name (truncates,
/// never pushes the price) · quantity UNDER the name (never a chip beside — the known
/// truncation bug) · dotted leader · mono price right. Checked: strike, desaturate, readable.
///
/// Tapping, two shapes (W5-P4 fix 1). `onOpen` nil — the default — keeps the FINAL
/// whole-row toggle: the check-off target is far larger than 44pt (INTERACTION.md §7).
/// `onOpen` non-nil splits the row: the tick still checks off one-thumbed, the body opens
/// the caller's sheet. That is how a promoted "tap to set what you paid" row keeps its
/// promise without demoting check-off to a hidden long-press.
public struct ItemRow: View {
    private let name: String

    /// The quantity EXACTLY as it should read — "×2", "1.5 lb", "½ dozen" — or nil for a
    /// row with nothing to say (W5-P7). The caller owns the vocabulary because the caller
    /// owns the units; DesignKit owns the placement, the type and the voice. An Int slot
    /// lived here until W5-P7 and could state neither a fraction nor a unit: 1.5 lb either
    /// rounded to a `×2` the database does not contain, or vanished. One way to say it —
    /// there is deliberately no Int overload for the two to drift apart.
    private let quantity: String?
    private let glyph: CategoryGlyph?
    private let emoji: String
    private let price: PriceDisplay
    private let prompt: String?
    private let isChecked: Bool
    private let onToggle: () -> Void
    private let onOpen: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        name: String,
        quantity: String? = nil,
        glyph: CategoryGlyph?,
        emoji: String = "🛒",
        price: PriceDisplay,
        prompt: String? = nil,
        isChecked: Bool = false,
        onToggle: @escaping () -> Void,
        onOpen: (() -> Void)? = nil
    ) {
        self.name = name
        self.quantity = quantity
        self.glyph = glyph
        self.emoji = emoji
        self.price = price
        self.prompt = prompt
        self.isChecked = isChecked
        self.onToggle = onToggle
        self.onOpen = onOpen
    }

    public var body: some View {
        // Spacing 0 + the body's own leading inset: the 12pt gutter belongs to a target
        // rather than to a dead zone between them. Same pixels, no unresponsive strip.
        HStack(spacing: 0) {
            tick
            rowBody
        }
        .frame(minHeight: 44)
        // One coherent VoiceOver phrase — name, quantity, price, state — not four fragments.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ItemRowSemantics.label(
            name: name, quantity: quantity, price: price,
            visiblePrompt: visiblePrompt, isChecked: isChecked))
        .accessibilityAddTraits(.isButton)
        // Check-off stays the default activation on EVERY row: the action performed 40×
        // a trip must never move because a row gained a second one.
        .accessibilityAction { onToggle() }
        // …and when there IS a second one, both are named, so neither has to be guessed.
        .accessibilityActions {
            if let onOpen {
                Button("Check off", action: onToggle)
                Button(ItemRowSemantics.openActionName(visiblePrompt: visiblePrompt), action: onOpen)
            }
        }
    }

    /// Everything right of the tick, and the row's second touch target. It carries its
    /// own ≥44pt height so the body tap area is never thinner than the row around it.
    private var rowBody: some View {
        HStack(spacing: 12) {
            if let glyph {
                GlyphTile(glyph)
            } else {
                GlyphTile(emoji: emoji)
            }
            VStack(alignment: .leading, spacing: 2) {
                itemName
                // Promoted-row anatomy (01-list, W4-C1 fix 4): when the row has no price,
                // the persimmon prompt ("tap to set what you paid") takes the quantity slot.
                // Persimmon body text is card-only (Palette rule) — rows sit on cards.
                if let visiblePrompt {
                    Text(visiblePrompt)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.persimmon.color)
                } else if let visibleQuantity {
                    Text(visibleQuantity)
                        .font(Typography.subtitle)
                        .foregroundStyle(Palette.muted.color)
                        // Wraps once at large Dynamic Type rather than truncating "½ dozen"
                        // down to "½ do…" — the whole point of this slot is that the unit
                        // survives. Two lines is the ceiling: past that it truncates, and
                        // it never contends for width with the price (layoutPriority 2).
                        .lineLimit(2)
                        .truncationMode(.tail)
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
        .padding(.leading, 12)
        .contentShape(Rectangle())
        // Whole-row toggle (W4-C1 fix 9) unless the caller claimed the body. The tick is
        // a Button, so its own taps never reach this gesture either way.
        .onTapGesture { (onOpen ?? onToggle)() }
    }

    private var visiblePrompt: String? {
        ItemRowSemantics.visiblePrompt(prompt: prompt, price: price)
    }

    private var visibleQuantity: String? {
        ItemRowSemantics.visibleQuantity(quantity: quantity, visiblePrompt: visiblePrompt)
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
}

/// ItemRow's spoken and structural rules, pure: no SwiftUI, no harness needed to test
/// them. The view holds the pixels; these three functions hold the promises.
enum ItemRowSemantics {

    /// The prompt only exists on a genuinely unpriced row — it occupies the quantity slot,
    /// so a priced row can never show both. One rule, read by the layout, the spoken
    /// label and the action name alike.
    static func visiblePrompt(prompt: String?, price: PriceDisplay) -> String? {
        guard let prompt, price == PriceDisplay.none else { return nil }
        return prompt
    }

    /// What the quantity slot actually shows: the caller's string, trimmed, unless the
    /// prompt has taken the slot (the mutual exclusion, unchanged) or there is nothing to
    /// say. A blank string is nothing to say — it must not open an empty line under the
    /// name. The view and the spoken label both read THIS, so they cannot diverge.
    static func visibleQuantity(quantity: String?, visiblePrompt: String?) -> String? {
        guard visiblePrompt == nil, let quantity else { return nil }
        let trimmed = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The row's ONE phrase (INTERACTION.md §7) — never four fragments. The quantity is
    /// spoken VERBATIM: the row shows "1.5 lb", so VoiceOver says "1.5 lb". Nothing here
    /// re-words it, because a re-wording is a second vocabulary and drifts from the pixels.
    static func label(
        name: String, quantity: String?, price: PriceDisplay,
        visiblePrompt: String?, isChecked: Bool
    ) -> String {
        var parts = [name]
        if let shown = visibleQuantity(quantity: quantity, visiblePrompt: visiblePrompt) {
            parts.append(shown)
        }
        // The price phrase is PriceLabel's, verbatim (W4-C1 fix 7) — defined once.
        parts.append(price.accessibilityPhrase)
        if let visiblePrompt { parts.append(visiblePrompt) }
        parts.append(isChecked ? "checked" : "not checked")
        return parts.joined(separator: ", ")
    }

    /// "Set price" is only true where the row is actually asking for one; elsewhere the
    /// body tap opens the item, and the action says exactly that.
    static func openActionName(visiblePrompt: String?) -> String {
        visiblePrompt == nil ? "Open details" : "Set price"
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
