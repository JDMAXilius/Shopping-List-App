import Core
import XCTest
@testable import Data

final class SyncEngineTests: XCTestCase {
    private let kitchenID = KitchenID()

    private func makeStack() throws -> (AppDatabase, Repository) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sync-tests-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        return (database, try Repository(database: database))
    }

    func testTwoOfflineDevicesConverge() async throws {
        let transport = FakeTransport()
        let (_, repoA) = try makeStack()
        let (_, repoB) = try makeStack()
        try repoA.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)
        try repoB.append(.add(ListItem(name: "  milk ")), kitchenID: kitchenID)

        let engineA = SyncEngine(repository: repoA, transport: transport, kitchenID: kitchenID)
        let engineB = SyncEngine(repository: repoB, transport: transport, kitchenID: kitchenID)
        await engineA.kick()
        await engineB.kick()
        await engineA.kick()

        let itemsA = try repoA.items()
        XCTAssertEqual(itemsA.count, 1, "same-name offline adds collapse to one row")
        XCTAssertEqual(itemsA, try repoB.items(), "both devices materialize identical state")
        let statusA = await engineA.status
        XCTAssertEqual(statusA, .synced)

        try repoA.rebuild()
        try repoB.rebuild()
        XCTAssertEqual(try repoA.items(), itemsA, "rebuild agrees with the incremental state")
        XCTAssertEqual(try repoA.items(), try repoB.items())
    }

    func testPushFailureBacksOffThenRecovers() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        try repository.append(.add(ListItem(name: "Eggs")), kitchenID: kitchenID)
        let engine = SyncEngine(repository: repository, transport: transport,
                                kitchenID: kitchenID, baseBackoff: 0.25, maxBackoff: 1)

        await transport.setPushError(TransportFailure())
        await engine.kick()
        let failedStatus = await engine.status
        XCTAssertEqual(failedStatus, .offline)
        let afterFailure = await transport.storedOps
        XCTAssertTrue(afterFailure.isEmpty)

        await transport.setPushError(nil)
        await engine.kick()
        let insideBackoff = await transport.storedOps
        XCTAssertTrue(insideBackoff.isEmpty, "kick inside the backoff window is a no-op")

        try await Task.sleep(for: .milliseconds(400))
        await engine.kick()
        let recovered = await transport.storedOps
        XCTAssertEqual(recovered.count, 1, "the drain resumes once the window passes")
        let recoveredStatus = await engine.status
        XCTAssertEqual(recoveredStatus, .synced)
        XCTAssertTrue(try repository.unpushedOps().isEmpty)
    }

    func testCursorPersistsAcrossEngineRestart() async throws {
        let transport = FakeTransport()
        let (_, repoA) = try makeStack()
        let (_, repoB) = try makeStack()
        try repoA.append(.add(ListItem(name: "Butter")), kitchenID: kitchenID)
        await SyncEngine(repository: repoA, transport: transport, kitchenID: kitchenID).kick()

        let first = SyncEngine(repository: repoB, transport: transport, kitchenID: kitchenID)
        await first.kick()
        XCTAssertEqual(try repoB.syncCursor(kitchenID: kitchenID), 1)

        let restarted = SyncEngine(repository: repoB, transport: transport, kitchenID: kitchenID)
        await restarted.kick()
        let cursor = await transport.lastPullCursor
        XCTAssertEqual(cursor, 1, "a fresh engine resumes from the persisted cursor")
    }

    func testRemoteOpsAreNeverRePushed() async throws {
        let transport = FakeTransport()
        let (_, repoA) = try makeStack()
        let (_, repoB) = try makeStack()
        try repoA.append(.add(ListItem(name: "Coffee")), kitchenID: kitchenID)
        await SyncEngine(repository: repoA, transport: transport, kitchenID: kitchenID).kick()

        let engineB = SyncEngine(repository: repoB, transport: transport, kitchenID: kitchenID)
        await engineB.kick()
        XCTAssertEqual(try repoB.items().count, 1, "B received A's op")
        XCTAssertTrue(try repoB.unpushedOps().isEmpty, "origin=remote is excluded from the drain")

        await engineB.kick()
        let pushCount = await transport.pushCount
        XCTAssertEqual(pushCount, 1, "only the originating device ever pushed")
        let stored = await transport.storedOps
        XCTAssertEqual(stored.count, 1, "no duplicate ops on the server")
    }
}
