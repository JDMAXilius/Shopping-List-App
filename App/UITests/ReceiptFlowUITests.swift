import XCTest

/// The receipt path, rendered for the first time: scripted scan (DEBUG launch mode) →
/// review → line resolver → save → result + first-receipt sheet. Exercises on screen the
/// coupon rule, the unsure-line resolver, and ignore-forever. Screenshots at every stop.
final class ReceiptFlowUITests: XCTestCase {

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testScanReviewResolveSave() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset", "--uitest-scripted-scan"]
        app.launch()

        // Into the camera screen; the scripted mode's stand-in shutter fires the scan.
        app.buttons["Capture"].firstMatch.tap()
        let scanOption = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'scan a receipt'")).firstMatch
        XCTAssertTrue(scanOption.waitForExistence(timeout: 4))
        scanOption.tap()
        let testShutter = app.buttons["Use test photo"].firstMatch
        XCTAssertTrue(testShutter.waitForExistence(timeout: 3), "scripted shutter missing")
        testShutter.tap()

        // Review. The coupon renders as money off, never as a price.
        XCTAssertTrue(app.staticTexts["MILK 1L"].firstMatch.waitForExistence(timeout: 5),
                      "review did not open")
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'money off'")).firstMatch.exists,
            "coupon chip missing")
        shoot(app, "14-receipt-review")

        // The unsure line goes through the resolver.
        app.buttons["Match this line"].firstMatch.tap()
        let search = app.textFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3), "resolver did not open")
        shoot(app, "15-line-resolver")
        search.tap()
        search.typeText("spinach")
        let match = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Match this line to'")).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 3), "no resolver match for spinach")
        match.tap()

        // Back on review: the receipt printed Trader Joe's but no shop exists yet — create it.
        XCTAssertTrue(app.staticTexts["MILK 1L"].firstMatch.waitForExistence(timeout: 3))
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'change shop'"))
            .firstMatch.tap()
        let newShop = app.textFields["New shop"].firstMatch
        XCTAssertTrue(newShop.waitForExistence(timeout: 3), "shop picker did not open")
        newShop.tap()
        newShop.typeText("Trader Joe's")
        app.buttons["Add"].firstMatch.tap()
        shoot(app, "16-review-ready")

        // Save. Two priced lines: milk and the resolved spinach; the coupon never counts.
        let save = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Save '")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        XCTAssertEqual(save.label, "Save 2 prices",
                       "the coupon or the fee leaked into the save count")
        save.tap()

        // First-receipt sheet (first commit with prices), then the result screen.
        let gotIt = app.buttons["Got it"].firstMatch
        if gotIt.waitForExistence(timeout: 4) {
            shoot(app, "17-first-receipt")
            gotIt.tap()
        }
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'photo stays on this phone'")).firstMatch
            .waitForExistence(timeout: 4), "result screen did not appear")
        shoot(app, "18-capture-result")
        app.buttons["Done"].firstMatch.tap()
    }
}
