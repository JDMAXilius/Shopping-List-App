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

    func testAMonthWithNothingInItTotalsNothing() {
        let month = PriceDerivation.month(observations: [], receipts: [], shops: shops,
                                          catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertFalse(month.summary.hasPricedItems)
        XCTAssertNil(month.deltaText)
        XCTAssertEqual(PriceDerivation.figure(month.summary), "—")
    }

    func testAnOlderMonthCarriesTheApproximationItsDecayEarned() throws {
        // Four months back every observation has demoted itself, so that bar can only be `≈`.
        let old = days(120)
        let month = PriceDerivation.month(
            observations: [observation(400, shopA, now), observation(200, shopA, old)],
            receipts: [], shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        let bar = try XCTUnwrap(month.bars.first { !$0.isCurrent })
        XCTAssertTrue(bar.summary.isApproximate)
        XCTAssertTrue(PriceDerivation.figure(bar.summary).hasPrefix("≈"))
        // …and it is not mixed into this month's figure.
        XCTAssertEqual(month.summary.total.minorUnits, 400)
    }

    func testTheMonthSaysHowMuchOfItATillPrinted() {
        let month = PriceDerivation.month(
            observations: [observation(400, shopA, now), observation(250, shopA, now, .manual)],
            receipts: [], shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertEqual(month.fromReceipts, 1)
        XCTAssertEqual(month.summary.measuredCount, 2)
    }

    func testTheAislesOfAMonthAddUpToTheMonth() {
        let month = PriceDerivation.month(
            observations: [observation(400, shopA, now), observation(250, shopB, now)],
            receipts: [], shops: shops, catalog: catalog, currencyCode: "USD", now: now)
        XCTAssertEqual(month.aisles.reduce(0) { $0 + $1.summary.total.minorUnits },
                       month.summary.total.minorUnits)
        XCTAssertEqual(month.shops.reduce(0) { $0 + $1.summary.total.minorUnits },
                       month.summary.total.minorUnits)
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

    func testAnEmptyBookSaysSoRatherThanShowingZeroes() throws {
        let (store, _, _) = try makeStore()
        XCTAssertTrue(store.isEmpty)
        XCTAssertFalse(store.hasRecordedPrices)
        XCTAssertEqual(store.stats.priceCount, 0)
        XCTAssertNil(store.stats.receiptShare)
    }
}
