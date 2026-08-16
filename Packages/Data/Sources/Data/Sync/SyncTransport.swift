import Core

// The seam Supabase plugs into; nothing above this layer knows Supabase exists.
public protocol SyncTransport: Sendable {
    func push(_ ops: [Op]) async throws
    func pull(after cursor: Int64, kitchenID: KitchenID) async throws -> (ops: [Op], cursor: Int64)
}
