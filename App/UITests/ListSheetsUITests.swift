import XCTest

/// The three wave-5 surfaces the walkthrough never opened: the shop switcher (screen 24),
/// the aisle-order editor (03) and the item-detail sheet (02). Screenshot each.
final class ListSheetsUITests: XCTestCase {

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testShopSwitcherAisleOrderAndItemDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        // Two aisles on the list: dairy (Butter) and produce (Apples).
        app.buttons["Add Butter"].firstMatch.tap()
        let field = app.textFields["I need…"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Apples\n")
        XCTAssertTrue(app.staticTexts["Apples"].waitForExistence(timeout: 3))

        // The shop switcher, then a shop so the aisle-order link appears.
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'change shop'"))
            .firstMatch.tap()
        // A kitchen with no shops asks for the first one inline ("Where do you usually
        // shop?"); with shops it lists them under "Shopping where?" behind + Add.
        let anyHeadline = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'shop'")).firstMatch
        XCTAssertTrue(anyHeadline.waitForExistence(timeout: 3), "shop sheet did not open")
        shoot(app, "19-shop-switcher")
        var name = app.textFields["Shop name"].firstMatch
        if !name.waitForExistence(timeout: 2) {
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "+ Add a shop")).firstMatch.tap()
            name = app.textFields["Shop name"].firstMatch
        }
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Tesco")
        app.buttons["Continue"].firstMatch.tap()

        // The aisle-order editor.
        let orderLink = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'aisle order'")).firstMatch
        XCTAssertTrue(orderLink.waitForExistence(timeout: 4), "aisle order link missing")
        orderLink.tap()
        sleep(1)
        shoot(app, "20-aisle-order")
        app.buttons["Done"].firstMatch.tap()

        // The item-detail sheet, from the row's context menu.
        app.staticTexts["Apples"].firstMatch.press(forDuration: 1.2)
        let setPrice = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'set what you paid'")).firstMatch
        XCTAssertTrue(setPrice.waitForExistence(timeout: 3), "context menu did not open")
        setPrice.tap()
        XCTAssertTrue(app.staticTexts["Quantity"].firstMatch.waitForExistence(timeout: 3),
                      "item detail sheet did not open")
        shoot(app, "21-item-detail")
    }
}
