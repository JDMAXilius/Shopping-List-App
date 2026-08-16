import Core

// The seam Supabase plugs into; nothing above this layer knows Supabase exists.
public protocol SyncTransport: Sendable {
    // MUST be idempotent on op id: the server upserts ignoring duplicate ids;
    // re-delivery after a crash-before-markPushed is the normal case, not an error.
    func push(_ ops: [Op]) async throws

    // Returns ops with server sequence > cursor, ordered by that sequence
    // (cursor = server-assigned bigserial, gap-free monotonic per kitchen).
    func pull(after cursor: Int64, kitchenID: KitchenID) async throws -> (ops: [Op], cursor: Int64)
}
