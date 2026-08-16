import XCTest
import Core
import DesignKit

// W4-C1 fixes 1–3 + 7, verified at the public surface. `.measured` being unreachable
// without a Confidence is a compile-time fact (PriceDisplay's tier is internal); what
// runs here is the behaviour that the opaque surface promises.
final class PriceSemanticsTests: XCTestCase {

    private func usd(_ minor: Int) -> Money { Money(minorUnits: minor, currencyCode: "USD") }

    // MARK: PriceDisplay — the confidence bridge and the ONE VoiceOver phrase (fix 7)

    func testTrustedAndDatedRenderMeasured() {
        // Measured speaks the exact figure, no hedging.
        XCTAssertEqual(
            PriceDisplay(amount: usd(449), confidence: .trusted).accessibilityPhrase, "$4.49")
        XCTAssertEqual(
            PriceDisplay(amount: usd(449), confidence: .dated).accessibilityPhrase, "$4.49")
    }

    func testEstimateConfidenceDemotesToEstimatedPhrase() {
        // 437¢ rounds to the half-unit: "about $4.50, estimated" — never "$4.37".
        XCTAssertEqual(
            PriceDisplay(amount: usd(437), confidence: .estimate).accessibilityPhrase,
            "about $4.50, estimated")
        XCTAssertEqual(
            PriceDisplay.estimated(usd(437)).accessibilityPhrase,
            "about $4.50, estimated")
    }

    func testNonePhrase() {
        XCTAssertEqual(PriceDisplay.none.accessibilityPhrase, "no price yet")
    }

    func testDisplayEquality() {
        XCTAssertEqual(PriceDisplay.none, PriceDisplay.none)
        XCTAssertEqual(
            PriceDisplay(amount: usd(100), confidence: .trusted),
            PriceDisplay(amount: usd(100), confidence: .dated))
        XCTAssertNotEqual(
            PriceDisplay(amount: usd(100), confidence: .trusted),
            PriceDisplay.estimated(usd(100)))
    }

    // MARK: PriceSummary — one array in, sum + counts + ≈ out (fixes 2–3)

    func testSummaryDerivesCountsAndSumFromOneArray() {
        let summary = PriceSummary([
            PriceDisplay(amount: usd(329), confidence: .trusted),
            .estimated(usd(437)),   // contributes its DISPLAYED value, 450 — the ledger adds up
            .none,
        ])
        XCTAssertEqual(summary.measuredCount, 1)
        XCTAssertEqual(summary.estimatedCount, 1)
        XCTAssertEqual(summary.unpricedCount, 1)
        XCTAssertEqual(summary.total, usd(329 + 450))
        XCTAssertTrue(summary.isApproximate)
        XCTAssertTrue(summary.hasPricedItems)
    }

    func testAllMeasuredIsExact() {
        let summary = PriceSummary([
            PriceDisplay(amount: usd(200), confidence: .trusted),
            PriceDisplay(amount: usd(350), confidence: .dated),
        ])
        XCTAssertEqual(summary.total, usd(550))
        XCTAssertFalse(summary.isApproximate)
    }

    // The fix-3 honesty rule itself: an unpriced gap ALONE makes the figure approximate.
    func testUnpricedAloneMakesApproximate() {
        let summary = PriceSummary([
            PriceDisplay(amount: usd(200), confidence: .trusted),
            .none,
        ])
        XCTAssertTrue(summary.isApproximate)
        XCTAssertEqual(summary.total, usd(200))
    }

    func testEstimateAloneMakesApproximate() {
        XCTAssertTrue(PriceSummary([.estimated(usd(100))]).isApproximate)
    }

    func testEmptyAndAllUnpriced() {
        let empty = PriceSummary([])
        XCTAssertEqual(empty.total.minorUnits, 0)
        XCTAssertFalse(empty.hasPricedItems)
        XCTAssertFalse(empty.isApproximate)

        let gaps = PriceSummary([.none, .none])
        XCTAssertEqual(gaps.total.minorUnits, 0)
        XCTAssertFalse(gaps.hasPricedItems)   // AisleHeader shows no subtotal — ≈ $0.00 would lie
        XCTAssertTrue(gaps.isApproximate)
        XCTAssertEqual(gaps.unpricedCount, 2)
    }

    func testCurrencyPropagatesFromPrices() {
        let brl = Money(minorUnits: 500, currencyCode: "BRL")
        let summary = PriceSummary([PriceDisplay(amount: brl, confidence: .trusted)])
        XCTAssertEqual(summary.total.currencyCode, "BRL")
    }
}
