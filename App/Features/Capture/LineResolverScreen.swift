import Core
import DesignKit
import SwiftUI

/// Screen 05. One unknown line, matched once — and the sentence at the top says out loud that
/// the match is kitchen-wide and permanent, because it is.
struct LineResolverScreen: View {
    let session: CaptureSession
    let lineID: CaptureLine.ID
    @Binding var path: [CaptureRoute]

    @State private var query = ""
    @State private var newName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let line {
                    printed(line)
                    Notice("Match it once and your whole kitchen remembers it — the next receipt won't ask.",
                           on: .paper)
                    Field("Search", text: $query, placeholder: line.hint ?? line.rawText, on: .paper)
                    suggestions(line)
                    newItem(line)
                    ignore(line)
                } else {
                    EmptyState(glyph: .other, message: "That line is no longer part of this receipt.")
                }
            }
            .padding(16)
        }
        .background(Palette.paper.color)
        .navigationTitle("Match the line")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard newName.isEmpty, let line else { return }
            newName = line.hint ?? line.rawText
        }
    }

    private var line: CaptureLine? {
        session.lines.first { $0.id == lineID }
    }

    private func printed(_ line: CaptureLine) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("PRINTED ON THE RECEIPT")
            Text(line.rawText)
                .font(.system(.title2, weight: .bold))
                .foregroundStyle(Palette.ink.color)
            PriceLabel(PriceDisplay(amount: line.amount, confidence: .trusted))
        }
    }

    @ViewBuilder private func suggestions(_ line: CaptureLine) -> some View {
        let matches = session.suggestions(for: searchText(line))
        SectionLabel("CLOSEST IN THE CATALOG")
        if matches.isEmpty {
            Text("Nothing in the catalog looks like that. Search for it, or create it below.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        } else {
            ForEach(matches, id: \.itemID) { match in
                Button {
                    session.choose(itemID: match.itemID, name: match.name, for: lineID)
                    leave()
                } label: {
                    HStack(spacing: 12) {
                        GlyphTile(match.category)
                        Text(match.name)
                            .font(Typography.itemName)
                            .foregroundStyle(Palette.ink.color)
                        Spacer(minLength: 12)
                    }
                    .padding(12)
                    .frame(minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card.color))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Match this line to \(match.name)")
            }
        }
    }

    private func searchText(_ line: CaptureLine) -> String {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.isEmpty ? (line.hint ?? line.rawText) : typed
    }

    private func newItem(_ line: CaptureLine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("OR MAKE IT A NEW ITEM")
            Field("Name it", text: $newName, placeholder: line.rawText, on: .paper)
            Button {
                session.createItem(named: newName, for: lineID)
                leave()
            } label: {
                Text("Create it")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Palette.card.color)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Palette.persimmon.color))
            }
            .buttonStyle(.plain)
            .disabled(trimmedName.isEmpty)
            .opacity(trimmedName.isEmpty ? 0.4 : 1)
        }
    }

    private func ignore(_ line: CaptureLine) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                session.ignore(lineID)
                leave()
            } label: {
                Text("Ignore this line forever")
                    .font(Typography.body)
                    .foregroundStyle(Palette.muted.color)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            Text("Forever means forever: this line, and every receipt that prints it again, is skipped without asking.")
                .font(Typography.footnote)
                .foregroundStyle(Palette.muted.color)
        }
    }

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // The decision is held in the session until the review screen's save; leaving writes nothing.
    private func leave() {
        if path.last == .resolver(lineID) { path.removeLast() }
    }
}
