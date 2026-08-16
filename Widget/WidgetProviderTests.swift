import Core
import Data
import DesignKit
import Foundation
import XCTest

/// Four honest states, one ordering rule, and a tile that never claims a price it does not hold.
final class WidgetProviderTests: XCTestCase {
    private let shopID = ShopID()

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-provider-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func snapshot(_ items: [ListItem], _ observations: [PriceObservation] = [],
                          shopID: ShopID? = nil, limit: Int = 3) -> WidgetList {
        WidgetSnapshot.list(items: items, observations: observations,
                            shopID: shopID ?? self.shopID, limit: limit)
    }

    // MARK: - The four states

    func testAnAbsentDatabaseIsSaidPlainlyAndNeverCreated() throws {
        let url = try temporaryDirectory().appendingPathComponent("bagged.sqlite")
        let (access, connection) = WidgetStore.connect(url)
        guard case .unreachable = access else { return XCTFail("no file means nothing to read") }
        XCTAssertNil(connection)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path),
                       "the widget made a database the app would have to live with")
    }

    func testADatabaseWithNoKitchenSaysSoRatherThanShowingAList() throws {
        let url = try temporaryDirectory().appendingPathComponent("bagged.sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        guard case .noKitchen = WidgetStore.connect(url).0 else {
            return XCTFail("no kitchen row is its own state")
        }
    }

    func testAnEmptyListIsAListNotAFailure() throws {
        let url = try temporaryDirectory().appendingPathComponent("bagged.sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        try Repository(database: database).saveKitchen(Kitchen(name: "Home"))

        let state = WidgetProvider.state(WidgetStore.connect(url).0, shopID: nil, limit: 3)
        guard case .list(let list) = state else { return XCTFail("a kitchen with no rows is a list") }
        XCTAssertEqual(list.total, 0)
        XCTAssertEqual(list.remaining, 0)
    }

    func testAVersionMismatchRendersNoRowsAtAll() {
        guard case .needsApp = WidgetProvider.state(.needsApp, shopID: nil, limit: 3) else {
            return XCTFail("a mismatch must not resolve to rows")
        }
    }

    // MARK: - What the tile shows

    func testCheckedRowsSinkExactlyAsTheyDoInTheApp() {
        let items = [ListItem(name: "Bananas", checked: true), ListItem(name: "Oat milk"),
                     ListItem(name: "Eggs")]
        let list = snapshot(items, limit: 3)
        XCTAssertEqual(list.rows.map(\.name), ["Oat milk", "Eggs", "Bananas"])
        XCTAssertEqual(list.remaining, 2)
        XCTAssertEqual(list.total, 3)
    }

    func testTheTileSaysHowManyMoreThereAre() {
        let items = (1...7).map { ListItem(name: "Item \($0)") }
        let small = snapshot(items, limit: 2)
        XCTAssertEqual(small.rows.count, 2)
        XCTAssertEqual(small.hidden, 5)
        XCTAssertEqual(snapshot(items, limit: 3).hidden, 4)
        // Nothing hidden is nothing claimed hidden.
        XCTAssertEqual(snapshot(Array(items.prefix(2)), limit: 3).hidden, 0)
    }

    // MARK: - The tiers

    func testAMeasuredPriceAtThisShopIsTheOnlyThingThatCountsAsMeasured() {
        let item = ListItem(itemID: ItemID(), name: "Bananas")
        let observation = PriceObservation(itemID: item.itemID!, shopID: shopID, date: Date(),
                                           amount: Money(minorUnits: 449), source: .receipt)
        let summary = snapshot([item], [observation]).summary
        XCTAssertEqual(summary.measuredCount, 1)
        XCTAssertEqual(summary.unpricedCount, 0)
        XCTAssertFalse(summary.isApproximate, "nothing estimated, nothing missing, no ≈")
        XCTAssertEqual(summary.total, Money(minorUnits: 449))
    }

    func testAnotherShopsPriceIsNotThisShopsPrice() {
        let item = ListItem(itemID: ItemID(), name: "Bananas")
        let elsewhere = PriceObservation(itemID: item.itemID!, shopID: ShopID(), date: Date(),
                                         amount: Money(minorUnits: 449), source: .receipt)
        let summary = snapshot([item], [elsewhere]).summary
        XCTAssertEqual(summary.measuredCount, 0)
        XCTAssertEqual(summary.unpricedCount, 1)
        XCTAssertTrue(summary.isApproximate)
        XCTAssertFalse(summary.hasPricedItems, "the tile shows `—`, not a price from another shop")
    }

    /// Past 90 days Core demotes an observation to an estimate. The tile must demote with it —
    /// a stale price rendering as measured is the one thing a glanced-at surface cannot do.
    func testAPriceOlderThanNinetyDaysCannotRenderAsMeasured() {
        let item = ListItem(itemID: ItemID(), name: "Bananas")
        let old = PriceObservation(itemID: item.itemID!, shopID: shopID,
                                   date: Date(timeIntervalSinceNow: -200 * 86_400),
                                   amount: Money(minorUnits: 449), source: .receipt)
        let summary = snapshot([item], [old]).summary
        XCTAssertEqual(summary.measuredCount, 0)
        XCTAssertEqual(summary.estimatedCount, 1)
        XCTAssertTrue(summary.isApproximate)
        // Estimates round hard, and the visible ledger adds up to the rounded figure.
        XCTAssertEqual(summary.total, Money(minorUnits: 450))
    }

    func testOneUnpricedRowIsEnoughToMakeTheWholeFigureApproximate() {
        let priced = ListItem(itemID: ItemID(), name: "Bananas")
        let observation = PriceObservation(itemID: priced.itemID!, shopID: shopID, date: Date(),
                                           amount: Money(minorUnits: 449), source: .receipt)
        let summary = snapshot([priced, ListItem(name: "Eggs")], [observation]).summary
        XCTAssertTrue(summary.isApproximate, "≈ on any total that is missing money")
        XCTAssertEqual(summary.unpricedCount, 1)
        XCTAssertEqual(summary.total, Money(minorUnits: 449))
    }

    func testTheGalleryTileCarriesNamesButNoMoneyNobodyPaid() {
        guard case .list(let list) = WidgetProvider.sample(limit: 2) else {
            return XCTFail("the gallery still shows a list")
        }
        XCTAssertEqual(list.rows.count, 2)
        XCTAssertFalse(list.summary.hasPricedItems)
        XCTAssertEqual(list.summary.total, Money(minorUnits: 0))
    }
}
