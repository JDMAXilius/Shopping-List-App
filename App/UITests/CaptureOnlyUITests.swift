import XCTest

/// Two regression pins from the 2026-08-16 gate:
/// 1. The capture sheet must present with its session (it once raced sheet(item: $sheet)
///    and showed the "couldn't start" apology).
/// 2. The post-save spin: a checked row + an unchecked row on the list + an enter-by-hand
///    save once looped LazyVStack layout at 100% CPU forever (ListScreen.listCard).
final class CaptureOnlyUITests: XCTestCase {

    @MainActor
    func testTapCaptureImmediately() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()
        app.buttons["Capture"].firstMatch.tap()
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'hand'")).firstMatch
            .waitForExistence(timeout: 4), "capture chooser did not open")
    }

    @MainActor
    private func createShop(_ app: XCUIApplication) {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'change shop'"))
            .firstMatch.tap()
        let newShop = app.textFields["New shop"].firstMatch
        XCTAssertTrue(newShop.waitForExistence(timeout: 3))
        newShop.tap()
        newShop.typeText("Tesco")
        app.buttons["Add"].firstMatch.tap()
    }

    @MainActor
    func testG_twoItemsCheckSave() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()
        app.buttons["Add Butter"].firstMatch.tap()
        let field = app.textFields["I need…"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Oat milk\n")
        XCTAssertTrue(app.staticTexts["Oat milk"].waitForExistence(timeout: 3))
        app.staticTexts["Butter"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'COMPLETED'")).firstMatch
            .waitForExistence(timeout: 3))
        app.buttons["Capture"].firstMatch.tap()
        let byHand = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'hand'")).firstMatch
        XCTAssertTrue(byHand.waitForExistence(timeout: 4))
        byHand.tap()
        let itemField = app.textFields.firstMatch
        XCTAssertTrue(itemField.waitForExistence(timeout: 3))
        itemField.tap()
        itemField.typeText("Eggs")
        let match = app.buttons["Price Eggs"].firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 3))
        match.tap()
        createShop(app)
        let priceField = app.textFields.matching(
            NSPredicate(format: "label CONTAINS[c] 'paid'")).firstMatch
        XCTAssertTrue(priceField.waitForExistence(timeout: 3))
        priceField.tap()
        priceField.typeText("3.49")
        app.buttons["Save 1 price"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Saved:'")).firstMatch
            .waitForExistence(timeout: 10), "post-save query hung")
    }
}
