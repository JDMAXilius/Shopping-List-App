import Core
import DesignKit
import SnapshotTesting
import SwiftUI
import XCTest

/// Pixel contracts for the twelve DesignKit components, one composed image per component
/// so every money tier ($4.49 measured · ~$5.00 estimated · — none · ≈ totals) is in frame.
/// Each runs at the default size and the largest Dynamic Type. One style, one appearance —
/// there is no dark variant to snapshot. Reference images live in __Snapshots__ and are
/// recorded on the iPhone 17 simulator; a diff is a broken visual contract, not noise.
@MainActor
final class ComponentSnapshotTests: XCTestCase {

    private func usd(_ minor: Int) -> Money { Money(minorUnits: minor, currencyCode: "USD") }
    private var measured: PriceDisplay { PriceDisplay(amount: usd(449), confidence: .trusted) }
    private var estimated: PriceDisplay { .estimated(usd(500)) }
    private func one(_ price: PriceDisplay) -> PriceLine { price.line(quantity: 1) }

    private func verify(
        _ view: some View, height: CGFloat,
        file: StaticString = #filePath, testName: String = #function, line: UInt = #line
    ) {
        for (suffix, size) in [("default", DynamicTypeSize.large),
                               ("ax5", DynamicTypeSize.accessibility5)] {
            let framed = view
                .dynamicTypeSize(size)
                .frame(width: 390, height: height)
                .background(Palette.paper.color)
            assertSnapshot(
                of: UIHostingController(rootView: framed),
                as: .image(size: CGSize(width: 390, height: height)),
                named: suffix, file: file, testName: testName, line: line)
        }
    }

    func testItemRow() {
        verify(VStack(spacing: 0) {
            ItemRow(name: "Oat milk", quantity: "×2", glyph: .plantMilk,
                    price: measured, onToggle: {})
            ItemRow(name: "Bananas", glyph: .produce, price: estimated, onToggle: {})
            ItemRow(name: "Chicken breast", quantity: "1.5 lb", glyph: .meat, price: .none,
                    prompt: "tap to set what you paid", onToggle: {}, onOpen: {})
            ItemRow(name: "Bread", glyph: .bakery, price: measured, isChecked: true,
                    onToggle: {})
        }, height: 620)
    }

    func testPriceLabel() {
        verify(VStack(alignment: .trailing, spacing: 12) {
            PriceLabel(measured)
            PriceLabel(estimated)
            PriceLabel(.none)
        }, height: 220)
    }

    /// One of each, so these two figures are the ones already recorded in __Snapshots__:
    /// W8-P5 made a total sum LINE totals, and the pixels here must not move with it.
    func testTotalBar() {
        verify(VStack(spacing: 12) {
            TotalBar(prices: [one(measured), one(measured)])   // all measured: exact total
            TotalBar(prices: [one(measured), one(estimated),   // gap + estimate: ≈ total
                              one(.none)])
        }, height: 260)
    }

    func testAisleHeader() {
        verify(VStack(spacing: 12) {
            AisleHeader(title: "Produce", prices: [one(measured), one(estimated)], doneCount: 0)
            AisleHeader(title: "Produce", prices: [one(measured), one(estimated)], doneCount: 2,
                        isCollapsed: true)
        }, height: 220)
    }

    func testInputBar() {
        verify(InputBar(text: .constant(""), onSubmit: {}, onMic: {}), height: 140)
    }

    func testTabPill() {
        verify(TabPill(selection: .constant(.list), onAdd: {}), height: 160)
    }

    func testEmptyState() {
        verify(EmptyState(glyph: .produce, message: "Nothing on the list yet.",
                          actionTitle: "Add the first thing", action: {}), height: 340)
    }

    func testSectionLabel() {
        verify(VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Total")
            SectionLabel("No price yet", tone: .attention, on: .card)
        }, height: 160)
    }

    func testUndoBar() {
        verify(UndoBar(phrase: "bread back on the list", on: .paper,
                       onUndo: {}, onDismiss: {}), height: 160)
    }

    func testChip() {
        verify(VStack(spacing: 12) {
            Chip("Tesco", glyph: .other, on: .paper, opensPicker: true, action: {})
            Chip("2 unmatched", tone: .attention, on: .paper)
        }, height: 220)
    }

    func testNotice() {
        verify(VStack(spacing: 12) {
            Notice("Prices remembered from your last trip here.", on: .paper)
            Notice("$14.00, more than 3× the usual $3.50", tone: .attention, on: .paper)
        }, height: 300)
    }

    func testPaidTotalLabel() {
        let month = PaidSummary(
            [ReceiptTotal(printedOnReceipt: usd(12_450)),
             ReceiptTotal(printedOnReceipt: usd(9_050))],
            in: "July", currencyCode: "USD", unread: 1)
        let empty = PaidSummary([], in: "July", currencyCode: "USD")
        verify(VStack(alignment: .leading, spacing: 16) {
            PaidTotalLabel(month)                 // solid figure + its basis sentence
            PaidTotalLabel(empty)                 // — with the no-receipts sentence
        }, height: 400)
    }

    func testPriceLabelDisplaySize() {
        verify(VStack(alignment: .trailing, spacing: 12) {
            PriceLabel(measured, size: .display)
            PriceLabel(estimated, size: .display)
        }, height: 220)
    }

    func testField() {
        verify(VStack(spacing: 12) {
            Field("Item", text: .constant("Whole milk"), placeholder: "What is it?",
                  on: .paper)
            Field("Price", text: .constant("3.49"), affix: "$", keyboard: .decimal,
                  on: .paper)
        }, height: 340)
    }
}
