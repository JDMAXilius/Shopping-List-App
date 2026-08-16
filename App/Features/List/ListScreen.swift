import Core
import Data
import DesignKit
import SwiftUI

struct ListScreen: View {
    let store: ListStore
    @Binding var sheet: Sheet?

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
            // The arrival moment: one haptic, one tone, one line. Nothing new appears.
            guard complete else { return }
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

    // MARK: - The list

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.rows.isEmpty {
                emptyList
            } else {
                if store.isComplete { arrivalLine }
                unpricedSection
                ForEach(store.aisles) { aisle in
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
                // The prompt promises the tap: here it opens the price, not the tick.
                ForEach(store.unpriced) { row in
                    ItemRow(name: row.item.name, quantity: quantity(row), glyph: row.category,
                            price: row.price, prompt: "tap to set what you paid",
                            isChecked: row.item.checked,
                            onToggle: { sheet = .itemDetail(row.id) })
                    .contextMenu {
                        Button("Check off") { store.toggle(row.item) }
                        Button("Remove from list", role: .destructive) { store.remove(row.item) }
                    }
                }
            }
        }
    }

    private func aisleSection(_ aisle: AisleSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AisleHeader(title: aisle.title, prices: aisle.prices,
                        doneCount: aisle.doneCount, isCollapsed: aisle.isCollapsed)
            ForEach(aisle.rows) { row in
                ItemRow(name: row.item.name, quantity: quantity(row), glyph: row.category,
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
        if store.aisles.count > 1, let shop = store.activeShop {
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
                    // Checked items sink, they never vanish.
                    ForEach(done) { row in
                        ItemRow(name: row.item.name, quantity: quantity(row), glyph: row.category,
                                price: row.price, isChecked: true,
                                onToggle: { store.toggle(row.item) })
                    }
                }
            }
        }
    }

    // MARK: - Bottom stack

    private var bottomStack: some View {
        VStack(spacing: 12) {
            TotalBar(prices: store.prices)
            InputBar(text: $draft, onSubmit: submit, onMic: { sheet = .addItem })
        }
        .padding(16)
        .background(Palette.card.color)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 8)
    }

    private func submit() {
        store.add(text: draft)
        draft = ""
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

    private func quantity(_ row: ListRow) -> Int {
        max(1, Int(row.item.quantity.rounded()))
    }
}
