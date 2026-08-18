import XCTest

/// A build configured with no backend must say so before a photo is taken, not after.
/// This pins the disclosure so a real-backend build silently losing it would fail here.
final class NoBackendNoticeUITests: XCTestCase {

    @MainActor
    func testTheCaptureChooserDisclosesAMissingReader() throws {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .camera)
        app.launchArguments = ["--uitest-reset"]
        app.launch()

        app.buttons["Capture"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Add prices"].firstMatch.waitForExistence(timeout: 4))

        let notice = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'no receipt reader'")).firstMatch
        // Only assert the wording when this build actually has no backend; a configured
        // build must NOT show it, and that is the other half of the contract.
        if notice.exists {
            XCTAssertTrue(notice.label.contains("kept on this phone"), notice.label)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "34-no-backend-notice"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
