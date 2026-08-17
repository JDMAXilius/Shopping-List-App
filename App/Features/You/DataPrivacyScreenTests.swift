import DesignKit
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class DataPrivacyScreenTests: XCTestCase {
    private let code = "3017620422003"

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    private func makeDefaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(UUID().uuidString)"))
    }

    private func makeLookup() -> ProductLookup {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.stub = StubURLProtocol.Stub(
            status: 200,
            body: Foundation.Data(#"{"product":{"product_name":"Nutella"},"status":1}"#.utf8))
        return ProductLookup(session: URLSession(configuration: configuration))
    }

    // MARK: - The switch this screen owns

    func testTheSwitchStartsOnAndSaysSoBecauseAbsentMeansOn() throws {
        let defaults = try makeDefaults()

        XCTAssertTrue(ProductLookup.isEnabled(defaults))
        XCTAssertNil(defaults.object(forKey: ProductLookup.settingKey))
    }

    func testTurningTheSwitchOffStopsAnyCodeLeavingThePhone() async throws {
        let defaults = try makeDefaults()

        DataPrivacyScreen.setBarcodeLookup(false, in: defaults)

        XCTAssertFalse(ProductLookup.isEnabled(defaults))
        let suggestion = ProductSuggestion(lookup: makeLookup(), defaults: defaults)
        XCTAssertFalse(suggestion.isEnabled, "the scanner discloses the state this screen set")
        await suggestion.ask(about: code)
        XCTAssertTrue(StubURLProtocol.requests.isEmpty, "a code left the phone with the switch off")
        XCTAssertNil(suggestion.name)
    }

    func testTurningItBackOnAsksAgain() async throws {
        let defaults = try makeDefaults()
        DataPrivacyScreen.setBarcodeLookup(false, in: defaults)

        DataPrivacyScreen.setBarcodeLookup(true, in: defaults)

        XCTAssertTrue(ProductLookup.isEnabled(defaults))
        let suggestion = ProductSuggestion(lookup: makeLookup(), defaults: defaults)
        await suggestion.ask(about: code)
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
        XCTAssertEqual(suggestion.name, "Nutella")
    }

    // MARK: - The two switches on Setup are the ones DesignKit actually reads

    func testTheFeedbackSwitchesReachSoundAndHaptics() throws {
        let defaults = try makeDefaults()

        SetupSettings.apply(defaults)
        XCTAssertTrue(Sound.isEnabled)
        XCTAssertTrue(Haptics.isEnabled)

        SetupSettings.set(SetupSettings.soundKey, false, in: defaults)
        XCTAssertFalse(Sound.isEnabled)
        XCTAssertTrue(Haptics.isEnabled)

        // The launch path: a phone that turned sound off must arrive with it off.
        Sound.isEnabled = true
        SetupSettings.apply(defaults)
        XCTAssertFalse(Sound.isEnabled)

        SetupSettings.set(SetupSettings.soundKey, true, in: defaults)
    }

    // MARK: - Rows that state counts, not guesses

    func testTheShopsRowCountsWhatIsThere() {
        XCTAssertEqual(SetupScreen.shopsDetail(0), "none yet")
        XCTAssertEqual(SetupScreen.shopsDetail(1), "1 shop")
        XCTAssertEqual(SetupScreen.shopsDetail(4), "4 shops")
    }

    func testTheScanChipStatesTheCountAndNeverPressures() {
        XCTAssertEqual(SetupScreen.scansChip(3), "3 free scans left")
        XCTAssertEqual(SetupScreen.scansChip(1), "1 free scan left")
        XCTAssertEqual(SetupScreen.scansChip(0), "3 free scans used")
    }

    func testAVersionIsNeverInvented() {
        // Whatever this build carries, the line is either the truth or absent.
        if let line = AboutScreen.versionLine {
            XCTAssertTrue(line.hasPrefix("Version "), line)
        }
    }
}
