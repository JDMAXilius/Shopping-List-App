import SwiftUI

/// The three destinations. Raw values are the visible labels.
public enum Tab: String, CaseIterable, Sendable {
    case list = "List"
    case prices = "Prices"
    case you = "You"
}

/// The dark pill: three labeled tabs, white active capsule, plus a separate persimmon
/// `+` circle for capture. Selection binding and the add closure out; no navigation here.
public struct TabPill: View {
    @Binding private var selection: Tab
    private let onAdd: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Namespace private var capsuleSpace

    /// The W8 ruling: a tab label never wraps, and when space runs out the pill's own
    /// padding gives before the word does — the scale floor is 0.8, no lower.
    private var isTight: Bool { typeSize.isAccessibilitySize }

    public init(selection: Binding<Tab>, onAdd: @escaping () -> Void) {
        self._selection = selection
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: isTight ? 8 : 12) {
            HStack(spacing: isTight ? 0 : 4) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(isTight ? 3 : 6)
            .background(Capsule().fill(Palette.ink.color))
            Button(action: onAdd) {
                ZStack {
                    Circle().fill(Palette.persimmon.color)
                    Image(systemName: "plus")
                        .font(.system(.title3, weight: .semibold))
                        .foregroundStyle(Palette.card.color)
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Capture")
        }
    }

    private func tabButton(_ tab: Tab) -> some View {
        let isActive = tab == selection
        return Button {
            withAnimation(Motion.tabChange.resolved(reduceMotion: reduceMotion)) {
                selection = tab
            }
        } label: {
            Text(tab.rawValue)
                .font(.system(.subheadline, weight: isActive ? .semibold : .regular))
                // A tab label never wraps and never hyphenates (W8 ruling): the pill grows
                // to fit first, then the word scales — floored at 0.8, no lower.
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle((isActive ? Palette.ink : Palette.paper).color)
                .padding(.horizontal, isTight ? 8 : 16)
                .frame(minHeight: 44)
                .background {
                    if isActive {
                        Capsule()
                            .fill(Palette.card.color)
                            .matchedGeometryEffect(id: "active", in: capsuleSpace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }
}
