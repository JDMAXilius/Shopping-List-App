import Core
import Data
import Foundation

/// The scheduler `SyncEngine` deliberately does not have. Polling on foreground plus a kick
/// after each local write is the honest v1: correctness comes from the cursor, so a missed
/// poll costs latency and never an op. (Realtime, if it ever lands, is only an accelerator.)
///
/// No spinner is offered anywhere here. The app is local-first and a pending queue is normal:
/// the status says what is true and the list never waits for it.
@Observable @MainActor
final class SyncCoordinator {
    /// Long enough that a phone in a pocket is not a battery story, short enough that a
    /// partner's add lands while you are still in the aisle.
    static let pollInterval: Duration = .seconds(20)

    private let engine: SyncEngine?
    private var loop: Task<Void, Never>?

    /// `.local` is the truth for a phone with no kitchen to share: nothing failed, nothing is
    /// waiting, and there is no server in this kitchen's story yet.
    private(set) var status: SyncStatus = .local
    /// Ops this kitchen still owes the server. A queue that has not drained is not "synced".
    private(set) var pending = 0

    init(repository: Repository?, kitchenID: KitchenID?, transport: (any SyncTransport)?) {
        guard let repository, let kitchenID, let transport else {
            engine = nil
            return
        }
        engine = SyncEngine(repository: repository, transport: transport, kitchenID: kitchenID)
    }

    var isSharing: Bool { engine != nil }

    /// What a screen can say without inventing a state. Never "failed": an offline phone with
    /// a queue is a phone that is working exactly as designed.
    var sentence: String {
        switch status {
        case .local: return "On this phone only."
        case .syncing: return "Catching up…"
        case .synced: return "Everyone's up to date."
        case .offline:
            return pending == 0
                ? "No signal — everything still works."
                : "No signal — \(pending) change\(pending == 1 ? "" : "s") will send when it's back."
        case .stuck:
            return pending == 0
                ? "Still trying to reach your kitchen."
                : "\(pending) change\(pending == 1 ? "" : "s") haven't sent yet. They're safe on this phone."
        }
    }

    /// Called on foreground, after a local write, and on the poll. Cheap when there is nothing
    /// to do: the engine's own backoff window makes an early kick a no-op.
    func kick() {
        guard let engine else { return }
        Task { [weak self] in
            await engine.kick()
            await self?.adopt(from: engine)
        }
    }

    func start() {
        guard engine != nil, loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.kick()
                try? await Task.sleep(for: SyncCoordinator.pollInterval)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    private func adopt(from engine: SyncEngine) async {
        status = await engine.status
        pending = await engine.pending
    }
}
