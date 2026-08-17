import XCTest

/// Wave 10's testing panel, reached from About. Compiled into Debug AND Release on purpose —
/// it is how a tester reaches a screen that would otherwise cost a real receipt — and it comes
/// out before submission (FOUNDER_BLOCKERS §10). Never seen until now.
final class ScreensPanelUITests: XCTestCase {

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testThePanelOpensAndListsScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        app.buttons["You"].firstMatch.tap()
        let about = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "About")).firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 4))
        about.tap()

        let opener = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Open a screen directly'")).firstMatch
        XCTAssertTrue(opener.waitForExistence(timeout: 4), "the screens panel entry is missing")
        // It must say what it is: a tester should never mistake it for a feature.
        XCTAssertTrue(opener.label.contains("For testing"),
                      "the panel does not disclaim itself: \(opener.label)")
        opener.tap()

        XCTAssertTrue(app.staticTexts["Screens"].firstMatch.waitForExistence(timeout: 4)
                      || app.navigationBars["Screens"].waitForExistence(timeout: 2),
                      "the panel did not open")
        shoot(app, "33-screens-panel")
    }
}
