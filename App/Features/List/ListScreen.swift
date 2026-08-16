import Core
import Data
import DesignKit
import SwiftUI

struct ListScreen: View {
    let store: ListStore
    @Binding var sheet: Sheet?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft = ""
    @State private var showCompleted = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if isOffline { offlineBanner }
                    listCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            bottomStack
        }
        .background(Palette.paper.color)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            Haptics.prepare()
            Sound.prepare()
        }
        .onChange(of: store.isComplete) { _, complete in
            // The arrival moment: one haptic, one tone, one line. Nothing new appears —
            // and it only arrives by checking the last row off, never by deleting it.
            guard complete, store.consumeCheckOff() else { return }
            Haptics.play(.listComplete)
            Sound.play(.complete)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Weekly shop")
                    .font(Typography.screenTitle)
                    .foregroundStyle(Palette.ink.color)
                Spacer(minLength: 8)
                shopChip
            }
            if !store.rows.isEmpty {
                Text("\(store.remainingCount) of \(store.rows.count) left")
                    .font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color)
            }
        }
        .padding(.top, 8)
    }

    private var shopChip: some View {
        Button { sheet = .shopSwitcher } label: {
            HStack(spacing: 6) {
                Text(store.activeShop?.name ?? "Pick a shop")
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.muted.color)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(capsuleSurface)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shopping at \(store.activeShop?.name ?? "no shop yet"). Change shop.")
    }

    private var isOffline: Bool { store.syncStatus == .offline || store.syncStatus == .stuck }

    private var offlineBanner: some View {
        Text("No signal — everything still works, and syncs when you're back.")
            .font(Typography.footnote)
            .foregroundStyle(Palette.muted.color)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
    }

    /// The way back from an action that changed the list quietly — a remove, or an add that
    /// merged into a row already there. It sits in the flow, covers nothing and takes no focus;
    /// when there is nothing to undo it is absent, never a disabled control.
    @ViewBuilder private var undoRow: some View {
        if let pending = store.pendingUndo {
            Button { store.undo() } label: {
                // The line names the restore, because the two cases restore different things
                // and "Undo" on its own would stand for both.
                (Text("Undo").font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink.color)
                    + Text(" · \(pending.phrase)").font(Typography.footnote)
                    .foregroundStyle(Palette.muted.color))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    // Paper on card: the pill sits inside the bottom stack, which is itself
                    // card — a card-on-card fill would be invisible.
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.paper.color))
            }
            .buttonStyle(.plain)
            .transition(.opacity)
            .accessibilityLabel("Undo, \(pending.phrase)")
            // It leaves on its own; every other write clears it in the store. Cancelled means
            // a newer action already owns the slot, and clearing would take its turn away.
            .task(id: pending.phrase) {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                store.dismissUndo()
            }
        }
    }

    // MARK: - The list

    // Plain VStack, deliberately: a shopping list is bounded, and LazyVStack's size
    // estimation loops at 100% CPU when the capture sheet's keyboard resizes this
    // ScrollView with a collapsed aisle on screen (see GATE_AUTOPILOT log, 2026-08-16).
    private var listCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.rows.isEmpty {
                emptyList
            } else {
                if store.isComplete { arrivalLine }
                unpricedSection
                ForEach(visibleAisles) { aisle in
                    aisleSection(aisle)
                }
                aisleOrderLink
                suggestedSection
                completedSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.card.color))
    }

    private var emptyList: some View {
        VStack(alignment: .leading, spacing: 16) {
            EmptyState(
                glyph: .produce,
                message: "Nothing on the list yet. Tap one below, or type what you need.")
                .frame(maxWidth: .infinity)
            suggestedSection
        }
    }

    private var arrivalLine: some View {
        Text("That's everything — \(store.rows.count) items, \(arrivalTotal)")
            .font(Typography.body)
            .foregroundStyle(Palette.ink.color)
    }

    private var arrivalTotal: String {
        let summary = PriceSummary(store.prices)
        return (summary.isApproximate ? "about " : "") + summary.total.display
    }

    @ViewBuilder private var unpricedSection: some View {
        if !store.unpriced.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                // Persimmon at caption size only holds contrast on the card, never on paper.
                Text("NO PRICE YET")
                    .font(Typography.sectionLabel)
                    .tracking(Typography.labelTracking)
                    .foregroundStyle(Palette.persimmon.color)
                // The prompt promises the tap: the body opens the price, the tick still checks off.
                ForEach(store.unpriced) { row in
                    ItemRow(name: row.item.name,
                            quantity: QuantityText.label(quantity: row.item.quantity,
                                                         unit: row.item.unit),
                            glyph: row.category,
                            price: row.price, prompt: "tap to set what you paid",
                            isChecked: row.item.checked,
                            onToggle: { store.toggle(row.item) },
                            onOpen: { sheet = .itemDetail(row.id) })
                    .contextMenu {
                        Button("Remove from list", role: .destructive) { store.remove(row.item) }
                    }
                }
            }
        }
    }

    // An aisle whose every row is promoted has nothing to draw; its money still counts,
    // in the total and in its own subtotal once it does draw.
    private var visibleAisles: [AisleSection] { store.aisles.filter { !$0.isEmpty } }

    private func aisleSection(_ aisle: AisleSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AisleHeader(title: aisle.title, prices: aisle.prices,
                        doneCount: aisle.doneCount, isCollapsed: aisle.isCollapsed)
            ForEach(aisle.rows) { row in
                ItemRow(name: row.item.name,
                        quantity: QuantityText.label(quantity: row.item.quantity,
                                                     unit: row.item.unit),
                        glyph: row.category,
                        price: row.price, isChecked: row.item.checked,
                        onToggle: { store.toggle(row.item) })
                .contextMenu {
                    Button("Set what you paid") { sheet = .itemDetail(row.id) }
                    Button("Remove from list", role: .destructive) { store.remove(row.item) }
                }
            }
        }
    }

    @ViewBuilder private var aisleOrderLink: some View {
        if visibleAisles.count > 1, let shop = store.activeShop {
            NavigationLink(value: Route.aisleOrder(shop.id)) {
                HStack {
                    sectionLabel("AISLE ORDER · \(shop.name.uppercased())")
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(Palette.muted.color)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var suggestedSection: some View {
        let chips = store.suggestedChips
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("SUGGESTED FOR YOU")
                HStack(spacing: 8) {
                    ForEach(chips) { suggestion in
                        chip(suggestion)
                    }
                }
            }
        }
    }

    private func chip(_ suggestion: ItemSuggestion) -> some View {
        Button { store.add(text: suggestion.name) } label: {
            HStack(spacing: 8) {
                GlyphShape(suggestion.category)
                    .stroke(Palette.ink.color,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 18, height: 18)
                Text(suggestion.name)
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(capsuleSurface)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(suggestion.name)")
    }

    @ViewBuilder private var completedSection: some View {
        let done = store.completed
        if !done.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Button { showCompleted.toggle() } label: {
                    HStack {
                        sectionLabel("COMPLETED (\(done.count))")
                        Spacer(minLength: 8)
                        Image(systemName: showCompleted ? "chevron.up" : "chevron.down")
                            .font(.system(.footnote, weight: .semibold))
                            .foregroundStyle(Palette.muted.color)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if showCompleted {
                    // Checked items sink, they never vanish — and they keep an aisle row's
                    // affordances exactly: pricing one must not cost an uncheck first.
                    ForEach(done) { row in
                        ItemRow(name: row.item.name,
                                quantity: QuantityText.label(quantity: row.item.quantity,
                                                             unit: row.item.unit),
                                glyph: row.category,
                                price: row.price, isChecked: true,
                                onToggle: { store.toggle(row.item) })
                        .contextMenu {
                            Button("Set what you paid") { sheet = .itemDetail(row.id) }
                            Button("Remove from list", role: .destructive) { store.remove(row.item) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom stack

    private var bottomStack: some View {
        VStack(spacing: 12) {
            // Undo lives here, not in the scroll: a merge is triggered from the input bar
            // an inch below, and an undo the user can scroll away from is not an undo.
            undoRow
            suggestionResults
            TotalBar(prices: store.prices)
            // Mic stays off until speech lands (wave 6) — an affordance must not
            // promise voice one screen before the sheet denies it.
            InputBar(text: $draft, isMicEnabled: false, onSubmit: submit, onMic: {})
        }
        .animation(Motion.undoReturn.resolved(reduceMotion: reduceMotion),
                   value: store.pendingUndo?.phrase)
        .padding(16)
        .background(Palette.card.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 8)
    }

    /// Autocomplete where the typing happens: yours, then the household's, then the catalog,
    /// each with what you last paid — plus the escape hatch that adds exactly what you typed.
    @ViewBuilder private var suggestionResults: some View {
        if !typed.isEmpty {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.suggestions(for: typed)) { suggestion in
                        suggestionRow(suggestion)
                    }
                    asTypedRow
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private func suggestionRow(_ suggestion: ItemSuggestion) -> some View {
        Button { add(suggestion.name) } label: {
            HStack(spacing: 12) {
                GlyphTile(suggestion.category)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.name)
                        .font(Typography.itemName)
                        .foregroundStyle(Palette.ink.color)
                        .lineLimit(1)
                    if let detail = suggestion.detail {
                        Text(detail)
                            .font(Typography.footnote)
                            .foregroundStyle(Palette.muted.color)
                    }
                }
                Spacer(minLength: 12)
                PriceLabel(suggestion.price)
            }
            .padding(12)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(suggestion.name), \(suggestion.price.accessibilityPhrase)")
    }

    private var asTypedRow: some View {
        Button { add(typed) } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(.body, weight: .semibold))
                Text("Add “\(typed)” as typed")
                    .font(.system(.body, weight: .semibold))
            }
            // Persimmon body text needs the card behind it to hold 4.5:1.
            .foregroundStyle(Palette.persimmon.color)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var typed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func submit() {
        guard !typed.isEmpty else { return }
        add(typed)
    }

    // The draft only clears once the write has actually landed.
    private func add(_ text: String) {
        if store.add(text: text) { draft = "" }
    }

    // MARK: - Shared bits

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.sectionLabel)
            .tracking(Typography.labelTracking)
            .foregroundStyle(Palette.muted.color)
    }

    private var capsuleSurface: some View {
        Capsule()
            .fill(Palette.card.color)
            .overlay(Capsule().strokeBorder(Palette.line.color, lineWidth: 1))
    }
}
