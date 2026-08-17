import Core
import Data
import DesignKit
import Foundation

struct PriceBookEntry: Identifiable, Hashable {
    let itemID: ItemID
    let name: String
    let category: CategoryGlyph
    let price: PriceDisplay
    /// "Trader Joe's · 2 weeks ago" — where it came from and how long ago, in words.
    let detail: String
    /// nil for an item carrying nothing but the catalog's estimate: nothing was observed.
    let observedAt: Date?
    var id: ItemID { itemID }
}

struct PriceBookAisle: Identifiable {
    let category: CategoryGlyph
    let title: String
    let entries: [PriceBookEntry]
    var id: String { category.rawValue }
}

struct PriceBookStats: Hashable {
    let priceCount: Int
    let fromReceipts: Int
    let shopCount: Int

    /// nil, not 0% — with nothing recorded there is no share to state.
    var receiptShare: Int? {
        guard priceCount > 0 else { return nil }
        return Int((Double(fromReceipts) / Double(priceCount) * 100).rounded())
    }
}

struct ReceiptRow: Identifiable, Hashable {
    let id: UUID
    let title: String
    let detail: String
    let total: Money
    /// False when the till's total was never read: the money shown is then what THIS RECEIPT
    /// wrote into the price book, which is not what the shop charged.
    let isPrinted: Bool
}

struct HistoryEntry: Identifiable, Hashable {
    let index: Int
    let price: PriceDisplay
    /// "Trader Joe's · 2 weeks ago · from a receipt" — a receipt and a typed line are not
    /// the same claim, so the row says which one it is.
    let detail: String
    /// Against the previous observation AT THE SAME SHOP. A different shop is a different
    /// shop, not a price change.
    let delta: String?
    let note: String?
    var id: Int { index }
}

struct ShopComparison: Identifiable, Hashable {
    let shopName: String
    let price: PriceDisplay
    let detail: String
    var id: String { shopName }
}

struct ItemHistory {
    let name: String
    let category: CategoryGlyph
    let headline: PriceDisplay
    let headlineDetail: String
    let entries: [HistoryEntry]
    let shops: [ShopComparison]
}

/// A month's spend, one bar. Receipt totals — the same quantity as the headline, so the
/// chart and the number on top of it cannot mean two different things.
struct MonthBar: Identifiable {
    let label: String
    let paid: PaidSummary
    let isCurrent: Bool
    var id: String { label }
}

/// One aisle's share of the lines that COULD be matched to items — not a share of spend.
/// Carries the summary it was derived from, so its figure and its `≈` can never disagree.
struct MonthGroup: Identifiable {
    let title: String
    let summary: PriceSummary
    let tint: Palette.RGB?
    var id: String { title }
}

/// What one shop rang up this month, from that shop's receipts.
struct ShopSpend: Identifiable {
    let title: String
    let paid: PaidSummary
    var id: String { title }
}

struct MonthSpend {
    let title: String
    /// THE number. Receipt totals: what the tills printed, including the tax, bag fees and
    /// deposits no per-item price knows about (W7-P3 ruling 1).
    let paid: PaidSummary
    /// The lines we could match to items — a different quantity from `paid`, and never
    /// presented as the month's spend. It feeds the aisle breakdown only.
    let matched: PriceSummary
    /// How many of those matched lines a till printed. The rest were typed or set by hand.
    let matchedFromReceipts: Int
    /// How the two relate, in words: what the breakdown covers of what was paid.
    let coverageText: String
    /// Δ against the user's own usual month, day for day, on receipt totals. nil when there
    /// is no earlier month to compare with — a first month has no usual.
    let deltaText: String?
    let bars: [MonthBar]
    let aisles: [MonthGroup]
    let shops: [ShopSpend]
}

// Pure view-state assembly over the observations the store already holds: what a price
// means, when it happened, and what a month of them adds up to. No SwiftUI, no database.
@MainActor
enum PriceDerivation {

    // MARK: - The book

    /// Every item this kitchen has paid for — its newest observation, rendered at whatever
    /// tier `confidence` says today — plus items on the list carrying only a seeded estimate.
    /// `unnamed` counts ids the name order could not answer for: they are dropped, never
    /// shown as a UUID.
    static func book(observations: [PriceObservation], items: [ListItem],
                     names: [ItemID: String], shops: [ShopID: String],
                     catalog: ListCatalog, now: Date) -> (entries: [PriceBookEntry], unnamed: Int) {
        let newest = latest(observations)
        let listNames = PriceDerivation.names(of: items)  // `names` param shadows the helper
        var entries: [PriceBookEntry] = []
        var unnamed = 0
        for (itemID, observation) in newest {
            guard let name = name(itemID, names, listNames, catalog) else {
                unnamed += 1
                continue
            }
            let parts = [shops[observation.shopID], recency(observation.date, asOf: now)]
            entries.append(PriceBookEntry(
                itemID: itemID, name: name, category: catalog.category(for: itemID),
                price: PriceDisplay(amount: observation.amount,
                                    confidence: observation.confidence(asOf: now)),
                detail: parts.compactMap { $0 }.joined(separator: " · "),
                observedAt: observation.date))
        }
        var seen = Set(newest.keys)
        for item in items {
            guard let itemID = item.itemID, seen.insert(itemID).inserted,
                  let estimate = catalog.estimate(for: itemID) else { continue }
            guard let name = name(itemID, names, listNames, catalog) else {
                unnamed += 1
                continue
            }
            entries.append(PriceBookEntry(
                itemID: itemID, name: name, category: catalog.category(for: itemID),
                price: .estimated(estimate), detail: "estimate · no receipt yet",
                observedAt: nil))
        }
        return (entries.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
                unnamed)
    }

    /// Naming is not this file's job: the order lives in `ListCatalog.displayName`. There is no
    /// raw text to fall back to in a price book, so an empty answer is a bug the caller counts.
    static func name(_ itemID: ItemID, _ kitchenNames: [ItemID: String],
                     _ listNames: [ItemID: String], _ catalog: ListCatalog) -> String? {
        let name = catalog.displayName(for: itemID, kitchenNames: kitchenNames,
                                       listName: listNames[itemID], fallback: "")
        return name.isEmpty ? nil : name
    }

    static func names(of items: [ListItem]) -> [ItemID: String] {
        var names: [ItemID: String] = [:]
        for item in items {
            guard let itemID = item.itemID else { continue }
            names[itemID] = item.name
        }
        return names
    }

    static func filter(_ entries: [PriceBookEntry], query: String) -> [PriceBookEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.name.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Grouped into the same aisles, in the same order, as the list — the two screens are
    /// one app or the walk order means nothing.
    static func aisles(_ entries: [PriceBookEntry], order: [CategoryID],
                       catalog: ListCatalog) -> [PriceBookAisle] {
        var grouped: [CategoryGlyph: [PriceBookEntry]] = [:]
        for entry in entries { grouped[entry.category, default: []].append(entry) }
        return grouped.keys.sorted { rank($0, order, catalog) < rank($1, order, catalog) }
            .compactMap { category in
                guard let group = grouped[category] else { return nil }
                return PriceBookAisle(category: category, title: catalog.name(for: category),
                                      entries: group)
            }
    }

    static func recent(_ entries: [PriceBookEntry], limit: Int = 5) -> [PriceBookEntry] {
        entries.compactMap { entry in entry.observedAt.map { ($0, entry) } }
            .sorted { $0.0 > $1.0 }.prefix(limit).map(\.1)
    }

    static func stats(_ observations: [PriceObservation]) -> PriceBookStats {
        PriceBookStats(
            priceCount: observations.count,
            fromReceipts: observations.filter { $0.source == .receipt }.count,
            shopCount: Set(observations.map(\.shopID)).count)
    }

    static func receiptRows(_ receipts: [Receipt], shops: [ShopID: String],
                            currencyCode: String, now: Date, limit: Int = 4) -> [ReceiptRow] {
        receipts.sorted { $0.capturedAt > $1.capturedAt }.prefix(limit).map { receipt in
            let lines = "\(receipt.lineCount) line\(receipt.lineCount == 1 ? "" : "s")"
            let printed = receipt.totalMinor
            let detail = "\(recency(receipt.capturedAt, asOf: now)) · \(lines)"
            return ReceiptRow(
                id: receipt.id, title: shops[receipt.shopID] ?? "A shop",
                detail: printed == nil ? "\(detail) · total not read" : detail,
                total: Money(minorUnits: printed ?? receipt.recordedMinor ?? 0,
                             currencyCode: currencyCode),
                isPrinted: printed != nil)
        }
    }

    // MARK: - One item over time

    /// nil only when no name can be found for the id — the screen says so rather than
    /// heading a page with a UUID.
    static func history(for itemID: ItemID, observations: [PriceObservation],
                        names: [ItemID: String], listNames: [ItemID: String],
                        shops: [ShopID: String],
                        catalog: ListCatalog, now: Date) -> ItemHistory? {
        guard let name = name(itemID, names, listNames, catalog) else { return nil }
        let mine = observations.filter { $0.itemID == itemID }.sorted { $0.date > $1.date }
        var entries: [HistoryEntry] = []
        var demotionNoted = false
        for (index, observation) in mine.enumerated() {
            let confidence = observation.confidence(asOf: now)
            let demoted = confidence == .estimate
            let parts = [shops[observation.shopID], recency(observation.date, asOf: now),
                         source(observation.source)]
            entries.append(HistoryEntry(
                index: index,
                price: PriceDisplay(amount: observation.amount, confidence: confidence),
                detail: parts.compactMap { $0 }.joined(separator: " · "),
                delta: delta(for: observation, before: index, in: mine, asOf: now),
                // Marked once, on the newest demoted row: that row IS the 90-day boundary.
                note: demoted && !demotionNoted ? "over 90 days old — an estimate again from here"
                                                : nil))
            demotionNoted = demotionNoted || demoted
        }
        let headline = mine.first.map {
            PriceDisplay(amount: $0.amount, confidence: $0.confidence(asOf: now))
        } ?? catalog.estimate(for: itemID).map(PriceDisplay.estimated) ?? .none
        return ItemHistory(
            name: name, category: catalog.category(for: itemID), headline: headline,
            headlineDetail: entries.first?.detail ?? "no receipt yet",
            entries: entries, shops: comparison(mine, shops: shops, now: now))
    }

    /// One row per shop, newest first: the same item at two shops is the comparison people
    /// actually want.
    private static func comparison(_ observations: [PriceObservation], shops: [ShopID: String],
                                   now: Date) -> [ShopComparison] {
        guard Set(observations.map(\.shopID)).count > 1 else { return [] }
        var newest: [ShopID: PriceObservation] = [:]
        var counts: [ShopID: Int] = [:]
        for observation in observations {
            counts[observation.shopID, default: 0] += 1
            if (newest[observation.shopID]?.date ?? .distantPast) < observation.date {
                newest[observation.shopID] = observation
            }
        }
        return newest.values.sorted { $0.date > $1.date }.map { observation in
            let count = counts[observation.shopID] ?? 1
            return ShopComparison(
                shopName: shops[observation.shopID] ?? "A shop",
                price: PriceDisplay(amount: observation.amount,
                                    confidence: observation.confidence(asOf: now)),
                detail: "\(count) price\(count == 1 ? "" : "s") · \(recency(observation.date, asOf: now))")
        }
    }

    /// A fact, never a judgement: what changed since the last time this shop rang it up.
    private static func delta(for observation: PriceObservation, before index: Int,
                              in newestFirst: [PriceObservation], asOf now: Date) -> String? {
        let earlier = newestFirst.dropFirst(index + 1).first {
            $0.shopID == observation.shopID
                && $0.amount.currencyCode == observation.amount.currencyCode
        }
        guard let earlier else { return nil }
        let when = recency(earlier.date, asOf: now)
        let change = observation.amount.minorUnits - earlier.amount.minorUnits
        guard change != 0 else { return "same as \(when)" }
        let money = Money(minorUnits: change, currencyCode: observation.amount.currencyCode)
        return "\(change > 0 ? "+" : "")\(money.display) vs \(when)"
    }

    // MARK: - A month

    /// A month's spend is the sum of its RECEIPTS — the tills' own totals, tax and fees and
    /// unmatched lines included. The observations feed the aisle breakdown and nothing else:
    /// they are the value of the lines we could match, counted at what was bought, which is a
    /// different number from what was paid even when the two happen to land on each other.
    static func month(observations: [PriceObservation], receipts: [Receipt],
                      shops: [ShopID: String], catalog: ListCatalog,
                      currencyCode: String, now: Date) -> MonthSpend {
        let calendar = Calendar.current
        let title = Self.monthTitle.string(from: now)
        let thisMonthReceipts = receipts.filter {
            calendar.isDate($0.capturedAt, equalTo: now, toGranularity: .month)
        }
        let paid = PaidSummary(totals(thisMonthReceipts, currencyCode: currencyCode),
                               in: title, currencyCode: currencyCode,
                               unread: unreadTotals(thisMonthReceipts))

        let thisMonth = observations.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        let matched = PriceSummary(lines(thisMonth, asOf: now))
        var aisles: [CategoryGlyph: [PriceLine]] = [:]
        for observation in thisMonth {
            aisles[catalog.category(for: observation.itemID), default: []]
                .append(line(observation, asOf: now))
        }
        let aisleGroups = aisles.map { category, displays in
            MonthGroup(title: catalog.name(for: category), summary: PriceSummary(displays),
                       tint: category.tint)
        }
        var byShop: [ShopID: [Receipt]] = [:]
        for receipt in thisMonthReceipts { byShop[receipt.shopID, default: []].append(receipt) }
        let shopSpend = byShop.map { shopID, theirs in
            ShopSpend(title: shops[shopID] ?? "A shop",
                      paid: PaidSummary(totals(theirs, currencyCode: currencyCode),
                                        in: title, currencyCode: currencyCode))
        }
        return MonthSpend(
            title: title,
            paid: paid,
            matched: matched,
            matchedFromReceipts: thisMonth.filter { $0.source == .receipt }.count,
            coverageText: coverage(paid: paid, matched: matched,
                                   uncounted: thisMonth.filter { !$0.hasRecordedQuantity }.count),
            deltaText: deltaVsUsual(receipts, paid: paid, currencyCode: currencyCode, now: now),
            bars: bars(receipts, current: paid, currencyCode: currencyCode, now: now),
            aisles: ranked(aisleGroups),
            shops: shopSpend.filter(\.paid.hasReceipts)
                .sorted { $0.paid.total.minorUnits > $1.paid.total.minorUnits })
    }

    /// Only a printed total can be spent. A receipt whose total was never read is left OUT —
    /// summing what we happened to match would understate the month while looking complete.
    private static func totals(_ receipts: [Receipt], currencyCode: String) -> [ReceiptTotal] {
        receipts.compactMap { receipt in
            receipt.totalMinor.map {
                ReceiptTotal(printedOnReceipt: Money(minorUnits: $0, currencyCode: currencyCode))
            }
        }
    }

    /// Captured trips whose total was never read, so the screen can say what it left out.
    static func unreadTotals(_ receipts: [Receipt]) -> Int {
        receipts.filter { $0.totalMinor == nil }.count
    }

    /// How the breakdown relates to the money paid — stated, not left for the user to notice
    /// that the aisle rows don't add up to the headline. They can't: tax has no aisle.
    ///
    /// `uncounted` is how many of the matched observations carry no count. Each of those is
    /// worth one here, so with any present the gap is not only tax and this must not say it is —
    /// that was the confidently wrong sentence a ×4 receipt used to produce.
    static func coverage(paid: PaidSummary, matched: PriceSummary, uncounted: Int) -> String {
        guard matched.hasPricedItems else {
            return "No prices from \(paid.period) are matched to items yet."
        }
        guard paid.hasReceipts else {
            return "These prices were recorded by hand. Without a receipt none of it can be "
                + "called what the month cost."
        }
        guard matched.total.minorUnits <= paid.total.minorUnits else {
            return "\(figure(matched)) is matched to items — more than the receipts add up to, "
                + "because some of it was recorded without a receipt."
        }
        let head = "\(figure(matched)) of the \(paid.figure) is matched to items."
        let short = matched.total.minorUnits < paid.total.minorUnits
        guard uncounted > 0 else {
            guard short else {
                return "\(figure(matched)) is matched to items — all of the \(paid.figure)."
            }
            return head + " The rest is tax, deposits, fees and lines nothing could be matched to."
        }
        let caveat = uncounted == 1
            ? " 1 of those prices was recorded before quantities were, and counts as one"
            : " \(uncounted) of those prices were recorded before quantities were, and count "
                + "as one each"
        guard short else { return head + caveat + "." }
        return head + caveat + ", so the rest is not only tax, deposits, fees and lines nothing "
            + "could be matched to."
    }

    /// Biggest first, and nothing that carries no money at all.
    private static func ranked(_ groups: [MonthGroup]) -> [MonthGroup] {
        groups.filter(\.summary.hasPricedItems)
            .sorted { $0.summary.total.minorUnits > $1.summary.total.minorUnits }
    }

    /// `—` for a figure with nothing behind it: a `$0.00` month is a claim about spending.
    /// `≈` is never caller-supplied — the summary decides it.
    static func figure(_ summary: PriceSummary) -> String {
        guard summary.hasPricedItems else { return "—" }
        return (summary.isApproximate ? "≈ " : "") + summary.total.display
    }

    /// Money paid carries no `≈`: every part of it is a till figure. What it can't include is
    /// said in words by `PaidSummary.basis`.
    static func figure(_ paid: PaidSummary) -> String { paid.figure }

    /// The last six months that hold a receipt, this one always last — a bar per month, each
    /// carrying its own summary so no figure is computed twice.
    private static func bars(_ receipts: [Receipt], current: PaidSummary,
                             currencyCode: String, now: Date) -> [MonthBar] {
        let calendar = Calendar.current
        var buckets: [Date: [Receipt]] = [:]
        for receipt in receipts {
            guard let start = calendar.dateInterval(of: .month, for: receipt.capturedAt)?.start,
                  let months = calendar.dateComponents([.month], from: start, to: now).month,
                  months > 0, months <= 5 else { continue }
            buckets[start, default: []].append(receipt)
        }
        let earlier = buckets.keys.sorted().map { start in
            let label = Self.barLabel.string(from: start)
            return MonthBar(
                label: label,
                paid: PaidSummary(totals(buckets[start] ?? [], currencyCode: currencyCode),
                                  in: label, currencyCode: currencyCode),
                isCurrent: false)
        }
        return earlier + [MonthBar(label: Self.barLabel.string(from: now), paid: current,
                                   isCurrent: true)]
    }

    /// Day for day: a month three days into itself is compared with the first three days of
    /// the months before it, never with their totals.
    ///
    /// Both sides are only as complete as the scanning was, so a month with fewer captured
    /// trips than usual would otherwise read as a month that cost less. It says the trip
    /// counts instead — the difference is stated, never explained away.
    private static func deltaVsUsual(_ receipts: [Receipt], paid: PaidSummary,
                                     currencyCode: String, now: Date) -> String? {
        guard paid.hasReceipts else { return nil }
        let calendar = Calendar.current
        let today = calendar.component(.day, from: now)
        var buckets: [Date: (total: Int, trips: Int)] = [:]
        for receipt in receipts {
            guard calendar.component(.day, from: receipt.capturedAt) <= today,
                  let start = calendar.dateInterval(of: .month, for: receipt.capturedAt)?.start,
                  let months = calendar.dateComponents([.month], from: start, to: now).month,
                  months > 0, months <= 6 else { continue }
            // Same exclusion as the headline: a month compared day for day must be built the
            // same way on both sides, or the delta measures the rule and not the spending.
            guard let printed = receipt.totalMinor else { continue }
            let bucket = buckets[start] ?? (0, 0)
            buckets[start] = (bucket.total + printed, bucket.trips + 1)
        }
        guard !buckets.isEmpty else { return nil }
        let usual = buckets.values.reduce(0) { $0 + $1.total } / buckets.count
        let usualTrips = Int((Double(buckets.values.reduce(0) { $0 + $1.trips })
                              / Double(buckets.count)).rounded())
        let change = paid.total.minorUnits - usual
        let money = Money(minorUnits: abs(change), currencyCode: currencyCode)
        let headline = change == 0
            ? "The same as a usual month, day for day."
            : "\(money.display) \(change > 0 ? "more" : "less") than a usual month, day for day."
        guard usualTrips != paid.receiptCount else { return headline }
        return headline + " \(paid.receiptCount) trip\(paid.receiptCount == 1 ? "" : "s") "
            + "captured here against a usual \(usualTrips)."
    }

    // MARK: - Shared

    /// One line per observation, at the count that observation was recorded at: a receipt's ×4
    /// milk is $14.00 here, not $3.50. An observation written before counts existed reports one,
    /// which is what it has always meant — `uncounted` is how the month says so out loud.
    static func lines(_ observations: [PriceObservation], asOf now: Date) -> [PriceLine] {
        observations.map { line($0, asOf: now) }
    }

    private static func line(_ observation: PriceObservation, asOf now: Date) -> PriceLine {
        PriceDisplay(amount: observation.amount, confidence: observation.confidence(asOf: now))
            .line(quantity: observation.quantity)
    }

    static func latest(_ observations: [PriceObservation]) -> [ItemID: PriceObservation] {
        var newest: [ItemID: PriceObservation] = [:]
        for observation in observations
        where (newest[observation.itemID]?.date ?? .distantPast) <= observation.date {
            newest[observation.itemID] = observation
        }
        return newest
    }

    /// How long ago, in words. A date the user has to subtract from today is not an answer.
    static func recency(_ date: Date, asOf now: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2 ... 6: return "\(days) days ago"
        case 7 ... 13: return "last week"
        case 14 ... 29: return "\(days / 7) weeks ago"
        case 30 ... 59: return "last month"
        case 60 ... 364: return "\(days / 30) months ago"
        case 365 ... 729: return "over a year ago"
        default: return "over \(days / 365) years ago"
        }
    }

    /// `.receipt` and `.typed` are not the same claim, so they never read the same.
    static func source(_ source: PriceObservation.Source) -> String {
        switch source {
        case .receipt: return "from a receipt"
        case .typed: return "typed by hand"
        case .manual: return "you set it"
        case .corrected: return "you corrected it"
        }
    }

    private static func rank(_ category: CategoryGlyph, _ order: [CategoryID],
                             _ catalog: ListCatalog) -> Int {
        order.firstIndex(of: CategoryID(category.rawValue)) ?? (1000 + catalog.defaultOrder(category))
    }

    private static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("LLLL")
        return formatter
    }()

    private static let barLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("LLL")
        return formatter
    }()
}
