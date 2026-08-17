import XCTest

/// W8-P5 on screen: a total sums line totals. Half an estimated item halves the money and
/// keeps ONE approximation mark — the total never grows a ~ of its own on top of the ≈.
final class ListTotalsUITests: XCTestCase {

    @MainActor
    func testHalfAnEstimatedItemHalvesTheTotal() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        let field = app.textFields["I need…"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("0.5 Oat milk\n")
        XCTAssertTrue(app.staticTexts["Oat milk"].waitForExistence(timeout: 3))

        // Oat milk's seed estimate is ~$5.00; half of it is $2.50, said once, with ≈ alone.
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '≈' AND label CONTAINS '$2.50'")).firstMatch
            .waitForExistence(timeout: 3), "half the estimate did not reach the total")
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '≈ ~'")).firstMatch.exists,
            "the total grew a second approximation mark")
    }
}
