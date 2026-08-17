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

    // MARK: - Quarantine (W10: a 403 was a poison pill)

    /// THE bug. RLS refuses a whole batch with 42501 → 403 when this device's session is no longer
    /// a member, and before quarantine those ops stayed unpushed forever with every later op
    /// queued behind them: one refusal and the kitchen stopped syncing for good.
    func testARefusedOpDoesNotBlockAnOpMadeAfterIt() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        let refused = try repository.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)
        await transport.setRefusedOpIDs([refused.opID])
        let clock = FakeClock()
        let engine = SyncEngine(repository: repository, transport: transport,
                                kitchenID: kitchenID, now: { clock.now })

        await engine.kick()
        let afterRefusal = await transport.storedOps
        XCTAssertTrue(afterRefusal.isEmpty, "the server took nothing")

        let later = try repository.append(.add(ListItem(name: "Eggs")), kitchenID: kitchenID)
        await engine.kick()

        let stored = await transport.storedOps
        XCTAssertEqual(stored.map(\.opID), [later.opID],
                       "the op made after the refusal reaches the server")
        XCTAssertTrue(try repository.unpushedOps().isEmpty, "and the queue drained")
    }

    /// RULING 1: quarantine, never discard. Marking a refused op pushed would lose a real edit —
    /// the one outcome worse than the wedge.
    func testAQuarantinedOpIsStillInTheDatabaseWithItsPayload() async throws {
        let transport = FakeTransport()
        let (database, repository) = try makeStack()
        let refused = try repository.append(.add(ListItem(name: "Sourdough")), kitchenID: kitchenID)
        await transport.setRefusedOpIDs([refused.opID])
        let engine = SyncEngine(repository: repository, transport: transport, kitchenID: kitchenID)

        await engine.kick()

        let held = try repository.quarantinedOps(kitchenID: kitchenID)
        XCTAssertEqual(held, [refused], "the refused op is still here, byte for byte")
        let pushedAt = try await database.pool.read { db in
            try Int64.fetchOne(db, sql: "SELECT pushed_at FROM op WHERE op_id = ?",
                               arguments: [refused.opID.rawValue.uuidString])
        }
        XCTAssertNil(pushedAt, "nobody accepted it, so nothing may say they did")
        XCTAssertEqual(try repository.items().map(\.name), ["Sourdough"],
                       "and the household's own list never lost the edit")
    }

    /// RULING 6: "synced" must never be shown while anything is quarantined — not even after a
    /// later op has drained cleanly and the queue is empty.
    func testStatusIsNeverSyncedWhileAnythingIsQuarantined() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        let refused = try repository.append(.add(ListItem(name: "Rice")), kitchenID: kitchenID)
        await transport.setRefusedOpIDs([refused.opID])
        let engine = SyncEngine(repository: repository, transport: transport, kitchenID: kitchenID)

        await engine.kick()
        let afterRefusal = await engine.status
        XCTAssertEqual(afterRefusal, .stuck, "a refusal nothing retries is not an outage")

        try repository.append(.add(ListItem(name: "Beans")), kitchenID: kitchenID)
        await engine.kick()
        let afterCleanDrain = await engine.status
        XCTAssertEqual(afterCleanDrain, .stuck,
                       "a queue that drained does not make the refused edit agreed")
        XCTAssertTrue(try repository.unpushedOps().isEmpty)
    }

    /// RULING 5: the count is not allowed to lie. Quarantined ops are not pending — nothing is
    /// being attempted for them — and they are not saved either, so they are their own number.
    func testPendingExcludesQuarantinedOpsAndRefusedCountsThem() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        let refused = try repository.append(.add(ListItem(name: "Oats")), kitchenID: kitchenID)
        try repository.append(.add(ListItem(name: "Tea")), kitchenID: kitchenID)
        await transport.setRefusedOpIDs([refused.opID])
        let engine = SyncEngine(repository: repository, transport: transport, kitchenID: kitchenID)

        // Both ops travelled in one batch, and a 403 says nothing about which op offended.
        await engine.kick()
        let pendingAfterRefusal = await engine.pending
        let refusedAfterRefusal = await engine.refused
        XCTAssertEqual(pendingAfterRefusal, 0, "nothing is on its way")
        XCTAssertEqual(refusedAfterRefusal, 2, "and both held ops are stated, not hidden")
        XCTAssertEqual(try repository.unpushedOps().count, 0)
        XCTAssertEqual(try repository.quarantinedOps(kitchenID: kitchenID).count, 2)

        try repository.append(.add(ListItem(name: "Salt")), kitchenID: kitchenID)
        await engine.kick()
        let pending = await engine.pending
        let stillRefused = await engine.refused
        XCTAssertEqual(pending, 0, "the new op drained")
        XCTAssertEqual(stillRefused, 2, "and the refused ones are still refused, still counted")
    }

    /// RULING: ordinary backoff is untouched. `unreachable`/`server`/`unauthenticated` all mean
    /// "try again" — quarantining any of them would take an op out of a queue that still works.
    func testRetryableFailuresQuarantineNothing() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        try repository.append(.add(ListItem(name: "Flour")), kitchenID: kitchenID)
        let clock = FakeClock()
        let engine = SyncEngine(repository: repository, transport: transport,
                                kitchenID: kitchenID, now: { clock.now })

        for error in [SupabaseTransportError.unreachable, .server(status: 502),
                      .unauthenticated, .malformedResponse] {
            await transport.setPushError(error)
            await engine.kick()
            let status = await engine.status
            let refused = await engine.refused
            let pending = await engine.pending
            XCTAssertEqual(status, .offline, "\(error) is not a refusal")
            XCTAssertEqual(refused, 0, "\(error) quarantines nothing")
            XCTAssertEqual(pending, 1, "\(error) leaves the op in the queue")
            XCTAssertTrue(try repository.quarantinedOps(kitchenID: kitchenID).isEmpty, "\(error)")
            XCTAssertEqual(try repository.unpushedOps().count, 1, "\(error)")
            clock.advance(by: 61)
        }

        await transport.setPushError(nil)
        await engine.kick()
        let stored = await transport.storedOps
        XCTAssertEqual(stored.count, 1, "and the op ships the moment the outage ends")
        let status = await engine.status
        XCTAssertEqual(status, .synced)
    }

    /// RULING 3: quarantine is reversible and a successful pull is what reverses it — the pull
    /// proves this session can still read the kitchen, so membership is real again.
    func testASuccessfulPullReleasesQuarantinedOps() async throws {
        let transport = FakeTransport()
        let (_, repository) = try makeStack()
        let refused = try repository.append(.add(ListItem(name: "Butter")), kitchenID: kitchenID)
        await transport.setRefusedOpIDs([refused.opID])
        let clock = FakeClock()
        let engine = SyncEngine(repository: repository, transport: transport,
                                kitchenID: kitchenID, now: { clock.now })
        await engine.kick()
        XCTAssertEqual(try repository.quarantinedOps(kitchenID: kitchenID).count, 1)

        // Re-invited an hour later: the server stops refusing, and the pull that answers is the
        // proof. The wait is the point — three pushes 20s apart would end the story before this.
        await transport.setRefusedOpIDs([])
        await engine.kick()
        XCTAssertEqual(try repository.quarantinedOps(kitchenID: kitchenID).count, 1,
                       "inside the hour the held op is not pushed again")
        clock.advance(by: 3601)
        await engine.kick()

        XCTAssertTrue(try repository.quarantinedOps(kitchenID: kitchenID).isEmpty,
                      "the held op got its retry")
        let stored = await transport.storedOps
        XCTAssertEqual(stored.map(\.opID), [refused.opID], "and the edit reached the server")
        let status = await engine.status
        let count = await engine.refused
        XCTAssertEqual(status, .synced, "nothing is held any more")
        XCTAssertEqual(count, 0)
        XCTAssertTrue(try repository.unpushedOps().isEmpty)
    }

    /// The other half of RULING 3: the release is BOUNDED. `quarantine_count` survives the
    /// release, so a server that keeps refusing gets `refusalLimit` pushes for that op and then
    /// none, ever — no doomed batch on every 20-second poll for the life of the install.
    func testTheReleaseIsBoundedSoARefusalCannotRetryForever() async throws {
        let transport = FakeTransport()
        let (database, repository) = try makeStack()
        let refused = try repository.append(.add(ListItem(name: "Yeast")), kitchenID: kitchenID)
        await transport.setRefusedOpIDs([refused.opID])
        let clock = FakeClock()
        let engine = SyncEngine(repository: repository, transport: transport, kitchenID: kitchenID,
                                refusalLimit: 3, retryRefusedAfter: 3600, now: { clock.now })

        // Eight kicks over eight hours: every one of them is free to retry, and only three do.
        for _ in 0..<8 {
            await engine.kick()
            clock.advance(by: 3601)
        }

        let attempts = await transport.pushAttempts
        XCTAssertEqual(attempts, 3, "three refusals and then the op is held for good")
        let refusalCount = try await database.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT quarantine_count FROM op WHERE op_id = ?",
                             arguments: [refused.opID.rawValue.uuidString])
        }
        XCTAssertEqual(refusalCount, 3, "the bound is persisted, so a relaunch does not reset it")
        XCTAssertEqual(try repository.quarantinedOps(kitchenID: kitchenID), [refused],
                       "still here, still unpushed, still carrying the edit")
        let status = await engine.status
        let count = await engine.refused
        XCTAssertEqual(status, .stuck, "and never reported as synced")
        XCTAssertEqual(count, 1)

        // A held-for-good op still must not block the kitchen.
        let later = try repository.append(.add(ListItem(name: "Sugar")), kitchenID: kitchenID)
        await engine.kick()
        let stored = await transport.storedOps
        XCTAssertEqual(stored.map(\.opID), [later.opID])
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
