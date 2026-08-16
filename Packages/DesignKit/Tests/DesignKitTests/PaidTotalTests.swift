import XCTest
import Core
import SwiftUI
@testable import DesignKit

// W7-P3 rulings 1–4 at the public surface. The rule these protect: money PAID and money
// MATCHED to items are different quantities, and only the first one is a month's spend.
final class PaidTotalTests: XCTestCase {

    private func usd(_ minor: Int) -> Money { Money(minorUnits: minor, currencyCode: "USD") }
    private func till(_ minor: Int) -> ReceiptTotal {
        ReceiptTotal(printedOnReceipt: usd(minor))
    }

    // MARK: PaidSummary — the sum of what the tills printed (ruling 1)

    func testPaidSummarySumsTillTotalsAndCountsTrips() {
        let paid = PaidSummary([till(12_450), till(8_960), till(9_050)],
                               in: "July", currencyCode: "USD")
        XCTAssertEqual(paid.total, usd(30_460))
        XCTAssertEqual(paid.receiptCount, 3)
        XCTAssertTrue(paid.hasReceipts)
        XCTAssertEqual(paid.figure, "$304.60")
    }

    // A till total is exact. `≈` means "contains an estimate" and would be a second lie about
    // a different thing — the incompleteness is said in words instead.
    func testAPaidTotalNeverWearsAnApproximationMark() {
        let paid = PaidSummary([till(6_210)], in: "July", currencyCode: "USD")
        XCTAssertEqual(paid.figure, "$62.10")
        XCTAssertFalse(paid.figure.contains("≈"))
        XCTAssertFalse(paid.figure.contains("~"))
    }

    func testNoReceiptsStatesNoTotalRatherThanZero() {
        let paid = PaidSummary([], in: "July", currencyCode: "USD")
        XCTAssertFalse(paid.hasReceipts)
        // `$0.00` would be a claim that nothing was spent in July. It is not one we can make.
        XCTAssertEqual(paid.figure, "—")
        XCTAssertEqual(paid.basis,
                       "No receipts captured in July, so there is no total to state.")
        XCTAssertEqual(paid.total.currencyCode, "USD")
    }

    // MARK: The basis travels with the number (ruling 2)

    func testTheBasisNamesTheTripsCountedAndWhatIsMissing() {
        let one = PaidSummary([till(6_210)], in: "July", currencyCode: "USD")
        XCTAssertEqual(one.basis, "From 1 receipt captured in July. "
                       + "A trip you didn't scan isn't in this number.")

        let many = PaidSummary([till(6_210), till(4_000)], in: "July", currencyCode: "USD")
        XCTAssertEqual(many.basis, "From 2 receipts captured in July. "
                       + "A trip you didn't scan isn't in this number.")
    }

    func testVoiceOverHearsTheNumberAndItsBasisTogether() {
        let paid = PaidSummary([till(6_210)], in: "July", currencyCode: "USD")
        XCTAssertEqual(paid.accessibilityPhrase, "$62.10. \(paid.basis)")
        // Nothing captured: "—" is not a thing to speak, so the sentence is the whole answer.
        let empty = PaidSummary([], in: "July", currencyCode: "USD")
        XCTAssertEqual(empty.accessibilityPhrase, empty.basis)
    }

    func testTheCurrencyComesFromTheReceiptsThemselves() {
        let brl = ReceiptTotal(printedOnReceipt: Money(minorUnits: 500, currencyCode: "BRL"))
        XCTAssertEqual(PaidSummary([brl], in: "julho", currencyCode: "USD").total.currencyCode,
                       "BRL")
    }

    // MARK: The two summaries are not interchangeable (ruling 3)

    // A compile-time fact, restated where a reader will look: `PaidSummary` takes
    // `[ReceiptTotal]` and `PriceSummary` takes `[PriceLine]`, and neither type can be
    // made from the other. What runs here is that they disagree on the SAME money, which is
    // the whole point — 12 matched lines are not a month's spend.
    func testMatchedLinesAndMoneyPaidAreDifferentQuantities() {
        let matched = PriceSummary((0 ..< 12).map {
            PriceDisplay(amount: usd(517 + $0), confidence: .trusted).line(quantity: 1)
        })
        let paid = PaidSummary([till(30_000)], in: "July", currencyCode: "USD")
        XCTAssertEqual(matched.total, usd(6_270))
        XCTAssertEqual(paid.total, usd(30_000))
        XCTAssertNotEqual(matched.total, paid.total)
    }

    // MARK: PriceSize — one tier logic, three sizes (ruling 4)

    func testTheThreeSizesAreActuallyThreeDifferentSizes() {
        // If a size scale collapses, a hero figure silently renders at row size again.
        XCTAssertEqual(Set(PriceSize.allCases.map(\.textStyle)).count, PriceSize.allCases.count)
        XCTAssertEqual(PriceSize.display.textStyle, .largeTitle)
        XCTAssertEqual(PriceSize.body.textStyle, .body)
    }

    func testAnEstimateIsLighterThanAMeasuredPriceAtEverySize() {
        for size in PriceSize.allCases {
            XCTAssertNotEqual(size.measuredWeight, size.estimatedWeight,
                              "\(size) lost the weight half of the honesty tier")
            XCTAssertEqual(size.estimatedWeight, .regular)
        }
    }

    func testTheDefaultSizeIsTheOneEveryExistingRowAlreadyUses() {
        // PriceLabel's default must stay `.body`, or every list row changes size at once.
        XCTAssertEqual(Typography.price, PriceSize.body.measuredFont)
        XCTAssertEqual(Typography.priceEstimated, PriceSize.body.estimatedFont)
        XCTAssertEqual(Typography.priceSmall, PriceSize.small.estimatedFont)
    }

    func testOnlyTheHeroIsAllowedToShrink() {
        // A hero that truncates shows a wrong number ($284.6…); a row price is laid out by
        // its caller and must not start scaling itself down.
        XCTAssertEqual(PriceSize.display.minimumScale, 0.5)
        XCTAssertEqual(PriceSize.body.minimumScale, 1)
        XCTAssertEqual(PriceSize.small.minimumScale, 1)
    }
}
