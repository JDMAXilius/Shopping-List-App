import Core
import Synchronization
import XCTest
@testable import Data

// Mutable fake clock so backoff windows are crossed by advancing time, never by sleeping.
final class FakeClock: Sendable {
    private let storage = Mutex(Date(timeIntervalSinceReferenceDate: 0))

    var now: Date { storage.withLock { $0 } }
    func advance(by interval: TimeInterval) {
        storage.withLock { $0.addTimeInterval(interval) }
    }
}

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
        let clock = FakeClock()
        let engine = SyncEngine(repository: repository, transport: transport,
                                kitchenID: kitchenID, now: { clock.now })

        await transport.setPushError(TransportFailure())
        await engine.kick()
        let failedStatus = await engine.status
        XCTAssertEqual(failedStatus, .offline)
        let afterFailure = await transport.storedOps
        XCTAssertTrue(afterFailure.isEmpty)

        await transport.setPushError(nil)
        clock.advance(by: 0.5)
        await engine.kick()
        let insideBackoff = await transport.storedOps
        XCTAssertTrue(insideBackoff.isEmpty, "kick inside the 1s backoff window is a no-op")

        clock.advance(by: 0.6)
        await engine.kick()
        let recovered = await transport.storedOps
        XCTAssertEqual(recovered.count, 1, "the drain resumes once the window passes")
        let recoveredStatus = await engine.status
        XCTAssertEqual(recoveredStatus, .synced)
        XCTAssertTrue(try repository.unpushedOps().isEmpty)
    }

    func testRepeatedFailuresReachStuck() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        try repository.append(.add(ListItem(name: "Flour")), kitchenID: kitchenID)
        let clock = FakeClock()
        let engine = SyncEngine(repository: repository, transport: transport,
                                kitchenID: kitchenID, stuckAfter: 5, now: { clock.now })

        await transport.setPushError(TransportFailure())
        for attempt in 1...5 {
            await engine.kick()
            let status = await engine.status
            XCTAssertEqual(status, attempt < 5 ? .offline : .stuck)
            clock.advance(by: 61)
        }
    }

    func testRedeliveryAfterCrashBeforeMarkPushed() async throws {
        let transport = FakeTransport()
        let (database, repository) = try makeStack()
        try repository.append(.add(ListItem(name: "Yogurt")), kitchenID: kitchenID)
        let engine = SyncEngine(repository: repository, transport: transport, kitchenID: kitchenID)
        await engine.kick()
        XCTAssertTrue(try repository.unpushedOps().isEmpty)

        // Crash between the push landing and markPushed: pushed_at was never written.
        try await database.pool.write { db in
            try db.execute(sql: "UPDATE op SET pushed_at = NULL")
        }
        XCTAssertEqual(try repository.unpushedOps().count, 1)

        await engine.kick()
        let stored = await transport.storedOps
        XCTAssertEqual(stored.count, 1, "idempotent push: re-delivery stores no duplicate")
        XCTAssertTrue(try repository.unpushedOps().isEmpty, "the op is marked pushed again")
        let status = await engine.status
        XCTAssertEqual(status, .synced)
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

    /// The guest's phone made its own kitchen before the invite arrived. Those ops must never
    /// be shipped under the shared kitchen's session — the real server refuses the whole batch
    /// (42501) and the queue never drains again — and must never be marked pushed by a drain
    /// that did not push them.
    func testOpsOfAnotherKitchenAreNeitherPushedNorMarked() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        let localOnly = KitchenID()
        try repository.append(.add(ListItem(name: "Shared milk")), kitchenID: kitchenID)
        try repository.append(.add(ListItem(name: "Private eggs")), kitchenID: localOnly)

        let engine = SyncEngine(repository: repository, transport: transport, kitchenID: kitchenID)
        await engine.kick()

        let stored = await transport.storedOps
        XCTAssertEqual(stored.count, 1, "only this engine's kitchen reached the server")
        XCTAssertEqual(stored.first?.kitchenID, kitchenID)
        let unpushed = try repository.unpushedOps()
        XCTAssertEqual(unpushed.count, 1, "the other kitchen's op is still owed, not lost")
        XCTAssertEqual(unpushed.first?.kitchenID, localOnly)
        let status = await engine.status
        XCTAssertEqual(status, .synced)
        let pending = await engine.pending
        XCTAssertEqual(pending, 0, "pending counts THIS kitchen's queue")
    }

    /// A cursor that was written but never persisted (a crash between apply and save) means the
    /// same rows arrive again. Nothing may change.
    func testAnOpDeliveredTwiceChangesNothing() async throws {
        let transport = FakeTransport()
        let (_, repoA) = try makeStack()
        let (_, repoB) = try makeStack()
        try repoA.append(.add(ListItem(name: "Coffee")), kitchenID: kitchenID)
        await SyncEngine(repository: repoA, transport: transport, kitchenID: kitchenID).kick()

        let first = try await transport.pull(after: 0, kitchenID: kitchenID)
        try repoB.applyRemote(first.ops, cursor: first.cursor, kitchenID: kitchenID)
        let afterFirst = try repoB.items()
        try repoB.applyRemote(first.ops, cursor: first.cursor, kitchenID: kitchenID)

        XCTAssertEqual(try repoB.items(), afterFirst)
        XCTAssertEqual(try repoB.items().count, 1)
        XCTAssertTrue(try repoB.unpushedOps().isEmpty)
    }

    func testPendingReportsTheUndrainedQueue() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        try repository.append(.add(ListItem(name: "Rice")), kitchenID: kitchenID)
        let clock = FakeClock()
        let engine = SyncEngine(repository: repository, transport: transport,
                                kitchenID: kitchenID, now: { clock.now })
        let initial = await engine.status
        XCTAssertEqual(initial, .local, "nothing has been agreed with a server yet")

        await transport.setPushError(TransportFailure())
        await engine.kick()
        let stalled = await engine.pending
        XCTAssertEqual(stalled, 1, "an undrained queue is stated, not hidden behind .synced")

        await transport.setPushError(nil)
        clock.advance(by: 2)
        await engine.kick()
        let drained = await engine.pending
        XCTAssertEqual(drained, 0)
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
