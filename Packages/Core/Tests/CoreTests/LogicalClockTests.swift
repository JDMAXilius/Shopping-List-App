import XCTest
import Core

final class LogicalClockTests: XCTestCase {
    func testTickIsMonotonic() {
        var clock = LogicalClock()
        var previous: UInt64 = 0
        for _ in 0..<100 {
            let next = clock.tick()
            XCTAssertGreaterThan(next, previous)
            previous = next
        }
    }

    func testMergeAdvancesPastRemote() {
        var clock = LogicalClock()
        clock.tick()
        clock.tick()
        clock.merge(remote: 10)
        XCTAssertEqual(clock.value, 11)
        XCTAssertEqual(clock.tick(), 12)
    }

    func testMergeWithStaleRemoteStillAdvances() {
        var clock = LogicalClock(value: 5)
        clock.merge(remote: 2)
        XCTAssertEqual(clock.value, 6)
    }
}
