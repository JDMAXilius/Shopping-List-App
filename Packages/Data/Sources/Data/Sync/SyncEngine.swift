import Core
import Foundation
import GRDB

public enum SyncStatus: String, Sendable {
    case synced, syncing, offline, stuck
}

// No timers in here: scheduling is the caller's problem; kick() is the only entry point.
public actor SyncEngine {
    private let repository: Repository
    private let transport: any SyncTransport
    private let kitchenID: KitchenID
    private let baseBackoff: TimeInterval
    private let maxBackoff: TimeInterval
    private let stuckAfter: Int

    public private(set) var status: SyncStatus = .synced
    private var failureCount = 0
    private var nextAttempt = Date.distantPast
    private var inFlight = false

    public init(repository: Repository, transport: any SyncTransport, kitchenID: KitchenID,
                baseBackoff: TimeInterval = 1, maxBackoff: TimeInterval = 60, stuckAfter: Int = 5) {
        self.repository = repository
        self.transport = transport
        self.kitchenID = kitchenID
        self.baseBackoff = baseBackoff
        self.maxBackoff = maxBackoff
        self.stuckAfter = stuckAfter
    }

    public func kick() async {
        guard !inFlight, Date() >= nextAttempt else { return }
        inFlight = true
        defer { inFlight = false }
        status = .syncing
        do {
            try await drain()
            try await pull()
            failureCount = 0
            nextAttempt = .distantPast
            status = .synced
        } catch {
            failureCount += 1
            // 1s·2^n capped at 60s; until the window passes, kick() is a no-op.
            let delay = min(baseBackoff * pow(2, Double(failureCount - 1)), maxBackoff)
            nextAttempt = Date().addingTimeInterval(delay)
            status = failureCount >= stuckAfter ? .stuck : .offline
        }
    }

    private func drain() async throws {
        let ops = try repository.unpushedOps()
        guard !ops.isEmpty else { return }
        try await transport.push(ops)
        try repository.markPushed(ops.map(\.opID))
    }

    private func pull() async throws {
        let cursor = try repository.syncCursor(kitchenID: kitchenID)
        let result = try await transport.pull(after: cursor, kitchenID: kitchenID)
        try repository.applyRemote(result.ops, cursor: result.cursor, kitchenID: kitchenID)
    }
}

struct SyncStateRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "sync_state"

    var kitchenID: String
    var cursor: Int64

    enum CodingKeys: String, CodingKey {
        case kitchenID = "kitchen_id"
        case cursor
    }
}
