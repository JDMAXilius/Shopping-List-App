import Core
import Foundation
import XCTest
@testable import Data

/// Every test here drives the real `SupabaseTransport` against `FakeSupabaseServer`, which
/// behaves like the SQL in `supabase/migrations`. The two attack tests are the acceptance
/// criterion: kitchen B trying to read and to write kitchen A, and failing.
final class SupabaseTransportTests: XCTestCase {
    private let config = SupabaseConfig(
        projectURL: URL(string: "https://example.supabase.co")!, anonKey: "anon-key")
    private let kitchenA = KitchenID()
    private let kitchenB = KitchenID()
    private let alice = UUID()
    private let mallory = UUID()
    private let device = DeviceID()

    private func makeTransport(_ server: FakeSupabaseServer,
                               token: String = "alice-jwt") -> SupabaseTransport {
        SupabaseTransport(config: config, http: server, accessToken: { token })
    }

    private func op(_ name: String, kitchenID: KitchenID, clock: UInt64,
                    wallClock: Date = Date(msSince1970: 1_755_300_000_000)) -> Op {
        Op(kitchenID: kitchenID, deviceID: device, clock: clock, wallClock: wallClock,
           kind: .add(ListItem(name: name)))
    }

    private func signedInServer() async -> FakeSupabaseServer {
        let server = FakeSupabaseServer()
        await server.signIn(token: "alice-jwt", userID: alice)
        await server.addMember(alice, to: kitchenA)
        return server
    }

    // MARK: - Idempotency is the contract

    func testDoublePushIsIdempotent() async throws {
        let server = await signedInServer()
        let transport = makeTransport(server)
        let ops = [op("Milk", kitchenID: kitchenA, clock: 1),
                   op("Eggs", kitchenID: kitchenA, clock: 2)]

        try await transport.push(ops)
        // The same batch again: push_ops answers 200 with 0 inserted, and 0 is success.
        try await transport.push(ops)

        let stored = await server.storedOpIDs
        XCTAssertEqual(stored.count, 2, "ON CONFLICT DO NOTHING: no duplicate rows")
        let pushes = await server.pushCount
        XCTAssertEqual(pushes, 2, "both calls really went to the server")
    }

    func testPartialBatchFailureIsRecoveredByRepushingEverything() async throws {
        let server = await signedInServer()
        let transport = makeTransport(server)
        let ops = (0..<250).map { op("Item \($0)", kitchenID: kitchenA, clock: UInt64($0 + 1)) }

        // 250 ops is two batches; the SECOND fails, so half the ops are already on the server
        // while the engine still holds every one of them unpushed.
        await server.failPush(number: 2)
        var caught: Error?
        do {
            try await transport.push(ops)
        } catch {
            caught = error
        }
        XCTAssertNotNil(caught, "a failed batch is reported, never swallowed")
        let landed = await server.storedOpIDs
        XCTAssertEqual(landed.count, SupabaseTransport.pushBatchSize,
                       "the first batch really landed — this is the state a retry must survive")

        try await transport.push(ops)
        let stored = await server.storedOpIDs
        XCTAssertEqual(Set(stored).count, 250, "the re-push lands every op exactly once")
        XCTAssertEqual(stored.count, 250)
    }

    func testWallClockCrossesTheWireAsIntegerMilliseconds() async throws {
        let server = await signedInServer()
        let transport = makeTransport(server)
        try await transport.push(
            [op("Milk", kitchenID: kitchenA, clock: 1,
                wallClock: Date(msSince1970: 1_755_300_000_000))])

        let body = await server.lastPushBody
        // `wall_clock bigint`: a float ("1.7553e+12") is a cast error on the real server.
        XCTAssertTrue(body.contains("\"wall_clock\":1755300000000"),
                      "wall_clock is an integer on the wire: \(body)")
        XCTAssertTrue(body.hasPrefix("{\"p_ops\":["), "push goes through the RPC's named argument")
    }

    // MARK: - The cursor

    func testPullNeverSkipsAnOpWhenKitchensShareTheSequence() async throws {
        let server = await signedInServer()
        await server.signIn(token: "mallory-jwt", userID: mallory)
        let transport = makeTransport(server)

        // Interleaved commits: A, B, A, B, A — one global sequence, two kitchens.
        try await transport.push([op("A1", kitchenID: kitchenA, clock: 1)])
        try await server.seed([op("B1", kitchenID: kitchenB, clock: 1)], as: mallory)
        try await transport.push([op("A2", kitchenID: kitchenA, clock: 2)])
        try await server.seed([op("B2", kitchenID: kitchenB, clock: 2)], as: mallory)
        try await transport.push([op("A3", kitchenID: kitchenA, clock: 3)])

        var cursor: Int64 = 0
        var received: [String] = []
        for _ in 0..<3 {
            let result = try await transport.pull(after: cursor, kitchenID: kitchenA)
            received += result.ops.map(\.opID.rawValue.uuidString)
            XCTAssertGreaterThanOrEqual(result.cursor, cursor)
            cursor = result.cursor
        }
        XCTAssertEqual(received.count, 3, "every op of kitchen A arrived, none of B's")
        XCTAssertEqual(cursor, 5, "the cursor is the seq of the last row delivered, not the max")
    }

    func testCursorNeverPassesAnOpThatWasNotDelivered() async throws {
        let server = await signedInServer()
        await server.signIn(token: "mallory-jwt", userID: mallory)
        let transport = makeTransport(server)
        try await transport.push([op("A1", kitchenID: kitchenA, clock: 1)])
        // Someone else's commit takes seq 2 while nothing of ours is at 2.
        try await server.seed([op("B1", kitchenID: kitchenB, clock: 1)], as: mallory)

        let first = try await transport.pull(after: 0, kitchenID: kitchenA)
        XCTAssertEqual(first.ops.count, 1)
        XCTAssertEqual(first.cursor, 1, "seq 2 is not ours and was never delivered to us")

        // The op that lands at seq 3 must still arrive on the next pull.
        try await transport.push([op("A2", kitchenID: kitchenA, clock: 2)])
        let second = try await transport.pull(after: first.cursor, kitchenID: kitchenA)
        XCTAssertEqual(second.ops.count, 1)
        XCTAssertEqual(second.cursor, 3)
    }

    func testPullSortsBySequenceRatherThanTrustingArrivalOrder() async throws {
        let server = await signedInServer()
        await server.shufflePages(true)
        let transport = makeTransport(server)
        try await transport.push([op("A1", kitchenID: kitchenA, clock: 1),
                                  op("A2", kitchenID: kitchenA, clock: 2),
                                  op("A3", kitchenID: kitchenA, clock: 3)])

        let result = try await transport.pull(after: 0, kitchenID: kitchenA)
        XCTAssertEqual(result.ops.map(\.clock), [1, 2, 3], "applied in sequence order")
        XCTAssertEqual(result.cursor, 3, "the cursor is the highest seq actually held")
    }

    func testEmptyPullLeavesTheCursorWhereItWas() async throws {
        let server = await signedInServer()
        let transport = makeTransport(server)
        let result = try await transport.pull(after: 7, kitchenID: kitchenA)
        XCTAssertTrue(result.ops.isEmpty)
        XCTAssertEqual(result.cursor, 7, "nothing arrived, so nothing is acknowledged")
    }

    // MARK: - The attacks

    /// Kitchen B's device asking for kitchen A's op log. `op_select` filters — the answer is
    /// empty, and it is empty whether or not kitchen A exists (no enumeration oracle).
    func testMemberOfAnotherKitchenPullsNothingFromMine() async throws {
        let server = await signedInServer()
        await server.signIn(token: "mallory-jwt", userID: mallory)
        await server.addMember(mallory, to: kitchenB)
        let mine = makeTransport(server)
        try await mine.push([op("Milk", kitchenID: kitchenA, clock: 1),
                             op("Eggs", kitchenID: kitchenA, clock: 2)])

        let attacker = makeTransport(server, token: "mallory-jwt")
        let stolen = try await attacker.pull(after: 0, kitchenID: kitchenA)
        XCTAssertTrue(stolen.ops.isEmpty, "kitchen A's list does not leak to kitchen B")
        XCTAssertEqual(stolen.cursor, 0)

        let unknown = try await attacker.pull(after: 0, kitchenID: KitchenID())
        XCTAssertTrue(unknown.ops.isEmpty, "a kitchen that does not exist answers the same way")
    }

    /// Kitchen B's device writing INTO kitchen A. `op_insert`'s WITH CHECK refuses the row and
    /// the whole call aborts: not one op lands, and the client is told it is a refusal.
    func testWritingIntoAnotherKitchenIsRefusedAndStoresNothing() async throws {
        let server = await signedInServer()
        await server.signIn(token: "mallory-jwt", userID: mallory)
        await server.addMember(mallory, to: kitchenB)
        let attacker = makeTransport(server, token: "mallory-jwt")

        do {
            try await attacker.push([op("Own", kitchenID: kitchenB, clock: 1),
                                     op("Planted", kitchenID: kitchenA, clock: 2)])
            XCTFail("a cross-kitchen batch must not succeed")
        } catch let error as SupabaseTransportError {
            XCTAssertEqual(error, .rejected(status: 403, code: "42501"))
        }

        let inA = await server.storedOpIDs(kitchen: kitchenA)
        let inB = await server.storedOpIDs(kitchen: kitchenB)
        XCTAssertTrue(inA.isEmpty, "nothing was planted in kitchen A")
        XCTAssertTrue(inB.isEmpty, "the attacker's own op did not land either — one transaction")
    }

    func testEvictedMemberIsRefusedRatherThanSilentlyDropped() async throws {
        let server = await signedInServer()
        let transport = makeTransport(server)
        try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
        await server.removeMember(alice, from: kitchenA)

        do {
            try await transport.push([op("Later", kitchenID: kitchenA, clock: 2)])
            XCTFail("an evicted member must not keep writing")
        } catch let error as SupabaseTransportError {
            XCTAssertEqual(error, .rejected(status: 403, code: "42501"))
        }
        let stored = await server.storedOpIDs(kitchen: kitchenA)
        XCTAssertEqual(stored.count, 1)
    }

    func testNoSessionIsUnauthenticatedAndSendsNothing() async {
        let server = await signedInServer()
        let transport = SupabaseTransport(config: config, http: server, accessToken: { nil })
        do {
            try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
            XCTFail("a push without a session must not be attempted")
        } catch let error as SupabaseTransportError {
            XCTAssertEqual(error, .unauthenticated)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        let paths = await server.requestedPaths
        XCTAssertTrue(paths.isEmpty, "nothing reached the network without a token")
    }

    func testAnonKeyTravelsWithEveryRequest() async throws {
        let server = await signedInServer()
        let transport = makeTransport(server)
        try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
        let key = await server.lastAPIKey
        XCTAssertEqual(key, "anon-key")
    }

    func testServerFailureIsRetryableRatherThanARefusal() async throws {
        let server = await signedInServer()
        await server.failNextPushes(1)
        let transport = makeTransport(server)
        do {
            try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
            XCTFail("a 503 is a failure")
        } catch let error as SupabaseTransportError {
            XCTAssertEqual(error, .server(status: 503), "5xx is retried, not treated as refused")
        }
        try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
        let stored = await server.storedOpIDs
        XCTAssertEqual(stored.count, 1)
    }

    /// A 4xx that is about TIMING is not a refusal. This stopped being cosmetic when W10-P1 made
    /// `.rejected` mean "quarantine it, and after three of these hold it for good": a rate limiter
    /// answering 429 would otherwise strand real edits permanently, which is the exact failure
    /// quarantining exists to prevent. Every one of these must reach the engine's backoff instead.
    func testARateLimitIsRetriedRatherThanTreatedAsARefusal() async throws {
        for status in [408, 423, 425, 429] {
            let server = await signedInServer()
            await server.failNextPushes(1, status: status, code: "PGRST999")
            let transport = makeTransport(server)
            do {
                try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
                XCTFail("\(status) is a failure")
            } catch let error as SupabaseTransportError {
                XCTAssertEqual(error, .server(status: status),
                               "\(status) must be retryable — a refusal would quarantine the op")
            }
            // And it really is retryable: the same push succeeds once the limiter lets go.
            try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
            let stored = await server.storedOpIDs
            XCTAssertEqual(stored.count, 1)
        }
    }

    /// The other side of the same line: a 4xx about PERMISSION stays a refusal, or the wedge this
    /// whole mechanism exists for comes straight back.
    func testAPermissionFailureIsStillARefusal() async throws {
        let server = await signedInServer()
        await server.failNextPushes(1, status: 403, code: "42501")
        let transport = makeTransport(server)
        do {
            try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
            XCTFail("a 403 is a refusal")
        } catch let error as SupabaseTransportError {
            XCTAssertEqual(error, .rejected(status: 403, code: "42501"))
        }
    }

    // MARK: - Round trip through the repository

    func testAnOpArrivingTwiceFromTheServerChangesNothing() async throws {
        let server = await signedInServer()
        let transport = makeTransport(server)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("transport-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        let repository = try Repository(database: database)

        try await transport.push([op("Milk", kitchenID: kitchenA, clock: 1)])
        let first = try await transport.pull(after: 0, kitchenID: kitchenA)
        try repository.applyRemote(first.ops, cursor: first.cursor, kitchenID: kitchenA)
        let afterFirst = try repository.items()

        // The same rows again — a re-pull from a cursor that was never persisted.
        let again = try await transport.pull(after: 0, kitchenID: kitchenA)
        try repository.applyRemote(again.ops, cursor: again.cursor, kitchenID: kitchenA)

        XCTAssertEqual(try repository.items(), afterFirst, "a redelivered op is a no-op")
        XCTAssertEqual(try repository.items().count, 1)
        XCTAssertTrue(try repository.unpushedOps().isEmpty, "remote ops are never re-pushed")
    }
}
