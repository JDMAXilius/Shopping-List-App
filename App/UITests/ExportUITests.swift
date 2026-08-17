import XCTest

/// The export is a promise about the user's own data, and it had never been run. This drives
/// it end to end on real content: add items, record a price, then export and confirm the app
/// says three files are ready rather than failing quietly.
final class ExportUITests: XCTestCase {

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testExportingEverythingProducesTheThreeFilesItPromises() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        // Something to export: two rows on the list.
        app.buttons["Add Butter"].firstMatch.tap()
        let field = app.textFields["I need…"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Oat milk\n")
        XCTAssertTrue(app.staticTexts["Oat milk"].waitForExistence(timeout: 3))

        app.buttons["You"].firstMatch.tap()
        let privacy = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Data & privacy")).firstMatch
        XCTAssertTrue(privacy.waitForExistence(timeout: 4))
        privacy.tap()

        let export = app.buttons["Export everything (CSV)"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 4), "the export button never appeared")
        export.tap()

        // Three files — list, prices, receipts — named in the copy above the button.
        let ready = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'files ready'")).firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 5),
                      "export produced nothing, or failed silently")
        XCTAssertTrue(ready.label.hasPrefix("3 files ready"), ready.label)
        shoot(app, "32-export-ready")
    }
}
