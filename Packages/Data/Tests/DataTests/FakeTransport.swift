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
    /// Every push the engine ATTEMPTED, refusals included — `pushCount` only counts the ones
    /// that landed, so it cannot tell a bounded retry from a loop.
    private(set) var pushAttempts = 0
    private(set) var lastPullCursor: Int64?
    private var knownOpIDs: Set<OpID> = []
    private var pushError: Error?
    private var pullError: Error?
    private var refusedOpIDs: Set<OpID> = []
    private var latency: Duration?

    var storedOps: [Op] { rows.map(\.op) }

    func setPushError(_ error: Error?) { pushError = error }
    func setPullError(_ error: Error?) { pullError = error }
    func setLatency(_ latency: Duration?) { self.latency = latency }

    /// Refuses like the server does, not more kindly: `op_insert`'s WITH CHECK aborts the WHOLE
    /// statement (42501 → 403), so a batch holding one refused op stores none of it and the
    /// client is told only that it was refused — never which op it was.
    func setRefusedOpIDs(_ ids: Set<OpID>) { refusedOpIDs = ids }

    func push(_ ops: [Op]) async throws {
        if let latency { try await Task.sleep(for: latency) }
        pushAttempts += 1
        if let pushError { throw pushError }
        if ops.contains(where: { refusedOpIDs.contains($0.opID) }) {
            throw SupabaseTransportError.rejected(status: 403, code: "42501")
        }
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
