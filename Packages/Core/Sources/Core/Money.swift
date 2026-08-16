import Foundation

// Stored amounts are integer minor units — Double never touches money.
public struct Money: Hashable, Sendable, Codable {
    public let minorUnits: Int
    public let currencyCode: String

    public init(minorUnits: Int, currencyCode: String = "USD") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    // Currencies whose minor unit *is* the major unit: 500 JPY is ¥500, never ¥5.00.
    private static let zeroDecimalCodes: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW", "PYG",
        "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF",
    ]

    // The Gulf dinars divide into a thousand, not a hundred. Read as 2-decimal, "1.500" parses
    // to 150 and every price in these currencies is stored and shown ten times wrong.
    private static let threeDecimalCodes: Set<String> = [
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND",
    ]

    // Unknown codes are assumed 2-decimal — true of every currency we ship to and of most others.
    public static func minorUnitExponent(for currencyCode: String) -> Int {
        if zeroDecimalCodes.contains(currencyCode) { return 0 }
        return threeDecimalCodes.contains(currencyCode) ? 3 : 2
    }

    public var minorUnitExponent: Int { Money.minorUnitExponent(for: currencyCode) }

    // Half a major unit where that is coarse enough, 50 minor units where it is not: $0.50 with
    // cents, ¥50 with whole yen, 0.500 with mils. Coarse in every class, so an estimate can
    // never read as a looked-up price.
    private static func estimateStep(for exponent: Int) -> Int {
        var major = 1
        for _ in 0..<exponent { major *= 10 }
        return max(50, major / 2)
    }

    // Estimates round hard to that grid — ~$4.50, never ~$4.37.
    public static func estimate(from money: Money) -> Money {
        let step = estimateStep(for: money.minorUnitExponent)
        let remainder = ((money.minorUnits % step) + step) % step
        let floor = money.minorUnits - remainder
        let rounded = remainder * 2 >= step ? floor + step : floor
        return Money(minorUnits: rounded, currencyCode: money.currencyCode)
    }

    public var display: String {
        let units = abs(minorUnits)
        let sign = minorUnits < 0 ? "-" : ""
        let exponent = minorUnitExponent
        guard exponent > 0 else { return "\(sign)\(symbol)\(units)" }
        var divisor = 1
        for _ in 0 ..< exponent { divisor *= 10 }
        let fraction = String(format: "%0\(exponent)d", units % divisor)
        return "\(sign)\(symbol)\(units / divisor).\(fraction)"
    }

    // Always lands on the estimate grid — an estimate never shows false precision.
    public var estimateDisplay: String {
        "~" + Money.estimate(from: self).display
    }

    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "mixed currencies")
        return Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currencyCode == rhs.currencyCode, "mixed currencies")
        return Money(minorUnits: lhs.minorUnits - rhs.minorUnits, currencyCode: lhs.currencyCode)
    }

    public func multiplied(by count: Int) -> Money {
        Money(minorUnits: minorUnits * count, currencyCode: currencyCode)
    }

    // Unknown codes print the code rather than risk a wrong symbol: "ZZZ 12.34".
    private var symbol: String {
        switch currencyCode {
        case "USD": return "$"
        case "BRL": return "R$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default: return currencyCode + " "
        }
    }
}
