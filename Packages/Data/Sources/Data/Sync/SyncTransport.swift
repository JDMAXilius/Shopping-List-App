import Core

// The seam Supabase plugs into; nothing above this layer knows Supabase exists.
public protocol SyncTransport: Sendable {
    // MUST be idempotent on op id: implement via the push_ops RPC (ON CONFLICT DO NOTHING),
    // never bare .insert() — a duplicate id 409s the whole batch. Re-delivery is the normal case.
    func push(_ ops: [Op]) async throws

    // Returns ops with server sequence > cursor, ordered by that sequence. Commit-ordered
    // per kitchen (server advisory-lock trigger), so a pulled cursor never skips an op.
    func pull(after cursor: Int64, kitchenID: KitchenID) async throws -> (ops: [Op], cursor: Int64)
}
