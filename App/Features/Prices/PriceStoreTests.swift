import Catalog
import Core
import Data
import DesignKit
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class PriceStoreTests: XCTestCase {
    // Fixed currency: the seeded estimates are dollars, so a device in another locale must
    // not decide whether this kitchen has estimates at all.
    private let kitchen = Kitchen(name: "test kitchen", currencyCode: "USD")
    private let shopA = ShopID()
    private let shopB = ShopID()
    private let milk = ItemID()
    private let now = Date()

    private func days(_ count: Double) -> Date { now.addingTimeInterval(-count * 86_400) }

    private func observation(_ minor: Int, _ shopID: ShopID, _ date: Date,
                             _ source: PriceObservation.Source = .receipt,
                             item: ItemID? = nil) -> PriceObservation {
        PriceObservation(itemID: item ?? milk, shopID: shopID, date: date,
                         amount: Money(minorUnits: minor), source: source)
    }

    private var catalog: ListCatalog { ListCatalog(database: nil) }
    private var names: [ItemID: String] { [milk: "Milk"] }
    private var shops: [ShopID: String] { [shopA: "Trader Joe's", shopB: "Walmart"] }

    // MARK: - The three tiers and the 90-day decay

    func testTheBookRendersWhatConfidenceSaysAndNothingElse() {
        let fresh = PriceDerivation.book(
            observations: [observation(449, shopA, days(10))], items: [], names: names,
            shops: shops, catalog: catalog, now: now)
        XCTAssertEqual(fresh.entries.first?.price,
                       PriceDisplay(amount: Money(minorUnits: 449), confidence: .trusted))

        // Past 90 days the observation demotes itself; the book must not out-claim it.
        let stale = PriceDerivation.book(
            observations: [observation(449, shopA, days(120))], items: [], names: names,
            shops: shops, catalog: catalog, now: now)
        XCTAssertEqual(stale.entries.first?.price, .estimated(Money(minorUnits: 449)))
    }

    func testTheNewestObservationIsTheOneShown() {
        let book = PriceDerivation.book(
            observations: [observation(449, shopA, days(30)), observation(519, shopB, days(2))],
            items: [], names: names, shops: shops, catalog: catalog, now: now)
        XCTAssertEqual(book.entries.count, 1)
        XCTAssertEqual(book.entries.first?.price,
                       PriceDisplay(amount: Money(minorUnits: 519), confidence: .trusted))
        XCTAssertEqual(book.entries.first?.detail, "Walmart · 2 days ago")
    }

    /// A UUID is not a name. The row is dropped and counted, so the bug is visible.
    func testAnItemWithNoNameIsCountedNeverRendered() {
        let book = PriceDerivation.book(
            observations: [observation(449, shopA, days(1))], items: [], names: [:],
            shops: shops, catalog: catalog, now: now)
        XCTAssertTrue(book.entries.isEmpty)
        XCTAssertEqual(book.unnamed, 1)
    }

    func testRecencyNeverAsksTheUserToSubtractDates() {
        XCTAssertEqual(PriceDerivation.recency(days(0), asOf: now), "today")
        XCTAssertEqual(PriceDerivation.recency(days(1), asOf: now), "yesterday")
        XCTAssertEqual(PriceDerivation.recency(days(3), asOf: now), "3 days ago")
        XCTAssertEqual(PriceDerivation.recency(days(8), asOf: now), "last week")
        XCTAssertEqual(PriceDerivation.recency(days(21), asOf: now), "3 weeks ago")
        XCTAssertEqual(PriceDerivation.recency(days(45), asOf: now), "last month")
        XCTAssertEqual(PriceDerivation.recency(days(120), asOf: now), "4 months ago")
    }

    func testStatsCountWhatCameFromReceipts()  {
        let stats = PriceDerivation.stats([
            observation(449, shopA, days(1)),
            observation(519, shopB, days(2), .typed),
            observation(399, shopA, days(3), .manual),
            observation(429, shopA, days(4)),
        ])
        XCTAssertEqual(stats.priceCount, 4)
        XCTAssertEqual(stats.shopCount, 2)
        XCTAssertEqual(stats.receiptShare, 50)
        XCTAssertNil(PriceDerivation.stats([]).receiptShare)
    }

    // MARK: - History

    func testDeltaComparesTheSameShopOnly() throws {
        let history = try XCTUnwrap(PriceDerivation.history(
            for: milk,
            observations: [observation(449, shopA, days(30)), observation(519, shopB, days(14)),
                           observation(489, shopA, days(2))],
            names: names, listNames: [:], shops: shops, catalog: catalog, now: now))
        // Newest first: Trader Joe's again, against Trader Joe's own last price.
        XCTAssertEqual(history.entries.first?.delta, "+$0.40 vs last month")
        // Walmart's first price here has nothing at Walmart to compare with.
        XCTAssertNil(history.entries[1].delta)
    }

    func testSourceIsNeverBlurred() throws {
        let history = try XCTUnwrap(PriceDerivation.history(
            for: milk, observations: [observation(449, shopA, days(1), .typed)],
            names: names, listNames: [:], shops: shops, catalog: catalog, now: now))
        XCTAssertEqual(history.entries.first?.detail, "Trader Joe's · yesterday · typed by hand")
    }

    func testTheNinetyDayBoundaryIsMarkedOnceNotOnEveryOldRow() throws {
        let history = try XCTUnwrap(PriceDerivation.history(
            for: milk,
            observations: [observation(449, shopA, days(2)), observation(429, shopA, days(120)),
                           observation(409, shopA, days(200))],
            names: names, listNames: [:], shops: shops, catalog: catalog, now: now))
        XCTAssertNil(history.entries[0].note)
        XCTAssertNotNil(history.entries[1].note)
        XCTAssertNil(history.entries[2].note)
    }

    func testTwoShopsGetTheComparisonOneShopDoesNot() throws {
        let single = try XCTUnwrap(PriceDerivation.history(
            for: milk, observations: [observation(449, shopA, days(1))],
            names: names, listNames: [:], shops: shops, catalog: catalog, now: now))
        XCTAssertTrue(single.shops.isEmpty)

        let both = try XCTUnwrap(PriceDerivation.history(
            for: milk, observations: [observation(449, shopA, days(1)),
                                      observation(519, shopB, days(3))],
            names: names, listNames: [:], shops: shops, catalog: catalog, now: now))
        XCTAssertEqual(both.shops.map(\.shopName), ["Trader Joe's", "Walmart"])
    }

    func testAnUnnamedItemHasNoHistoryPageAtAll() {
        XCTAssertNil(PriceDerivation.history(
            for: milk, observations: [observation(449, shopA, days(1))],
            names: [:], listNames: [:], shops: shops, catalog: catalog, now: now))
    }

    // MARK: - The month

    private var lastMonth: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: now) ?? days(30)
    }

    private func receipt(_ minor: Int, _ shopID: ShopID, _ date: Date,
                         lines: Int = 6) -> Receipt {
        Receipt(shopID: shopID, capturedAt: date, lineCount: lines, totalMinor: minor)
    }

    /// THE ruling (W7-P3 §1). A month's spend is what the tills printed. Summing the price
    /// observations dated in the month states a confidently wrong number — it silently drops
    /// tax, fees, deposits, every unmatched line, and every trip that was never captured.
    /// W7-P2's own example: 12 matched prices worth $62.04 in a month whose receipts say $300.
    func testAMonthTotalIsNotASumOfObservations() {
        let observations = (0 ..< 12).map { _ in observation(517, shopA, now, item: ItemID()) }
        let month = PriceDerivation.month(
            observations: observations, receipts: [receipt(30_000, shopA, now, lines: 41)],
            shops: shops, catalog: catalog, currencyCode: "USD", now: now)

        XCTAssertEqual(month.paid.total, Money(minorUnits: 30_000))
        XCTAssertEqual(PriceDerivation.figure(month.paid), "$300.00")
        // The observations are still derived — as the BREAKDOWN, a different quantity.
        XCTAssertEqual(month.matched.total, Money(minorUnits: 6_204))
        XCTAssertNotEqual(month.matched.total, month.paid.total)
        // And the Prices tab's month link, which reads `month.summary`, states the same
        // number this screen does.
        XCTAssertEqual(month.summary.total, month.paid.total)
    }

    func testTheMonthCountsCapturedTripsAndSaysWhatItCannotInclude() {
        let month = PriceDerivation.month(
            observations: [], receipts: [receipt(12_450, shopA, now), receipt(9_050, shopB, now)],
            shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertEqual(month.paid.receiptCount, 2)
        XCTAssertTrue(month.paid.basis.contains("From 2 receipts captured in \(month.title)"))
        XCTAssertTrue(month.paid.basis.contains("A trip you didn't scan isn't in this number."))
    }

    /// "Says plainly what it cannot" — a month with hand-recorded prices and no receipt has
    /// no spend figure at all, and does not borrow one from the prices.
    func testAMonthWithNoReceiptStatesNoTotalAtAll() {
        let month = PriceDerivation.month(
            observations: [observation(400, shopA, now, .manual),
                           observation(250, shopA, now, .typed, item: ItemID())],
            receipts: [], shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertFalse(month.paid.hasReceipts)
        XCTAssertEqual(PriceDerivation.figure(month.paid), "—")
        XCTAssertNil(month.deltaText)
        XCTAssertTrue(month.shops.isEmpty)
        XCTAssertTrue(month.coverageText.contains("Without a receipt"))
        // The prices are still there to break down; they are simply not called spend.
        XCTAssertEqual(month.matched.total.minorUnits, 650)
    }

    func testAMonthWithNothingInItTotalsNothing() {
        let month = PriceDerivation.month(observations: [], receipts: [], shops: shops,
                                          catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertFalse(month.matched.hasPricedItems)
        XCTAssertFalse(month.paid.hasReceipts)
        XCTAssertNil(month.deltaText)
        XCTAssertEqual(PriceDerivation.figure(month.paid), "—")
    }

    /// The aisle rows cannot add up to the headline — tax has no aisle — so the gap is
    /// stated rather than left for the user to discover by adding the rows up.
    func testTheCoverageSentenceNamesTheGapBetweenPaidAndMatched() {
        let short = PriceDerivation.month(
            observations: [observation(400, shopA, now)], receipts: [receipt(1_000, shopA, now)],
            shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertEqual(short.coverageText,
                       "$4.00 of the $10.00 is matched to items. The rest is tax, deposits, "
                       + "fees and lines nothing could be matched to.")

        // Prices recorded by hand can exceed the receipts. That is not tax — say the truth.
        let over = PriceDerivation.month(
            observations: [observation(400, shopA, now, .manual)],
            receipts: [receipt(100, shopA, now)],
            shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertTrue(over.coverageText.contains("more than the receipts add up to"))
    }

    func testTheMonthSaysHowMuchOfTheBreakdownATillPrinted() {
        let month = PriceDerivation.month(
            observations: [observation(400, shopA, now),
                           observation(250, shopA, now, .manual, item: ItemID())],
            receipts: [receipt(1_000, shopA, now)], shops: shops, catalog: catalog,
            currencyCode: "USD", now: now)
        XCTAssertEqual(month.matchedFromReceipts, 1)
        XCTAssertEqual(month.matched.measuredCount, 2)
    }

    func testTheAislesBreakDownTheMatchedLinesAndTheShopsBreakDownTheSpend() {
        let month = PriceDerivation.month(
            observations: [observation(400, shopA, now),
                           observation(250, shopB, now, item: ItemID())],
            receipts: [receipt(1_200, shopA, now), receipt(800, shopB, now)],
            shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertEqual(month.aisles.reduce(0) { $0 + $1.summary.total.minorUnits },
                       month.matched.total.minorUnits)
        // Shop rows are receipts, so they DO add up to the headline.
        XCTAssertEqual(month.shops.reduce(0) { $0 + $1.paid.total.minorUnits },
                       month.paid.total.minorUnits)
        XCTAssertEqual(month.shops.first?.title, "Trader Joe's")
        XCTAssertEqual(month.shops.first?.paid.figure, "$12.00")
    }

    /// A bar is a month's spend, same as the headline. A month full of observations and no
    /// receipt has no bar to draw — it would draw a number nobody paid.
    func testEveryBarIsAMonthOfReceiptsNotAMonthOfObservations() throws {
        let month = PriceDerivation.month(
            observations: [observation(400, shopA, now), observation(20_000, shopA, lastMonth)],
            receipts: [receipt(9_000, shopA, now), receipt(30_260, shopA, lastMonth)],
            shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        let earlier = try XCTUnwrap(month.bars.first { !$0.isCurrent })
        XCTAssertEqual(earlier.paid.figure, "$302.60")
        XCTAssertEqual(try XCTUnwrap(month.bars.last).paid.figure, "$90.00")

        let noReceipts = PriceDerivation.month(
            observations: [observation(20_000, shopA, lastMonth)], receipts: [],
            shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertEqual(noReceipts.bars.count, 1)
        XCTAssertTrue(noReceipts.bars[0].isCurrent)
    }

    func testTheDeltaComparesWhatWasPaidDayForDay() {
        let month = PriceDerivation.month(
            observations: [], receipts: [receipt(9_000, shopA, now),
                                         receipt(10_800, shopA, lastMonth)],
            shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertEqual(month.deltaText, "$18.00 less than a usual month, day for day")
        // A fact, not a judgement: no colour word, no praise, no scolding.
        for word in ["good", "great", "under", "over budget", "saved", "🎉"] {
            XCTAssertFalse(month.deltaText?.contains(word) ?? false)
        }
    }

    // MARK: - The store

    private func makeStore() throws -> (PriceStore, ListStore, Repository) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("price-store-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        let repository = try Repository(database: database)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(UUID().uuidString)"))
        let catalog = ListCatalog(database: try CatalogDatabase.bundled(),
                                  currencyCode: kitchen.currencyCode)
        let list = try ListStore(repository: repository, kitchenID: kitchen.id, catalog: catalog,
                                 defaults: defaults)
        let store = try PriceStore(repository: repository, kitchen: kitchen, catalog: catalog,
                                   list: list)
        return (store, list, repository)
    }

    func testAPriceRecordedOnTheListReachesTheBook() throws {
        let (store, list, _) = try makeStore()
        list.addShop(named: "Trader Joe's")
        list.add(text: "milk")
        list.setPrice(try XCTUnwrap(list.rows.first).item, Money(minorUnits: 449))
        store.refresh()

        let entry = try XCTUnwrap(store.aisles.flatMap(\.entries)
            .first { $0.name.localizedCaseInsensitiveContains("milk") })
        XCTAssertEqual(entry.price, PriceDisplay(amount: Money(minorUnits: 449),
                                                 confidence: .trusted))
        XCTAssertEqual(entry.detail, "Trader Joe's · today")
        XCTAssertEqual(store.unnamedCount, 0)
        XCTAssertTrue(store.hasRecordedPrices)
    }

    func testSearchFindsOneItemInABookFullOfThem() throws {
        let (store, list, _) = try makeStore()
        list.addShop(named: "Trader Joe's")
        for name in ["milk", "bananas", "coffee"] { list.add(text: name) }
        store.refresh()

        store.query = "bana"
        XCTAssertEqual(store.aisles.flatMap(\.entries).count, 1)
        // A search asks a question the recency list does not answer.
        XCTAssertTrue(store.recent.isEmpty)
        store.query = "zzz"
        XCTAssertTrue(store.aisles.isEmpty)
    }

    /// End to end: the till total in the database is the number the month screen states, and
    /// a price recorded by hand on the list does not move it.
    func testTheMonthOnTheStoreIsTheReceiptsInTheDatabase() throws {
        let (store, list, repository) = try makeStore()
        list.addShop(named: "Trader Joe's")
        let shopID = try XCTUnwrap(list.activeShopID)
        list.add(text: "milk")
        list.setPrice(try XCTUnwrap(list.rows.first).item, Money(minorUnits: 449))
        try repository.saveReceipt(Receipt(shopID: shopID, capturedAt: Date(), lineCount: 23,
                                           totalMinor: 8_412))
        store.refresh()

        XCTAssertEqual(store.month.paid.total, Money(minorUnits: 8_412))
        XCTAssertEqual(store.month.paid.receiptCount, 1)
        // The $4.49 is in the breakdown, not in the total.
        XCTAssertEqual(store.month.matched.total, Money(minorUnits: 449))
    }

    func testAnEmptyBookSaysSoRatherThanShowingZeroes() throws {
        let (store, _, _) = try makeStore()
        XCTAssertTrue(store.isEmpty)
        XCTAssertFalse(store.hasRecordedPrices)
        XCTAssertEqual(store.stats.priceCount, 0)
        XCTAssertNil(store.stats.receiptShare)
    }
}
