import AppIntents
import Core
import DesignKit
import SwiftUI
import WidgetKit

/// design/app/28-widget.png, in DesignKit's tokens only. The tile carries exactly one money
/// figure — what the rows still to buy come to, the same basket the count names.
struct ListWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ListEntry

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) { ground }
    }

    // The lock screen paints its own vibrant material over anything behind it; the home-screen
    // tile is the app's own paper. `.clear` is the absence of a ground, not a second colour.
    @ViewBuilder private var ground: some View {
        if family == .systemSmall { Palette.paper.color } else { Color.clear }
    }

    @ViewBuilder private var content: some View {
        switch entry.state {
        case .list(let list) where list.total == 0:
            message("Nothing on the list yet.")
        case .list(let list) where list.remaining == 0:
            message("That's everything.")
        case .list(let list):
            if family == .systemSmall { smallTile(list) } else { rectangularTile(list) }
        case .noKitchen:
            message("Open Bagged to set up your kitchen.")
        case .needsApp:
            // Only the app migrates, so this tile can honestly claim nothing about the list —
            // and claims nothing. No rows, no count, no money, and no tick that could write.
            message("Open Bagged to finish updating.")
        case .unreachable:
            message("Open Bagged to see your list.")
        }
    }

    // MARK: - The two families

    private func smallTile(_ list: WidgetList) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            Text("\(list.remaining) of \(list.total) left")
                .font(Typography.subtitle)
                .foregroundStyle(Palette.muted.color)
            total(list.summary)
                .padding(.bottom, 6)
            ForEach(list.rows) { row in
                line(row)
            }
            if list.hidden > 0 {
                Text("+\(list.hidden) more")
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.muted.color)
            }
            Spacer(minLength: 0)
        }
    }

    /// The lock screen has one line for the header, so the row count carries what the small
    /// tile says twice: `5 left` beside three rows is also how many more there are.
    private func rectangularTile(_ list: WidgetList) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                title
                Spacer(minLength: 4)
                // The separator belongs to the money, not to the count: this family drops the
                // figure whenever its qualifier will not fit, and a trailing "·" pointing at
                // nothing is its own small lie about there being more to read.
                Text(showsMoney(list.summary) ? "\(list.remaining) left ·"
                                              : "\(list.remaining) left")
                    .font(Typography.subtitle)
                    .foregroundStyle(Palette.muted.color)
                total(list.summary)
            }
            ForEach(list.rows) { row in
                line(row)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Parts

    private var title: some View {
        Text("Weekly shop")
            .font(.system(.footnote, weight: .semibold))
            .foregroundStyle(Palette.ink.color)
            .lineLimit(1)
    }

    /// If the qualifier doesn't fit, the figure doesn't go. The lock screen has one header line
    /// and no room for "5 no price yet" — and `≈ $12.40` alone, for a basket that will cost
    /// thirty, is read at a glance by someone who will not open the app to check. So this family
    /// shows the count and no money. The small tile has the room, so it shows both.
    /// One rule, read by the header's separator and by the figure itself, so a "·" can never
    /// point at nothing.
    private func showsMoney(_ summary: PriceSummary) -> Bool {
        !summary.hasPricedItems || summary.breakdown == nil || family == .systemSmall
    }

    @ViewBuilder private func total(_ summary: PriceSummary) -> some View {
        if !showsMoney(summary) {
            EmptyView()
        } else if !summary.hasPricedItems {
            PriceLabel(PriceDisplay.none, size: .small)
        } else {
            VStack(alignment: .trailing, spacing: 0) {
                Text(summary.display)
                    .font(family == .systemSmall ? Typography.total : Typography.priceSmall)
                    .foregroundStyle(Palette.ink.color)
                    .lineLimit(1)
                if family == .systemSmall, let breakdown = summary.breakdown {
                    Text(breakdown)
                        .font(Typography.footnote)
                        .foregroundStyle(Palette.muted.color)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary.accessibilityPhrase)
        }
    }

    /// The tick, and the only thing on this tile that writes. `Button(intent:)` is the only
    /// interactivity a widget has — a closure here would render a tick that does nothing.
    private func line(_ row: WidgetRow) -> some View {
        Button(intent: ToggleItemIntent(itemID: row.id, isChecked: row.isChecked)) {
            HStack(spacing: 7) {
                tick(row.isChecked)
                Text(row.name)
                    .font(Typography.subtitle)
                    .foregroundStyle((row.isChecked ? Palette.muted : Palette.ink).color)
                    // Struck AND muted AND a filled tick: done is never colour alone.
                    .strikethrough(row.isChecked, color: Palette.muted.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .frame(minHeight: family == .systemSmall ? 26 : 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(row.name), \(row.isChecked ? "checked" : "not checked")")
        .accessibilityHint(row.isChecked ? "Put it back on the list" : "Check it off")
    }

    private func tick(_ isChecked: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder((isChecked ? Palette.confirmed : Palette.line).color, lineWidth: 1.5)
                .background(Circle().fill(isChecked ? Palette.confirmed.color : .clear))
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Palette.card.color)
            }
        }
        .frame(width: 13, height: 13)
        .accessibilityHidden(true)
    }

    private func message(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            title
            Text(text)
                .font(Typography.subtitle)
                .foregroundStyle(Palette.muted.color)
                .lineLimit(3)
            Spacer(minLength: 0)
        }
    }
}
