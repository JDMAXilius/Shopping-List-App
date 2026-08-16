import XCTest
import Core

final class MoneyTests: XCTestCase {
    func testEstimateRoundsHardToNearestHalfUnit() {
        XCTAssertEqual(Money.estimate(from: Money(minorUnits: 437)).minorUnits, 450)
        XCTAssertEqual(Money.estimate(from: Money(minorUnits: 412)).minorUnits, 400)
        XCTAssertEqual(Money.estimate(from: Money(minorUnits: 80)).minorUnits, 100)
        XCTAssertEqual(Money.estimate(from: Money(minorUnits: 25)).minorUnits, 50)
        XCTAssertEqual(Money.estimate(from: Money(minorUnits: 0)).minorUnits, 0)
    }

    func testEstimateDisplayNeverShowsFalsePrecision() {
        XCTAssertEqual(Money(minorUnits: 437).estimateDisplay, "~$4.50")
        XCTAssertEqual(Money(minorUnits: 412).estimateDisplay, "~$4.00")
        XCTAssertEqual(Money(minorUnits: 80).estimateDisplay, "~$1.00")
        for minor in stride(from: 0, to: 2_000, by: 7) {
            let display = Money(minorUnits: minor).estimateDisplay
            XCTAssertTrue(display.hasPrefix("~$"), display)
            XCTAssertTrue(display.hasSuffix(".00") || display.hasSuffix(".50"), display)
        }
    }

    func testMeasuredDisplayKeepsExactCents() {
        XCTAssertEqual(Money(minorUnits: 449).display, "$4.49")
        XCTAssertEqual(Money(minorUnits: 5).display, "$0.05")
        XCTAssertEqual(Money(minorUnits: 1_000).display, "$10.00")
    }

    func testMinorUnitArithmeticIsExact() {
        XCTAssertEqual(Money(minorUnits: 437) + Money(minorUnits: 212), Money(minorUnits: 649))
        XCTAssertEqual(Money(minorUnits: 649) - Money(minorUnits: 212), Money(minorUnits: 437))
        // 3 × $3.33 must be exactly $9.99 — the classic Double failure.
        XCTAssertEqual(Money(minorUnits: 333).multiplied(by: 3), Money(minorUnits: 999))
        let total = [10, 20, 30].map { Money(minorUnits: $0) }
            .reduce(Money(minorUnits: 0)) { $0 + $1 }
        XCTAssertEqual(total.minorUnits, 60)
    }

    func testObservationConfidenceDecaysWithAge() {
        let now = Date(timeIntervalSince1970: 100 * 86_400)
        func observation(daysAgo: Double) -> PriceObservation {
            PriceObservation(itemID: ItemID(), shopID: ShopID(),
                             date: now.addingTimeInterval(-daysAgo * 86_400),
                             amount: Money(minorUnits: 449), source: .receipt)
        }
        XCTAssertEqual(observation(daysAgo: 0).confidence(asOf: now), .trusted)
        XCTAssertEqual(observation(daysAgo: 29).confidence(asOf: now), .trusted)
        XCTAssertEqual(observation(daysAgo: 30).confidence(asOf: now), .dated)
        XCTAssertEqual(observation(daysAgo: 90).confidence(asOf: now), .dated)
        XCTAssertEqual(observation(daysAgo: 91).confidence(asOf: now), .estimate)
    }
}
