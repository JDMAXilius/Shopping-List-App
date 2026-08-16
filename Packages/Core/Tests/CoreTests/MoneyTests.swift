import Foundation
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

    func testMinorUnitExponentPerCurrencyClass() {
        for code in ["JPY", "KRW", "CLP", "ISK", "VND", "XAF", "XOF", "XPF", "UGX", "RWF"] {
            XCTAssertEqual(Money.minorUnitExponent(for: code), 0, code)
        }
        // A kitchen created on a Kuwaiti phone: 1.500 KWD is 1500 minor units, not 150.
        for code in ["KWD", "BHD", "JOD", "OMR", "TND", "IQD", "LYD"] {
            XCTAssertEqual(Money.minorUnitExponent(for: code), 3, code)
        }
        // The grid stays coarse in every class — an estimate must never read as looked up.
        XCTAssertEqual(Money.estimate(from: Money(minorUnits: 1437, currencyCode: "KWD")),
                       Money(minorUnits: 1500, currencyCode: "KWD"))
        XCTAssertEqual(Money.estimate(from: Money(minorUnits: 437, currencyCode: "USD")),
                       Money(minorUnits: 450, currencyCode: "USD"))
        XCTAssertEqual(Money.estimate(from: Money(minorUnits: 437, currencyCode: "JPY")),
                       Money(minorUnits: 450, currencyCode: "JPY"))
        for code in ["USD", "EUR", "GBP", "BRL", "CAD", "AUD", "MXN"] {
            XCTAssertEqual(Money.minorUnitExponent(for: code), 2, code)
        }
        // Documented default: an unrecognised code is treated as 2-decimal.
        XCTAssertEqual(Money.minorUnitExponent(for: "ZZZ"), 2)
        XCTAssertEqual(Money.minorUnitExponent(for: ""), 2)
        XCTAssertEqual(Money(minorUnits: 500, currencyCode: "JPY").minorUnitExponent, 0)
        XCTAssertEqual(Money(minorUnits: 500, currencyCode: "BRL").minorUnitExponent, 2)
    }

    func testZeroDecimalCurrenciesDisplayWholeUnits() {
        XCTAssertEqual(Money(minorUnits: 500, currencyCode: "JPY").display, "¥500")
        XCTAssertEqual(Money(minorUnits: 0, currencyCode: "JPY").display, "¥0")
        XCTAssertEqual(Money(minorUnits: 7, currencyCode: "JPY").display, "¥7")
        XCTAssertEqual(Money(minorUnits: -500, currencyCode: "JPY").display, "-¥500")
        XCTAssertEqual(Money(minorUnits: 12_000, currencyCode: "KRW").display, "KRW 12000")
        XCTAssertEqual(Money(minorUnits: 3_990, currencyCode: "CLP").display, "CLP 3990")
        XCTAssertEqual(Money(minorUnits: 1_495, currencyCode: "ISK").display, "ISK 1495")
        XCTAssertEqual(Money(minorUnits: 25_000, currencyCode: "VND").display, "VND 25000")
    }

    func testTwoDecimalCurrenciesDisplayMinorUnitsAsCents() {
        XCTAssertEqual(Money(minorUnits: 500, currencyCode: "BRL").display, "R$5.00")
        XCTAssertEqual(Money(minorUnits: 449, currencyCode: "EUR").display, "€4.49")
        XCTAssertEqual(Money(minorUnits: 5, currencyCode: "GBP").display, "£0.05")
        XCTAssertEqual(Money(minorUnits: -449, currencyCode: "USD").display, "-$4.49")
        XCTAssertEqual(Money(minorUnits: 1_234, currencyCode: "MXN").display, "MXN 12.34")
    }

    func testUnknownCurrencyCodeFallsBackToCodePrefix() {
        XCTAssertEqual(Money(minorUnits: 1_234, currencyCode: "ZZZ").display, "ZZZ 12.34")
        XCTAssertEqual(Money(minorUnits: 1_234, currencyCode: "ZZZ").estimateDisplay, "~ZZZ 12.50")
        XCTAssertEqual(Money(minorUnits: 0, currencyCode: "").display, " 0.00")
    }

    func testEstimateRoundingIsIdenticalOnTheMinorUnitGridForBothClasses() {
        for code in ["USD", "JPY"] {
            func rounded(_ minor: Int) -> Int {
                Money.estimate(from: Money(minorUnits: minor, currencyCode: code)).minorUnits
            }
            XCTAssertEqual(rounded(437), 450, code)
            XCTAssertEqual(rounded(412), 400, code)
            XCTAssertEqual(rounded(0), 0, code)
            XCTAssertEqual(rounded(1), 0, code)          // small values collapse to zero…
            XCTAssertEqual(rounded(24), 0, code)
            XCTAssertEqual(rounded(25), 50, code)        // …and ties round up, always
            XCTAssertEqual(rounded(75), 100, code)
            XCTAssertEqual(rounded(26), 50, code)
            XCTAssertEqual(rounded(-425), -400, code)    // ties round up for negatives too
            XCTAssertEqual(rounded(-437), -450, code)
            XCTAssertEqual(
                Money.estimate(from: Money(minorUnits: 437, currencyCode: code)).currencyCode,
                code)
        }
    }

    func testZeroDecimalEstimatesLandOnAWholeFiftyUnitGrid() {
        XCTAssertEqual(Money(minorUnits: 437, currencyCode: "JPY").estimateDisplay, "~¥450")
        XCTAssertEqual(Money(minorUnits: 412, currencyCode: "JPY").estimateDisplay, "~¥400")
        XCTAssertEqual(Money(minorUnits: 80, currencyCode: "JPY").estimateDisplay, "~¥100")
        // An estimate must never look like a looked-up price: coarse in every currency class.
        for minor in stride(from: 0, to: 2_000, by: 7) {
            let money = Money(minorUnits: minor, currencyCode: "JPY")
            let estimate = Money.estimate(from: money)
            XCTAssertEqual(estimate.minorUnits % 50, 0, money.estimateDisplay)
            XCTAssertTrue(money.estimateDisplay.hasPrefix("~¥"), money.estimateDisplay)
        }
    }

    // A kitchen created in the eurozone shops in euros, with no caller passing anything.
    func testKitchenTakesItsCurrencyFromTheLocaleItWasCreatedIn() {
        XCTAssertEqual(Kitchen.defaultCurrencyCode(for: Locale(identifier: "de_DE")), "EUR")
        XCTAssertEqual(Kitchen.defaultCurrencyCode(for: Locale(identifier: "es_MX")), "MXN")
        XCTAssertEqual(Kitchen.defaultCurrencyCode(for: Locale(identifier: "ja_JP")), "JPY")
        XCTAssertEqual(Kitchen.defaultCurrencyCode(for: Locale(identifier: "en_US")), "USD")
        // Whether POSIX carries a currency or not, the answer is USD — never empty, never a guess.
        XCTAssertEqual(Kitchen.defaultCurrencyCode(for: Locale(identifier: "en_US_POSIX")), "USD")

        let mexico = Kitchen.defaultCurrencyCode(for: Locale(identifier: "es_MX"))
        let kitchen = Kitchen(name: "Cocina", currencyCode: mexico)
        XCTAssertEqual(kitchen.currencyCode, "MXN")
        XCTAssertEqual(Money(minorUnits: 4_500, currencyCode: kitchen.currencyCode).display,
                       "MXN 45.00", "an unknown symbol prints its code, never a dollar sign")
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
