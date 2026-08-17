import Core
import Foundation
import GRDB

public enum SyncStatus: String, Sendable {
    /// No remote peer for this kitchen — nothing has been asked of a server, and the local
    /// database is the whole truth. A solo kitchen is not "synced" (nothing agreed with
    /// anyone) and it is certainly not "offline" (nothing failed).
    case local
    /// Everything this kitchen owed has been accepted AND nothing is quarantined. Never said
    /// over a refused edit: the server taking three of four ops is not agreement.
    case synced
    case syncing, offline
    /// This will not fix itself: the backoff has failed `stuckAfter` times in a row, or ops are
    /// quarantined — refused by the server and held, with no attempt scheduled for them.
    ///
    /// No new case for the quarantine: the meaning is identical ("nothing more happens until
    /// something changes") and `SyncEngine.refused` says which of the two it is, whereas a new case
    /// would need every exhaustive switch above this layer to grow a branch before it compiled.
    case stuck
}

// No timers in here: scheduling is the caller's problem; kick() is the only entry point.
public actor SyncEngine {
    private let repository: Repository
    private let transport: any SyncTransport
    private let kitchenID: KitchenID
    private let baseBackoff: TimeInterval
    private let maxBackoff: TimeInterval
    private let stuckAfter: Int
    private let refusalLimit: Int
    private let retryRefusedAfter: TimeInterval
    private let now: @Sendable () -> Date

    // Before the first kick nothing has been agreed with anyone; saying `.synced` would claim
    // a round-trip that never happened.
    public private(set) var status: SyncStatus = .local
    /// Ops THIS kitchen still owes the server. A queue that has not drained is not "synced",
    /// and the number is what a screen can say honestly without inventing a spinner.
    public private(set) var pending = 0
    /// Ops of this kitchen the server REFUSED and this device is holding. Not pending — nothing
    /// is being attempted for them — and not saved either, so they are their own number: folding
    /// them into `pending` would promise they are on their way, and hiding them would say a
    /// refused edit never happened.
    public private(set) var refused = 0
    private var failureCount = 0
    private var nextAttempt = Date.distantPast
    private var inFlight = false

    /// The release bound, both halves. `refusalLimit` 3: an op is pushed three times and then held
    /// for good, so no doomed batch rides every poll for the life of the install.
    /// `retryRefusedAfter` 1h: three pushes 20 seconds apart would burn the whole allowance before
    /// anyone could re-invite this device, which would make "reversible" a word and not a fact.
    public init(repository: Repository, transport: any SyncTransport, kitchenID: KitchenID,
                baseBackoff: TimeInterval = 1, maxBackoff: TimeInterval = 60, stuckAfter: Int = 5,
                refusalLimit: Int = 3, retryRefusedAfter: TimeInterval = 3600,
                now: @escaping @Sendable () -> Date = Date.init) {
        self.repository = repository
        self.transport = transport
        self.kitchenID = kitchenID
        self.baseBackoff = baseBackoff
        self.maxBackoff = maxBackoff
        self.stuckAfter = stuckAfter
        self.refusalLimit = refusalLimit
        self.retryRefusedAfter = retryRefusedAfter
        self.now = now
    }

    // Out-of-process writers (widget/intent) must run a one-shot kick or signal the app
    // before returning; ops are never lost, only delayed — wave 8 owns that wiring.
    public func kick() async {
        guard !inFlight, now() >= nextAttempt else { return }
        inFlight = true
        defer { inFlight = false }
        status = .syncing
        do {
            try await drain()
            try await pull()
            try await retryRefused()
            failureCount = 0
            nextAttempt = .distantPast
            refreshCounts()
            // A nonzero pending here is an op another process appended mid-kick, which the next
            // kick ships. A refused op is what no kick fixes, so it is what stops `.synced`.
            status = refused > 0 ? .stuck : .synced
        } catch {
            refreshCounts()
            failureCount += 1
            // 1s·2^n capped at 60s; until the window passes, kick() is a no-op.
            let delay = min(baseBackoff * pow(2, Double(failureCount - 1)), maxBackoff)
            nextAttempt = now().addingTimeInterval(delay)
            status = (failureCount >= stuckAfter || refused > 0) ? .stuck : .offline
        }
    }

    private func drain() async throws {
        let ops = try unpushed()
        guard !ops.isEmpty else { return }
        try await pushOrQuarantine(ops)
    }

    /// A refusal is not a failed kick: `rejected` is the server refusing the write itself (RLS,
    /// 42501 → 403), which no retry changes, so the batch leaves the queue — kept, unpushed,
    /// payload intact — and this returns normally. That is what lets the NEXT op through; before
    /// it, one refusal queued every later op behind it forever.
    /// The whole batch goes, because a 403 does not say which op offended and guessing would
    /// strand a good one. Everything else throws to the caller's ordinary backoff.
    private func pushOrQuarantine(_ ops: [Op]) async throws {
        do {
            try await transport.push(ops)
        } catch let error as SupabaseTransportError {
            guard case .rejected = error else { throw error }
            try repository.markQuarantined(ops.map(\.opID), at: now())
            return
        }
        try repository.markPushed(ops.map(\.opID))
    }

    /// A pull that answered proves this session can still READ this kitchen — membership is real
    /// again (re-invited, token refreshed, the server was wrong) — so the release is that pull and
    /// this is the retry it earns. Bounded three ways, because a quiet infinite retry is worse than
    /// the wedge this fixes: at most `refusalLimit` pushes per op, `op.quarantine_count` surviving
    /// the release so relaunching does not reset it; no sooner than `retryRefusedAfter` since the
    /// last refusal; and as their OWN batch, never rejoining the queue — a 403 on a retry would
    /// otherwise drag every op made after them back into quarantine.
    private func retryRefused() async throws {
        let held = try repository.quarantinedOps(
            kitchenID: kitchenID, refusedFewerThan: refusalLimit,
            refusedBefore: now().addingTimeInterval(-retryRefusedAfter))
        guard !held.isEmpty else { return }
        try await pushOrQuarantine(held)
    }

    private func refreshCounts() {
        pending = (try? unpushed().count) ?? pending
        refused = (try? repository.quarantinedOps(kitchenID: kitchenID).count) ?? refused
    }

    /// One engine speaks for ONE kitchen. A device that has a local-only kitchen and a shared
    /// one (every guest does — the phone made its own kitchen before the invite arrived) must
    /// not ship the local one's ops under this kitchen's session: RLS refuses the whole batch
    /// (42501) and the queue wedges forever. Marking them pushed instead would be worse — a
    /// drain that did not push them would lose them for good.
    private func unpushed() throws -> [Op] {
        try repository.unpushedOps().filter { $0.kitchenID == kitchenID }
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
