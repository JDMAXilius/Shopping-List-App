import Core
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class ScreensPanelTests: XCTestCase {

    private var nothingAvailable: ScreensPanel.Availability { ScreensPanel.Availability() }

    private var everythingAvailable: ScreensPanel.Availability {
        ScreensPanel.Availability(listRow: ListItemID(), shop: ShopID(), item: ItemID(),
                                  prices: true, places: true, kitchen: true, sync: true,
                                  capture: true)
    }

    private func rows(_ available: ScreensPanel.Availability) -> [ScreensPanel.Row] {
        ScreensPanel.groups(available).flatMap(\.rows)
    }

    // MARK: - It must be invisible in an App Store build, and visible in TestFlight

    func testAnAppStoreBuildNeverCarriesThePanel() {
        XCTAssertFalse(ScreensPanel.isAllowed(receiptName: "receipt", isDebugBuild: false),
                       "the panel reached a production build")
        // Absent is never a licence: a release build with no receipt is treated as the store.
        XCTAssertFalse(ScreensPanel.isAllowed(receiptName: nil, isDebugBuild: false))
        XCTAssertFalse(ScreensPanel.isAllowed(receiptName: "sandboxreceipt", isDebugBuild: false),
                       "the receipt name is compared exactly, not loosely")
    }

    func testTestFlightAndTheSimulatorDoCarryIt() {
        XCTAssertTrue(ScreensPanel.isAllowed(receiptName: "sandboxReceipt", isDebugBuild: false),
                      "a TestFlight build is a Release build and is where this is wanted")
        XCTAssertTrue(ScreensPanel.isAllowed(receiptName: nil, isDebugBuild: true))
        XCTAssertTrue(ScreensPanel.isAllowed(receiptName: "receipt", isDebugBuild: true))
    }

    func testThisTestBundleAgreesWithItsOwnBuildConfiguration() {
        XCTAssertEqual(ScreensPanel.isAllowedInThisBuild,
                       ScreensPanel.isAllowed(
                           receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent,
                           isDebugBuild: ScreensPanel.isDebugBuild))
    }

    // MARK: - Every row opens something or explains itself

    func testEveryRowEitherOpensSomethingOrSaysWhyNot() {
        for available in [nothingAvailable, everythingAvailable] {
            for row in rows(available) {
                XCTAssertFalse(row.title.isEmpty)
                guard case .cannot(let reason) = row.opening else { continue }
                XCTAssertFalse(reason.isEmpty, "\(row.title) is a dead row")
                XCTAssertTrue(reason.hasSuffix("."), "\(row.title): \(reason)")
                XCTAssertGreaterThan(reason.count, 20, "\(row.title): \(reason) explains nothing")
            }
        }
    }

    /// On a device that can hand over everything, the only rows that refuse are the ones that
    /// would have to invent a receipt — the honest limit, named.
    func testTheOnlyScreensThePanelRefusesAreTheOnesNeedingARealReceipt() {
        let refused = rows(everythingAvailable).filter {
            if case .cannot = $0.opening { return true } else { return false }
        }

        XCTAssertEqual(refused.map(\.title),
                       ["Receipt review", "Line resolver", "Receipt saved", "First receipt"])
    }

    func testAnEmptyKitchenExplainsEveryRowItCannotOpen() {
        let opened = rows(nothingAvailable).filter {
            if case .opens = $0.opening { return true } else { return false }
        }

        // What needs no store at all: the paywall, the You tab, and the three static pages.
        XCTAssertEqual(opened.map(\.title),
                       ["Shop switcher", "You", "Bagged Plus", "Data & privacy", "About",
                        "Why it works this way"])
    }

    func testTheListNamesEachScreenOnceAndIsGroupedByTab() {
        let all = rows(everythingAvailable)

        XCTAssertEqual(ScreensPanel.groups(everythingAvailable).map(\.title),
                       ["List", "Prices", "You", "Add prices"])
        XCTAssertEqual(Set(all.map(\.title)).count, all.count, "a screen is listed twice")
        XCTAssertEqual(all.count, 25)
    }

    /// One style, and no debug aesthetic: the panel speaks in the app's voice or it teaches a
    /// tester that a second voice exists.
    func testItSaysWhatItIsWithoutShouting() {
        XCTAssertTrue(ScreensPanel.explanation.contains("tested"))
        XCTAssertTrue(ScreensPanel.explanation.contains("not part of the app"))
        for text in [ScreensPanel.explanation] + rows(nothingAvailable).flatMap(sentences) {
            XCTAssertFalse(text.contains("!"), text)
            XCTAssertFalse(text.lowercased().contains("debug"), text)
            XCTAssertFalse(text.unicodeScalars.contains { $0.properties.isEmojiPresentation }, text)
        }
    }

    private func sentences(_ row: ScreensPanel.Row) -> [String] {
        var found = [row.title]
        if let note = row.note { found.append(note) }
        if case .cannot(let reason) = row.opening { found.append(reason) }
        return found
    }

    // MARK: - It stays out of navigation

    /// Both switches are exhaustive, so a `Route` or `Sheet` case added for the panel stops this
    /// file compiling — which is the point: the panel is temporary and owns neither enum.
    func testThePanelAddsNoRouteAndNoSheetCase() {
        let routes: [Route] = [.aisleOrder(ShopID()), .priceHistory(ItemID()), .monthSpend,
                               .shopEditor(nil), .kitchen, .places, .setup, .dataPrivacy, .about,
                               .whyItWorksThisWay]
        let sheets: [Sheet] = [.itemDetail(ListItemID()), .shopSwitcher, .firstShop, .capture,
                               .invite, .paywall, .join("token")]

        XCTAssertEqual(Set(routes.map(name)).count, 10, "navigation gained a push destination")
        XCTAssertEqual(Set(sheets.map(name)).count, 7, "navigation gained a sheet")
    }

    private func name(_ route: Route) -> String {
        switch route {
        case .aisleOrder: return "aisleOrder"
        case .priceHistory: return "priceHistory"
        case .monthSpend: return "monthSpend"
        case .shopEditor: return "shopEditor"
        case .kitchen: return "kitchen"
        case .places: return "places"
        case .setup: return "setup"
        case .dataPrivacy: return "dataPrivacy"
        case .about: return "about"
        case .whyItWorksThisWay: return "whyItWorksThisWay"
        }
    }

    private func name(_ sheet: Sheet) -> String {
        switch sheet {
        case .itemDetail: return "itemDetail"
        case .shopSwitcher: return "shopSwitcher"
        case .firstShop: return "firstShop"
        case .capture: return "capture"
        case .invite: return "invite"
        case .paywall: return "paywall"
        case .join: return "join"
        }
    }
}
