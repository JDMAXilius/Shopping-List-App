import XCTest

/// Wave-7 parity capture: seed one typed price, then walk the Prices tab —
/// book → price history → month spend — attaching a screenshot at each stop.
final class PricesTabUITests: XCTestCase {

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testPricesBookHistoryAndMonth() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        // Seed: one typed price for Eggs at a new shop, via enter-by-hand.
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
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'change shop'"))
            .firstMatch.tap()
        let newShop = app.textFields["New shop"].firstMatch
        XCTAssertTrue(newShop.waitForExistence(timeout: 3))
        newShop.tap()
        newShop.typeText("Tesco")
        app.buttons["Add"].firstMatch.tap()
        let priceField = app.textFields.matching(
            NSPredicate(format: "label CONTAINS[c] 'paid'")).firstMatch
        XCTAssertTrue(priceField.waitForExistence(timeout: 3))
        priceField.tap()
        priceField.typeText("3.49")
        app.buttons["Save 1 price"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Saved:'")).firstMatch
            .waitForExistence(timeout: 5))
        app.swipeDown(velocity: .fast)  // close the capture sheet

        // The book.
        app.buttons["Prices"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Eggs"].firstMatch.waitForExistence(timeout: 4),
                      "typed price did not reach the book")
        shoot(app, "11-prices-book")

        // Price history for the one entry.
        app.staticTexts["Eggs"].firstMatch.tap()
        sleep(1)
        shoot(app, "12-price-history")
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap() }

        // Month spend.
        let monthLink = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'where it went'")).firstMatch
        if monthLink.waitForExistence(timeout: 3) {
            monthLink.tap()
            sleep(1)
            shoot(app, "13-month-spend")
        }
    }
}
