import XCTest
import Catalog

// Expected values pinned by running the JS reference (resolve.mjs) directly.
final class EditDistanceTests: XCTestCase {

    func testExactAndSmallDistances() {
        XCTAssertEqual(editDistance("abc", "abc"), 0)
        XCTAssertEqual(editDistance("flour", "floor"), 1)
        XCTAssertEqual(editDistance("bananna", "banana"), 1)
        XCTAssertEqual(editDistance("tomatos", "tomato"), 1)
        XCTAssertEqual(editDistance("bananna", "bananas"), 2)
        XCTAssertEqual(editDistance("abc", "abcde"), 2)
    }

    func testEmptyStrings() {
        XCTAssertEqual(editDistance("", "ab"), 2)
        XCTAssertEqual(editDistance("ab", ""), 2)
        XCTAssertEqual(editDistance("", ""), 0)
    }

    func testLengthDifferenceShortCircuit() {
        XCTAssertEqual(editDistance("a", "abcd"), 3)  // |1-4| > 2 → max+1
        XCTAssertEqual(editDistance("kitten", "sitting"), 3)  // true distance 3, capped
    }

    func testBoundedEarlyExit() {
        // Every row minimum exceeds max → max+1, never the true distance 4.
        XCTAssertEqual(editDistance("abcd", "wxyz"), 3)
    }

    func testCustomMax() {
        XCTAssertEqual(editDistance("kitten", "sitting", max: 3), 3)
        XCTAssertEqual(editDistance("abcd", "wxyz", max: 4), 4)
    }
}
