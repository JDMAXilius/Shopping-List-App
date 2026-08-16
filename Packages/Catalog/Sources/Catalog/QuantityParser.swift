// Pulls a leading quantity/container off free text so the resolver sees the item:
// "2 lb chicken breast" → 2 lb · "chicken breast". Ported from and pinned to
// data/catalog/quantity.mjs — run `node data/catalog/quantity.mjs` for the contract.

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
        "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb",
        "kg": "kg", "kgs": "kg", "kilo": "kg", "kilos": "kg",
        "g": "g", "gram": "g", "grams": "g", "oz": "oz", "ounce": "oz", "ounces": "oz",
        "l": "l", "litre": "l", "litres": "l", "liter": "l", "liters": "l",
        "ml": "ml", "pint": "pint", "pints": "pint", "quart": "quart", "quarts": "quart",
        "dozen": "dozen", "dozens": "dozen",
        "pack": "pack", "packs": "pack", "packet": "pack", "packets": "pack",
        "bunch": "bunch", "bunches": "bunch",
        "can": "can", "cans": "can", "tin": "tin", "tins": "tin",
        "bottle": "bottle", "bottles": "bottle",
        "box": "box", "boxes": "box",
        "bag": "bag", "bags": "bag",
        "jar": "jar", "jars": "jar",
        "tub": "tub", "tubs": "tub", "pot": "pot", "pots": "pot",
        "carton": "carton", "cartons": "carton",
        "punnet": "punnet", "punnets": "punnet",
        "loaf": "loaf", "loaves": "loaf",
        "head": "head", "heads": "head",
        "clove": "clove", "cloves": "clove",
        "slice": "slice", "slices": "slice",
        "roll": "roll", "rolls": "roll",
        "sachet": "sachet", "sachets": "sachet",
        "tube": "tube", "tubes": "tube",
        "block": "block", "blocks": "block",
        "piece": "piece", "pieces": "piece",
        "bar": "bar", "bars": "bar",
    ]

    static let wordNumbers: [String: Double] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
        "twelve": 12, "couple": 2,
    ]

    // Only sizes, and only ahead of a container: "large tub of yoghurt".
    static let sizes: Set<String> = ["large", "small", "medium", "big", "little", "jumbo", "mini"]

    public static func parse(_ input: String) -> ParsedQuantity {
        let raw = input.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !raw.isEmpty else { return ParsedQuantity(quantity: nil, unit: nil, rest: "") }

        let lower = raw.map { $0.lowercased() }
        let token = { (i: Int) -> String in i < lower.count ? lower[i] : "" }

        var i = 0
        var quantity: Double?
        var unit: String?

        if token(i) == "half" {
            quantity = 0.5
            i += 1
            if token(i) == "a" || token(i) == "an" { i += 1 }
        }

        if quantity == nil, let n = number(from: token(i)) {
            quantity = n
            i += 1
        } else if quantity == nil, let (n, attached) = attachedUnit(from: token(i)) {
            quantity = n
            unit = attached
            i += 1
        } else if quantity == nil, let n = wordNumbers[token(i)], raw.count > 1 {
            quantity = n
            i += 1
            if token(i) == "of" { i += 1 }
        }

        if unit == nil, sizes.contains(token(i)), units[token(i + 1)] != nil { i += 1 }

        if unit == nil, let canonical = units[token(i)] {
            unit = canonical
            i += 1
            if quantity == nil { quantity = 1 }   // "carton of milk" is one carton
        }

        if unit != nil, token(i) == "of" { i += 1 }

        let rest = raw[i...].joined(separator: " ")
        // Never consume the whole input: a bare "loaf" or "dozen" IS the item.
        if rest.isEmpty {
            return ParsedQuantity(quantity: nil, unit: nil, rest: raw.joined(separator: " "))
        }
        return ParsedQuantity(quantity: quantity, unit: unit, rest: rest)
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
