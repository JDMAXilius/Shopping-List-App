import Core
import Foundation
import Data

struct TransportFailure: Error {}

// In-memory op store standing in for Supabase; cursor is an index into the global op array.
actor FakeTransport: SyncTransport {
    private(set) var storedOps: [Op] = []
    private(set) var pushCount = 0
    private(set) var lastPullCursor: Int64?
    private var knownOpIDs: Set<OpID> = []
    private var pushError: Error?
    private var pullError: Error?
    private var latency: Duration?

    func setPushError(_ error: Error?) { pushError = error }
    func setPullError(_ error: Error?) { pullError = error }
    func setLatency(_ latency: Duration?) { self.latency = latency }

    func push(_ ops: [Op]) async throws {
        if let latency { try await Task.sleep(for: latency) }
        if let pushError { throw pushError }
        pushCount += 1
        for op in ops where knownOpIDs.insert(op.opID).inserted {
            storedOps.append(op)
        }
    }

    func pull(after cursor: Int64, kitchenID: KitchenID) async throws -> (ops: [Op], cursor: Int64) {
        if let latency { try await Task.sleep(for: latency) }
        if let pullError { throw pullError }
        lastPullCursor = cursor
        let start = min(max(Int(cursor), 0), storedOps.count)
        let ops = storedOps[start...].filter { $0.kitchenID == kitchenID }
        return (ops, Int64(storedOps.count))
    }
}
