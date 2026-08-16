import Core
import Foundation
import XCTest

final class IdentifiersTests: XCTestCase {
    private let edgeCases: [Int64] = [0, 1, 2, 7, 461, 999_999, .max, .min, -1]

    func testCatalogMappingIsDeterministic() {
        for id in edgeCases {
            XCTAssertEqual(ItemID.catalog(id), ItemID.catalog(id))
            XCTAssertEqual(ItemID.catalog(id).rawValue.uuidString, ItemID.catalog(id).rawValue.uuidString)
        }
    }

    // The byte layout is a storage format: moving it re-keys every seeded price
    // against every observed one, silently. These are pinned forever.
    func testCatalogByteLayoutIsPinned() {
        XCTAssertEqual(ItemID.catalog(0).rawValue.uuidString, "BA60CA7A-1060-0001-0000-000000000000")
        XCTAssertEqual(ItemID.catalog(1).rawValue.uuidString, "BA60CA7A-1060-0001-0000-000000000001")
        XCTAssertEqual(ItemID.catalog(2).rawValue.uuidString, "BA60CA7A-1060-0001-0000-000000000002")
        XCTAssertEqual(ItemID.catalog(369).rawValue.uuidString, "BA60CA7A-1060-0001-0000-000000000171")
        XCTAssertEqual(ItemID.catalog(.max).rawValue.uuidString, "BA60CA7A-1060-0001-7FFF-FFFFFFFFFFFF")
    }

    func testCatalogIDRoundTrips() {
        for id in edgeCases {
            XCTAssertEqual(ItemID.catalog(id).catalogID, id)
        }
        for id in Int64(0)...5_000 {
            XCTAssertEqual(ItemID.catalog(id).catalogID, id)
        }
        for offset in Int64(0)...5_000 {
            let id = Int64.max - offset
            XCTAssertEqual(ItemID.catalog(id).catalogID, id)
        }
    }

    func testDistinctCatalogIDsNeverCollide() {
        var seen = Set<ItemID>()
        for id in Int64(0)...10_000 {
            XCTAssertTrue(seen.insert(ItemID.catalog(id)).inserted, "collision at \(id)")
        }
        for id in edgeCases where !(0...10_000).contains(id) {
            XCTAssertTrue(seen.insert(ItemID.catalog(id)).inserted, "collision at \(id)")
        }
    }

    func testRandomItemIDIsNotCatalogBacked() {
        for _ in 0..<2_000 {
            XCTAssertNil(ItemID().catalogID)
        }
    }

    func testNearMissNamespaceIsNotCatalogBacked() {
        // One byte off the namespace is a user item, not catalog id 2.
        XCTAssertNil(ItemID(UUID(uuidString: "BA60CA7A-1060-0002-0000-000000000002")!).catalogID)
        XCTAssertNil(ItemID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!).catalogID)
        XCTAssertEqual(ItemID(UUID(uuidString: "BA60CA7A-1060-0001-0000-000000000002")!).catalogID, 2)
    }
}
