import XCTest

/// The T6 walkthrough, automated: add an item → check it → undo → open the `+` →
/// enter a price by hand → see it on the list. Screenshots attach at every stage
/// (exported to design/built/ by scripts alongside the xcresult).
final class FlowWalkthroughUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func shoot(_ name: String) {
        if ProcessInfo.processInfo.environment["SKIP_SHOTS"] != nil { return }
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testAddCheckUndoThenEnterAPriceByHand() throws {
        app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()
        shoot("01-list-empty")

        // Add from the suggestion chips (spoken label is "Add Butter").
        let butterChip = app.buttons["Add Butter"].firstMatch
        XCTAssertTrue(butterChip.waitForExistence(timeout: 3), "suggestion chip missing")
        butterChip.tap()

        // Add by typing.
        let field = app.textFields["I need…"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "input bar missing")
        field.tap()
        field.typeText("Oat milk\n")
        XCTAssertTrue(app.staticTexts["Oat milk"].waitForExistence(timeout: 3),
                      "typed item did not land on the list")
        shoot("02-list-two-items")

        // Check Butter off. Check-off has no undo by design — the same tap unchecks
        // (ListStore.toggle) — so the proof is the COMPLETED section appearing.
        let butterRow = app.otherElements.matching(
            NSPredicate(format: "label BEGINSWITH[c] 'Butter'")).firstMatch
        (butterRow.exists ? butterRow : app.staticTexts["Butter"].firstMatch).tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'COMPLETED'"))
                .firstMatch.waitForExistence(timeout: 3),
            "check-off did not move the row to COMPLETED")
        shoot("03-checked")

        // Remove Oat milk from its context menu, then take the undo back.
        app.staticTexts["Oat milk"].firstMatch.press(forDuration: 1.2)
        let removeAction = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'remove'")).firstMatch
        XCTAssertTrue(removeAction.waitForExistence(timeout: 3), "context menu did not open")
        removeAction.tap()
        let undo = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'undo'")).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "no undo offer after removal")
        shoot("04-removed-with-undo")
        undo.tap()
        XCTAssertTrue(app.staticTexts["Oat milk"].firstMatch.waitForExistence(timeout: 3),
                      "undo did not put Oat milk back")
        shoot("05-after-undo")

        // The + (spoken "Capture") → enter by hand → price typed in.
        app.buttons["Capture"].firstMatch.tap()
        let byHand = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'hand'")).firstMatch
        XCTAssertTrue(byHand.waitForExistence(timeout: 3), "capture chooser did not open")
        shoot("06-capture-chooser")
        byHand.tap()
        shoot("07-enter-by-hand")

        // Search the catalog, pick the exact match.
        let itemField = app.textFields.firstMatch
        XCTAssertTrue(itemField.waitForExistence(timeout: 3))
        itemField.tap()
        itemField.typeText("Eggs")
        let match = app.buttons["Price Eggs"].firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 3), "catalog match did not appear")
        match.tap()

        // A fresh install has no shop, and a price with no shop cannot save — create one
        // first, while no keyboard covers the lower half of the screen.
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'change shop'"))
            .firstMatch.tap()
        let newShop = app.textFields["New shop"].firstMatch
        XCTAssertTrue(newShop.waitForExistence(timeout: 3), "shop picker did not open")
        newShop.tap()
        newShop.typeText("Tesco")
        app.buttons["Add"].firstMatch.tap()

        // Type what was paid; save the one price.
        let priceField = app.textFields.matching(
            NSPredicate(format: "label CONTAINS[c] 'paid'")).firstMatch
        XCTAssertTrue(priceField.waitForExistence(timeout: 3), "price field did not appear")
        priceField.tap()
        priceField.typeText("3.49")
        shoot("08-enter-by-hand-filled")

        let saveButton = app.buttons["Save 1 price"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        XCTAssertTrue(saveButton.isEnabled, "save still disabled after picking a shop")
        saveButton.tap()

        // The price landed as a PriceObservation (enter-by-hand never adds a list item):
        // the screen returns to search with the saved sentence as the proof.
        sleep(2)
        shoot("09-saved")
        let savedNotice = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Saved:'")).firstMatch
        XCTAssertTrue(savedNotice.waitForExistence(timeout: 5),
                      "saved sentence did not appear")
        shoot("10-saved-notice")
    }
}
