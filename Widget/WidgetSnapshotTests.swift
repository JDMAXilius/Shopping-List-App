import Core
import DesignKit
import SnapshotTesting
import SwiftUI
import WidgetKit
import XCTest

/// Pixel contracts for the two widget families, default and accessibility5 — the tile's
/// one money figure, the row ticks, and the honest empty/refusal messages.
@MainActor
final class WidgetSnapshotTests: XCTestCase {

    private func usd(_ minor: Int) -> Money { Money(minorUnits: minor, currencyCode: "USD") }

    private var list: WidgetState {
        .list(WidgetList(
            rows: [WidgetRow(id: ListItemID(), name: "Oat milk", isChecked: false),
                   WidgetRow(id: ListItemID(), name: "Bananas", isChecked: false),
                   WidgetRow(id: ListItemID(), name: "Bread", isChecked: true)],
            remaining: 2, total: 3,
            summary: PriceSummary([
                PriceDisplay(amount: usd(449), confidence: .trusted).line(quantity: 1),
                PriceDisplay.estimated(usd(250)).line(quantity: 1),
            ])))
    }

    private func verify(
        _ state: WidgetState, family: WidgetFamily, size: CGSize,
        file: StaticString = #filePath, testName: String = #function, line: UInt = #line
    ) {
        for (suffix, type) in [("default", DynamicTypeSize.large),
                               ("ax5", DynamicTypeSize.accessibility5)] {
            let framed = ListWidgetView(entry: ListEntry(date: .distantPast, state: state),
                                        familyOverride: family)
                .dynamicTypeSize(type)
                .frame(width: size.width, height: size.height)
                .background(Palette.paper.color)
            assertSnapshot(
                of: UIHostingController(rootView: framed),
                as: .image(size: size),
                named: suffix, file: file, testName: testName, line: line)
        }
    }

    func testAccessoryRectangular() {
        verify(list, family: .accessoryRectangular, size: CGSize(width: 172, height: 76))
    }

    func testSystemSmall() {
        verify(list, family: .systemSmall, size: CGSize(width: 170, height: 170))
    }

    func testNeedsAppRefusal() {
        verify(.needsApp, family: .accessoryRectangular, size: CGSize(width: 172, height: 76))
    }
}
