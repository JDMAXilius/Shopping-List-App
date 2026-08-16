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

    /// Quantity one is the old behaviour exactly: this case must not move.
    func testSummaryDerivesCountsAndSumFromOneArray() {
        let summary = PriceSummary([
            PriceDisplay(amount: usd(329), confidence: .trusted).line(quantity: 1),
            // contributes its DISPLAYED value, 450 — the ledger adds up
            PriceDisplay.estimated(usd(437)).line(quantity: 1),
            PriceDisplay.none.line(quantity: 1),
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
            PriceDisplay(amount: usd(200), confidence: .trusted).line(quantity: 1),
            PriceDisplay(amount: usd(350), confidence: .dated).line(quantity: 1),
        ])
        XCTAssertEqual(summary.total, usd(550))
        XCTAssertFalse(summary.isApproximate)
    }

    // The fix-3 honesty rule itself: an unpriced gap ALONE makes the figure approximate.
    func testUnpricedAloneMakesApproximate() {
        let summary = PriceSummary([
            PriceDisplay(amount: usd(200), confidence: .trusted).line(quantity: 1),
            PriceDisplay.none.line(quantity: 1),
        ])
        XCTAssertTrue(summary.isApproximate)
        XCTAssertEqual(summary.total, usd(200))
    }

    func testEstimateAloneMakesApproximate() {
        XCTAssertTrue(PriceSummary([PriceDisplay.estimated(usd(100)).line(quantity: 1)])
            .isApproximate)
    }

    func testEmptyAndAllUnpriced() {
        let empty = PriceSummary([])
        XCTAssertEqual(empty.total.minorUnits, 0)
        XCTAssertFalse(empty.hasPricedItems)
        XCTAssertFalse(empty.isApproximate)

        let gaps = PriceSummary([PriceDisplay.none.line(quantity: 1),
                                 PriceDisplay.none.line(quantity: 4)])
        XCTAssertEqual(gaps.total.minorUnits, 0)
        XCTAssertFalse(gaps.hasPricedItems)   // AisleHeader shows no subtotal — ≈ $0.00 would lie
        XCTAssertTrue(gaps.isApproximate)
        // Counts are counts of ROWS, whatever the quantity: "2 no price yet" is two things
        // to find, and ×4 of a thing with no price is still one gap in the figure.
        XCTAssertEqual(gaps.unpricedCount, 2)
    }

    func testCurrencyPropagatesFromPrices() {
        let brl = Money(minorUnits: 500, currencyCode: "BRL")
        let summary = PriceSummary([PriceDisplay(amount: brl, confidence: .trusted)
            .line(quantity: 3)])
        XCTAssertEqual(summary.total.currencyCode, "BRL")
        XCTAssertEqual(summary.total.minorUnits, 1_500)
    }

    // MARK: A total counts what the list says (W8-P5 rulings 1–3)

    /// THE bug. A list holding ×4 milk at a measured $3.50 said $3.50 from wave 5 to wave 8:
    /// every total in the app summed the price of ONE. If this fails, it is back.
    func testFourOfSomethingTotalsFourTimesIt() {
        let milk = PriceDisplay(amount: usd(350), confidence: .trusted)
        XCTAssertEqual(PriceSummary([milk.line(quantity: 4)]).total, usd(1_400))
        // The row still shows what one costs — the two quantities are both true at once.
        XCTAssertEqual(milk.accessibilityPhrase, "$3.50")
    }

    /// Scaling changes the amount, never the tier: four measured items are still measured,
    /// so the figure carries no `≈` and speaks without hedging.
    func testScalingPreservesTheTier() {
        let measured = PriceSummary([
            PriceDisplay(amount: usd(350), confidence: .trusted).line(quantity: 4)])
        XCTAssertEqual(measured.measuredCount, 1)
        XCTAssertEqual(measured.estimatedCount, 0)
        XCTAssertFalse(measured.isApproximate)
        XCTAssertEqual(measured.display, "$14.00")

        let estimated = PriceSummary([PriceDisplay.estimated(usd(437)).line(quantity: 4)])
        XCTAssertEqual(estimated.estimatedCount, 1)
        XCTAssertEqual(estimated.measuredCount, 0)
        XCTAssertTrue(estimated.isApproximate)
        // 450 (the grid, applied to the unit) × 4 — never 437 × 4 rounded to anything.
        XCTAssertEqual(estimated.total, usd(1_800))
        XCTAssertEqual(estimated.display, "≈ $18.00")
    }

    /// Ruling 3, the case that bites: the row showed `~$4.50`, so half of it is $2.25.
    /// Re-rounding the line total would say ~$2.50; rounding after the multiply would say
    /// $2.00. Both are figures nothing on screen supports.
    func testHalfAnEstimateIsHalfOfWhatTheRowShowed() {
        let unit = PriceDisplay.estimated(usd(437))
        XCTAssertEqual(unit.accessibilityPhrase, "about $4.50, estimated")   // what was shown

        let half = PriceSummary([unit.line(quantity: 0.5)])
        XCTAssertEqual(half.total, usd(225))
        XCTAssertNotEqual(half.total, usd(250))   // the second rounding
        XCTAssertNotEqual(half.total, usd(200))   // the reversed order
        XCTAssertTrue(half.isApproximate)

        XCTAssertEqual(PriceSummary([unit.line(quantity: 0.25)]).total, usd(113))
        XCTAssertEqual(PriceSummary([unit.line(quantity: 0.75)]).total, usd(338))
    }

    /// A weighed row: 1.5 lb at a measured $3.99 is $5.99 — rounded once, to the minor unit.
    func testAFractionalQuantityRoundsOnceAtTheEnd() {
        let perPound = PriceDisplay(amount: usd(399), confidence: .trusted)
        XCTAssertEqual(PriceSummary([perPound.line(quantity: 1.5)]).total, usd(599))
        XCTAssertEqual(PriceSummary([
            PriceDisplay(amount: usd(349), confidence: .trusted).line(quantity: 0.5)]).total,
            usd(175))
    }

    /// Whole counts never touch floating point: a 40-row trip must not drift a cent.
    func testWholeCountsAreExact() {
        for count in 1 ... 40 {
            XCTAssertEqual(
                PriceSummary([PriceDisplay(amount: usd(349), confidence: .trusted)
                    .line(quantity: Double(count))]).total,
                usd(349 * count))
        }
    }

    /// A quantity nothing can read is not a licence to invent or erase money — the price of
    /// one stands, which is the figure the app showed before this existed.
    func testANonsenseQuantityFallsBackToThePriceOfOne() {
        let unit = PriceDisplay(amount: usd(350), confidence: .trusted)
        let nonsense: [Double] = [0, -3, .nan, .infinity]
        for quantity in nonsense {
            XCTAssertEqual(PriceSummary([unit.line(quantity: quantity)]).total, usd(350),
                           "quantity \(quantity)")
        }
    }

    /// The whole basket at once: the figure, its mark and its breakdown agree.
    func testABasketOfEveryTierAtEveryQuantity() {
        let summary = PriceSummary([
            PriceDisplay(amount: usd(350), confidence: .trusted).line(quantity: 4),   // 1400
            PriceDisplay.estimated(usd(437)).line(quantity: 0.5),                     //  225
            PriceDisplay(amount: usd(199), confidence: .dated).line(quantity: 1),     //  199
            PriceDisplay.none.line(quantity: 3),                                      //    0
        ])
        XCTAssertEqual(summary.total, usd(1_824))
        XCTAssertEqual(summary.display, "≈ $18.24")
        XCTAssertEqual(summary.breakdown, "1 estimated · 1 no price yet")
        XCTAssertEqual(summary.spokenTotal, "about $18.24")
        XCTAssertFalse(summary.spokenTotal.contains("≈"))
    }

    /// A zero-decimal currency scales on its own grid: ¥137 estimated shows ~¥150, and
    /// three of them are ¥450 — never ¥411 and never a fractional yen.
    func testAZeroDecimalCurrencyScalesOnItsOwnGrid() {
        let yen = PriceDisplay.estimated(Money(minorUnits: 137, currencyCode: "JPY"))
        XCTAssertEqual(yen.accessibilityPhrase, "about ¥150, estimated")
        let summary = PriceSummary([yen.line(quantity: 3)])
        XCTAssertEqual(summary.total, Money(minorUnits: 450, currencyCode: "JPY"))
    }
}
