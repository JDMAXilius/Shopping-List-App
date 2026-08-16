import Core
import Foundation

/// THE parser: the one place in the app that turns typed text into `Money`, and the only one
/// that may exist. It takes the currency and consults the exponent, because a second parser
/// that forgot to is how every price typed in a EUR kitchen was silently refused.
enum MoneyText {
    /// Minor units, built with integers only: 4.49 has no exact Double and a price book that is
    /// off by a cent is a wrong price book. Anything else in the text is not a price.
    static func money(from text: String, currencyCode: String) -> Money? {
        guard text.allSatisfy({
            $0.isNumber || $0 == "." || $0 == "," || $0.isWhitespace || $0.isCurrencySymbol
        }) else { return nil }
        let digits = text.filter { $0.isNumber || $0 == "." || $0 == "," }
            .replacingOccurrences(of: ",", with: ".")
        let parts = digits.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, digits.contains(where: \.isNumber), parts[0].count <= 9,
              let major = Int(parts[0].isEmpty ? "0" : String(parts[0])) else { return nil }
        let exponent = Money.minorUnitExponent(for: currencyCode)
        var minorUnits = major
        for _ in 0 ..< exponent { minorUnits *= 10 }
        guard exponent > 0, parts.count == 2 else {
            return Money(minorUnits: minorUnits, currencyCode: currencyCode)
        }
        // "4.4" is $4.40, not $4.04 — the fraction is padded on the right, like a till.
        let fraction = parts[1].prefix(exponent)
        let padded = fraction + String(repeating: "0", count: exponent - fraction.count)
        guard let cents = Int(String(padded)) else { return nil }
        return Money(minorUnits: minorUnits + cents, currencyCode: currencyCode)
    }

    /// 0.5 is half a pound, which the scanned path has always been able to say. Blank, zero and
    /// anything that isn't a number are not quantities — and the save button stays off.
    static func quantity(from text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned.allSatisfy({ $0.isNumber || $0 == "." }),
              cleaned.filter({ $0 == "." }).count <= 1,
              let value = Double(cleaned), value > 0, value <= 999 else { return nil }
        return value
    }

    /// Whole counts stay whole — "×2", never "×2.0".
    static func quantityText(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
