// Port of resolve() from data/catalog/resolve.mjs. Same inputs → same
// outputs, pinned by the 23 golden cases. Stage order, tie-breaks and
// insertion-order stability all mirror the JS exactly.

import Foundation

public struct CatalogMatch: Sendable, Equatable {
    public enum Via: String, Sendable {
        case exact, prefix, fuzzy
    }

    public let id: Int64
    public let canonicalName: String
    public let parentConcept: String?
    public let categoryID: String
    public let emoji: String?
    public let defaultUnit: String?
    public let baseAmount: Double?
    public let score: Double
    public let via: Via

    public init(
        id: Int64, canonicalName: String, parentConcept: String?, categoryID: String,
        emoji: String?, defaultUnit: String?, baseAmount: Double?, score: Double, via: Via
    ) {
        self.id = id
        self.canonicalName = canonicalName
        self.parentConcept = parentConcept
        self.categoryID = categoryID
        self.emoji = emoji
        self.defaultUnit = defaultUnit
        self.baseAmount = baseAmount
        self.score = score
        self.via = via
    }
}

private let exactSQL = """
    SELECT i.id, i.canonical_name, i.parent_concept, i.category_id, i.emoji,
           i.default_unit, lt.weight, ps.base_amount
      FROM lookup_term lt
      JOIN item i ON i.id = lt.item_id
      LEFT JOIN price_seed ps ON ps.item_id = i.id
     WHERE lt.term = ?
    """

private let prefixSQL = """
    SELECT i.id, i.canonical_name, i.parent_concept, i.category_id, i.emoji,
           i.default_unit, lt.term, ps.base_amount
      FROM lookup_term lt
      JOIN item i ON i.id = lt.item_id
      LEFT JOIN price_seed ps ON ps.item_id = i.id
     WHERE lt.term LIKE ? OR lt.term LIKE ? LIMIT 60
    """

private let detailSQL = """
    SELECT i.id, i.canonical_name, i.parent_concept, i.category_id, i.emoji,
           i.default_unit, ps.base_amount
      FROM item i LEFT JOIN price_seed ps ON ps.item_id = i.id WHERE i.id = ?
    """

public func resolve(db: CatalogDatabase, query: String, limit: Int = 6) throws -> [CatalogMatch] {
    let q = Normalizer.normalize(query)
    if q.isEmpty { return [] }

    // term → penalty, insertion-ordered; a repeat term keeps its slot and
    // only lowers its penalty (JS Map semantics).
    var variants: [(term: String, penalty: Double)] = []
    func consider(_ t: String, _ p: Double) {
        guard !t.isEmpty else { return }
        if let i = variants.firstIndex(where: { $0.term == t }) {
            if variants[i].penalty > p { variants[i].penalty = p }
        } else {
            variants.append((t, p))
        }
    }
    consider(q, 0)
    consider(Normalizer.singularizeWords(q), 1)
    consider(Normalizer.strip(q), 2)
    consider(Normalizer.strip(Normalizer.singularizeWords(q)), 2)

    // item id → best-scored match; first insertion fixes the position and
    // ties keep the earlier row, matching JS `prev.score > score`.
    var order: [Int64] = []
    var hits: [Int64: CatalogMatch] = [:]
    func record(_ match: CatalogMatch) {
        if let prev = hits[match.id] {
            if prev.score > match.score { hits[match.id] = match }
        } else {
            hits[match.id] = match
            order.append(match.id)
        }
    }

    for (term, penalty) in variants {
        for row in try db.rows(exactSQL, bind: [.text(term)]) {
            guard let weight = row[6].doubleValue else { continue }
            record(match(row: row, score: weight + penalty, via: .exact))
        }
    }

    // Prefix match on any word boundary, not just the start of the term:
    // "oat" must reach "oat milk", "mince" must reach "beef mince".
    if hits.count < limit {
        for row in try db.rows(prefixSQL, bind: [.text("\(q)%"), .text("% \(q)%")]) {
            guard let term = row[6].textValue else { continue }
            // Starts-with beats matches-a-later-word.
            let score: Double = term.hasPrefix(q) ? 4 : 4.5
            record(match(row: row, score: score, via: .prefix))
        }
    }

    // Typo fallback: only when nothing else matched, and only on short queries.
    if hits.isEmpty && q.utf16.count >= 4 && q.components(separatedBy: " ").count <= 3 {
        let threshold = q.utf16.count <= 6 ? 1 : 2
        var near: [(d: Int, index: Int, itemID: Int64)] = []
        for row in try db.rows("SELECT term, item_id FROM lookup_term WHERE weight <= 1") {
            guard let term = row[0].textValue, let itemID = row[1].integerValue else { continue }
            let d = editDistance(q, term)
            if d <= threshold { near.append((d, near.count, itemID)) }
        }
        near.sort { $0.d != $1.d ? $0.d < $1.d : $0.index < $1.index }
        for candidate in near.prefix(limit) {
            if hits[candidate.itemID] != nil { continue }
            guard let row = try db.rows(detailSQL, bind: [.integer(candidate.itemID)]).first else { continue }
            record(match(row: row, score: 5 + Double(candidate.d), via: .fuzzy))
        }
    }

    // Stable sort: score, then canonical-name length, then hit insertion
    // order — exactly the JS stable Array.prototype.sort.
    let ranked = order.compactMap { hits[$0] }
    return Array(
        ranked.enumerated()
            .sorted { l, r in
                if l.element.score != r.element.score { return l.element.score < r.element.score }
                let ln = l.element.canonicalName.utf16.count
                let rn = r.element.canonicalName.utf16.count
                if ln != rn { return ln < rn }
                return l.offset < r.offset
            }
            .map(\.element)
            .prefix(limit)
    )
}

// Columns 0–5 are shared by all three SELECTs; base_amount sits at index 7
// for exact/prefix (weight/term at 6) and index 6 for the fuzzy detail.
private func match(row: [SQLiteValue], score: Double, via: CatalogMatch.Via) -> CatalogMatch {
    let baseIndex = row.count == 8 ? 7 : 6
    return CatalogMatch(
        id: row[0].integerValue ?? 0,
        canonicalName: row[1].textValue ?? "",
        parentConcept: row[2].textValue,
        categoryID: row[3].textValue ?? "",
        emoji: row[4].textValue,
        defaultUnit: row[5].textValue,
        baseAmount: row[baseIndex].doubleValue,
        score: score,
        via: via
    )
}
