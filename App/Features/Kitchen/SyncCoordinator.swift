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
    /// Ops the server REFUSED and the engine is holding. Separate from `pending` because nothing
    /// is being attempted for them: folding the two together is how a screen ends up saying it is
    /// still trying over an edit nothing will ever retry.
    private(set) var refused = 0

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
        SyncCoordinator.sentence(status: status, pending: pending, refused: refused)
    }

    /// A pure function of the three numbers, so every sentence this app says about sync can be
    /// tested without a database, a server or a running app — the instance property is only the
    /// three current values passed in.
    static func sentence(status: SyncStatus, pending: Int, refused: Int) -> String {
        switch status {
        case .local: return "On this phone only."
        case .syncing: return "Catching up…"
        case .synced: return "Everyone's up to date."
        case .offline:
            return pending == 0
                ? "No signal — everything still works."
                : "No signal — \(SyncCoordinator.count(pending)) will send when it's back."
        case .stuck:
            // A refused change is not a change that is still being tried, so "still trying" is a
            // lie the moment one exists. The phone does not know WHY the kitchen refused it — an
            // eviction and a broken session look identical from here — so it says the two things
            // it does know: the kitchen would not take them, and they are still here.
            if refused > 0 {
                let held = "\(SyncCoordinator.count(refused)) your kitchen wouldn't take"
                let safe = refused == 1 ? "It's safe on this phone." : "They're safe on this phone."
                return pending == 0
                    ? "\(held). \(safe)"
                    : "\(held). \(safe) \(SyncCoordinator.count(pending)) still to send."
            }
            return pending == 0
                ? "Still trying to reach your kitchen."
                : "\(SyncCoordinator.count(pending)) \(pending == 1 ? "hasn't" : "haven't") sent yet. "
                    + "\(pending == 1 ? "It's" : "They're") safe on this phone."
        }
    }

    /// "1 change" / "3 changes". Its own function because the singular used to be read out with a
    /// plural verb — "1 change haven't sent yet" — which is the kind of thing that makes a person
    /// distrust the number beside it.
    static func count(_ n: Int) -> String { "\(n) change\(n == 1 ? "" : "s")" }

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
        refused = await engine.refused
    }
}
