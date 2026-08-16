// New code (no JS source): pull a leading quantity + unit off free text.
// "2 lb chicken breast" → (2, "lb", "chicken breast"). Deliberately minimal.

public struct ParsedQuantity: Sendable, Equatable {
    public let quantity: Double?
    public let unit: String?
    public let rest: String

    public init(quantity: Double?, unit: String?, rest: String) {
        self.quantity = quantity
        self.unit = unit
        self.rest = rest
    }
}

public enum QuantityParser {
    // alias → canonical unit
    static let units: [String: String] = [
        "lb": "lb", "lbs": "lb", "kg": "kg", "g": "g", "oz": "oz",
        "l": "l", "ml": "ml", "dozen": "dozen",
        "pack": "pack", "packs": "pack",
        "bunch": "bunch", "bunches": "bunch",
        "can": "can", "cans": "can",
        "bottle": "bottle", "bottles": "bottle",
        "box": "box", "boxes": "box",
        "bag": "bag", "bags": "bag",
    ]

    public static func parse(_ input: String) -> ParsedQuantity {
        var tokens = input.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = tokens.first else {
            return ParsedQuantity(quantity: nil, unit: nil, rest: "")
        }

        var quantity: Double?
        var unit: String?

        if let number = number(from: first) {
            quantity = number
            tokens.removeFirst()
        } else if let (number, attached) = attachedUnit(from: first.lowercased()) {
            // "2lb" — number and unit in one token
            quantity = number
            unit = attached
            tokens.removeFirst()
        }

        if quantity != nil, unit == nil, let next = tokens.first,
            let canonical = units[next.lowercased()] {
            unit = canonical
            tokens.removeFirst()
        }

        return ParsedQuantity(quantity: quantity, unit: unit, rest: tokens.joined(separator: " "))
    }

    // Strict decimal: digits with an optional single point. Rejects "nan",
    // "1e3", "-2" — none of those are grocery quantities.
    private static func number(from token: String) -> Double? {
        var digits = 0
        var points = 0
        for ch in token {
            if ch.isNumber && ch.isASCII { digits += 1 } else if ch == "." { points += 1 } else { return nil }
        }
        guard digits > 0, points <= 1 else { return nil }
        return Double(token)
    }

    private static func attachedUnit(from token: String) -> (Double, String)? {
        guard let splitIndex = token.firstIndex(where: { !$0.isNumber && $0 != "." }) else { return nil }
        let numberPart = String(token[..<splitIndex])
        let unitPart = String(token[splitIndex...])
        guard let value = number(from: numberPart), let canonical = units[unitPart] else { return nil }
        return (value, canonical)
    }
}
