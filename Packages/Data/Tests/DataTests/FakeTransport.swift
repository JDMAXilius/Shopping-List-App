import Core
import Foundation
import Data

struct TransportFailure: Error {}

/// In-memory op store standing in for Supabase, and matching `SupabaseTransport` where it
/// counts: push is idempotent on op id (push_ops is ON CONFLICT DO NOTHING, so a redelivered
/// batch succeeds), and the pull cursor is the SEQ OF THE LAST ROW DELIVERED — one global
/// sequence shared by every kitchen, exactly as `op_seq` is. A fake that answered the global
/// count instead would hand back a cursor past ops it never delivered.
actor FakeTransport: SyncTransport {
    private struct StoredOp {
        let seq: Int64
        let op: Op
    }

    private var rows: [StoredOp] = []
    private var nextSeq: Int64 = 0
    private(set) var pushCount = 0
    private(set) var lastPullCursor: Int64?
    private var knownOpIDs: Set<OpID> = []
    private var pushError: Error?
    private var pullError: Error?
    private var latency: Duration?

    var storedOps: [Op] { rows.map(\.op) }

    func setPushError(_ error: Error?) { pushError = error }
    func setPullError(_ error: Error?) { pullError = error }
    func setLatency(_ latency: Duration?) { self.latency = latency }

    func push(_ ops: [Op]) async throws {
        if let latency { try await Task.sleep(for: latency) }
        if let pushError { throw pushError }
        pushCount += 1
        for op in ops where knownOpIDs.insert(op.opID).inserted {
            nextSeq += 1
            rows.append(StoredOp(seq: nextSeq, op: op))
        }
    }

    func pull(after cursor: Int64, kitchenID: KitchenID) async throws -> (ops: [Op], cursor: Int64) {
        if let latency { try await Task.sleep(for: latency) }
        if let pullError { throw pullError }
        lastPullCursor = cursor
        let page = rows
            .filter { $0.seq > cursor && $0.op.kitchenID == kitchenID }
            .sorted { $0.seq < $1.seq }
        return (page.map(\.op), page.last?.seq ?? cursor)
    }
}
