import Foundation

// Stored amounts are integer minor units — Double never touches money.
public struct Money: Hashable, Sendable, Codable {
    public let minorUnits: Int
    public let currencyCode: String

    public init(minorUnits: Int, currencyCode: String = "USD") {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }

    // Estimates round hard to the nearest half unit — ~$4.50, never ~$4.37.
    public static func estimate(from money: Money) -> Money {
        let step = 50
        let remainder = ((money.minorUnits % step) + step) % step
        let floor = money.minorUnits - remainder
        let rounded = remainder * 2 >= step ? floor + step : floor
        return Money(minorUnits: rounded, currencyCode: money.currencyCode)
    }

    public var display: String {
        let units = abs(minorUnits)
        let sign = minorUnits < 0 ? "-" : ""
        return "\(sign)\(symbol)\(units / 100).\(String(format: "%02d", units % 100))"
    }

    // Always ~$X.00 / ~$X.50 — an estimate never shows false precision.
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

    private var symbol: String {
        switch currencyCode {
        case "USD": return "$"
        case "BRL": return "R$"
        case "EUR": return "€"
        case "GBP": return "£"
        default: return currencyCode + " "
        }
    }
}
