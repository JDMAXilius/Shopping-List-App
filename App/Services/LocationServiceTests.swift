import CoreLocation
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class LocationServiceTests: XCTestCase {

    // MARK: - Permission is four words, and a refusal is one of them

    func testEveryAuthorizationStatusLandsOnAPlainValue() {
        XCTAssertEqual(LocationService.permission(for: .notDetermined), .notAsked)
        XCTAssertEqual(LocationService.permission(for: .authorizedWhenInUse), .whileUsing)
        XCTAssertEqual(LocationService.permission(for: .authorizedAlways), .always)
        // Two system states, one consequence: nothing above this can locate anything.
        XCTAssertEqual(LocationService.permission(for: .denied), .denied)
        XCTAssertEqual(LocationService.permission(for: .restricted), .denied)
    }

    func testOnlyTheTwoGrantedStatesCanLocate() {
        XCTAssertTrue(LocationService.Permission.whileUsing.canLocate)
        XCTAssertTrue(LocationService.Permission.always.canLocate)
        XCTAssertFalse(LocationService.Permission.notAsked.canLocate)
        XCTAssertFalse(LocationService.Permission.denied.canLocate)
    }

    // MARK: - A device with no CoreLocation behaves exactly like a refusal

    func testWithoutCoreLocationEverythingAnswersInsteadOfHanging() async {
        let service = LocationService(manager: nil)

        XCTAssertEqual(service.permission, .denied)
        let fix = await service.currentFix()
        XCTAssertNil(fix, "no fix, and no waiting for one that cannot come")

        // None of these may trap or block: every screen calls them without checking first.
        service.requestWhenInUse()
        service.requestAlways()
        service.monitor([fence("a"), fence("b")])
        XCTAssertEqual(service.permission, .denied)
    }

    // MARK: - The 20 iOS allows

    func testTheFenceLimitIsTwentyAndTheExtrasAreCutFromTheEnd() {
        let wanted = (0..<30).map { fence("shop-\($0)") }
        let capped = LocationService.capped(wanted)

        XCTAssertEqual(LocationService.fenceLimit, 20, "the system's cap, not a preference")
        XCTAssertEqual(capped.count, 20)
        // Order in, order out: the caller ranked them, and this must not re-rank or sample.
        XCTAssertEqual(capped.map(\.id), (0..<20).map { "shop-\($0)" })
    }

    func testFewerThanTheLimitArePassedThroughWhole() {
        let wanted = (0..<3).map { fence("shop-\($0)") }
        XCTAssertEqual(LocationService.capped(wanted).map(\.id), wanted.map(\.id))
        XCTAssertTrue(LocationService.capped([]).isEmpty)
    }

    // MARK: - A coordinate never reaches a log

    func testAFixDescribesItselfWithoutSayingWhereItIs() {
        let fix = LocationService.Fix(latitude: 40.712776, longitude: -74.005974,
                                      accuracy: 12.4, takenAt: Date())
        let printed = "\(fix)"

        XCTAssertEqual(printed, "Fix(±12m)")
        XCTAssertFalse(printed.contains("40.7"), "a crash report must not carry an address")
        XCTAssertFalse(printed.contains("74.0"))
    }

    private func fence(_ id: String) -> LocationService.Fence {
        LocationService.Fence(id: id, latitude: 40.7, longitude: -74, radius: 150)
    }
}
