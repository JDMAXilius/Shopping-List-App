import XCTest

/// Wave 9's tab 3, rendered for the first time: the You root, the Plus paywall, Kitchen,
/// Places and the two honesty screens. Screenshot each — these have never been seen.
final class YouTabUITests: XCTestCase {

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// These screens hide the navigation bar, so the way back is the edge-pop gesture —
    /// driven from the very left edge so a scrollable body cannot swallow it.
    private func back(_ app: XCUIApplication) {
        if app.navigationBars.buttons.firstMatch.exists {
            app.navigationBars.buttons.firstMatch.tap()
            return
        }
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        edge.press(forDuration: 0.05,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)))
    }

    @MainActor
    func testTheYouTabAndEveryScreenUnderIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        app.buttons["You"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["You"].firstMatch.waitForExistence(timeout: 4),
                      "the You tab did not open")
        shoot(app, "25-you")

        // The Plus card is an offer to the owner — three free scans left on a fresh install.
        let plus = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'bagged plus'")).firstMatch
        if plus.waitForExistence(timeout: 2) {
            plus.tap()
            sleep(1)
            shoot(app, "26-paywall")
            // A sheet, not a push: dismiss by swiping it down.
            app.swipeDown(velocity: .fast)
        }

        // Kitchen and Places hide the navigation bar, so chaining back-navigation between
        // them is fragile; each screen is opened from its own launch instead.
        for (label, name) in [("Kitchen", "27-kitchen"), ("Places", "28-places"),
                              ("Data & privacy", "29-data-privacy"),
                              ("Why it works this way", "30-why"), ("About", "31-about")] {
            let fresh = XCUIApplication()
            fresh.launchArguments = ["--uitest-reset"]
            fresh.launch()
            fresh.buttons["You"].firstMatch.tap()
            XCTAssertTrue(fresh.staticTexts["You"].firstMatch.waitForExistence(timeout: 4))
            let row = fresh.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 3), "\(label) row missing")
            row.tap()
            sleep(1)
            shoot(fresh, name)
            fresh.terminate()
        }
    }
}
