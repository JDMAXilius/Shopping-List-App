// Port of normalize/strip/singularize from data/catalog/resolve.mjs.
// Quirks are load-bearing: the JS is the spec, the golden cases pin it.

import Foundation

public enum Normalizer {
    // The JS QUALIFIERS list pre-sorted longest-first exactly as
    // [...QUALIFIERS].sort((a, b) => b.length - a.length) produces (stable).
    static let qualifiersLongestFirst: [String] = [
        "whole grain", "reduced fat", "store brand", "unsweetened", "free range",
        "free-range", "wholegrain", "unbleached", "sweetened", "fat free",
        "fat-free", "boneless", "skinless", "seedless", "organic", "low fat",
        "low-fat", "non fat", "premium", "generic", "natural", "nonfat",
        "medium", "fresh", "large", "small", "jumbo", "extra", "mini", "ripe",
        "some", "raw", "the", "a",
    ]

    static let irregular: [String: String] = [
        "leaves": "leaf", "loaves": "loaf", "potatoes": "potato",
        "tomatoes": "tomato", "mangoes": "mango", "berries": "berry",
        "cherries": "cherry", "peaches": "peach",
    ]

    /// Lowercase, NFKD, strip combining marks U+0300–U+036F, everything
    /// outside [a-z0-9%-] becomes a space, collapse runs, trim.
    /// Lowercasing happens BEFORE decomposition, as in the JS: "№" → "No"
    /// keeps its capital N and is dropped, yielding "o". Port the quirk.
    public static func normalize(_ text: String) -> String {
        let decomposed = text.lowercased().decomposedStringWithCompatibilityMapping
        var out: [Character] = []
        out.reserveCapacity(decomposed.unicodeScalars.count)
        for scalar in decomposed.unicodeScalars {
            let v = scalar.value
            if (0x300...0x36F).contains(v) { continue }
            let allowed = (0x61...0x7A).contains(v) || (0x30...0x39).contains(v)
                || v == 0x25 || v == 0x2D  // % and -
            if allowed {
                out.append(Character(scalar))
            } else if let last = out.last, last != " " {
                out.append(" ")
            }
        }
        if out.last == " " { out.removeLast() }
        return String(out)
    }

    /// Space-padded, left-to-right non-overlapping replacement per qualifier,
    /// longest first. "organic organic milk" keeps one "organic" — JS
    /// replaceAll consumes the shared space; port the quirk.
    public static func strip(_ text: String) -> String {
        var out = " \(text) "
        for q in qualifiersLongestFirst {
            out = out.replacingOccurrences(of: " \(q) ", with: " ")
        }
        return collapseWhitespace(out)
    }

    public static func singularize(_ w: String) -> String {
        if let s = irregular[w] { return s }
        if w.count <= 3 || w.hasSuffix("ss") || w.hasSuffix("us") { return w }
        if w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
        if w.hasSuffix("oes") { return String(w.dropLast(2)) }
        if w.hasSuffix("shes") || w.hasSuffix("ches") || w.hasSuffix("xes") || w.hasSuffix("zes") {
            return String(w.dropLast(2))
        }
        return w.hasSuffix("s") ? String(w.dropLast()) : w
    }

    /// JS q.split(' ').map(singularize).join(' ') on already-normalized input.
    public static func singularizeWords(_ text: String) -> String {
        text.components(separatedBy: " ").map(singularize).joined(separator: " ")
    }

    static func collapseWhitespace(_ s: String) -> String {
        var out: [Character] = []
        out.reserveCapacity(s.count)
        for ch in s {
            if ch.isWhitespace {
                if let last = out.last, last != " " { out.append(" ") }
            } else {
                out.append(ch)
            }
        }
        if out.last == " " { out.removeLast() }
        return String(out)
    }
}
