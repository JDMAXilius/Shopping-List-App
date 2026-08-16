import GRDB
import Observation

// Bridges GRDB's ValueObservation to @Observable, the one read path (ARCHITECTURE §5).
@MainActor @Observable
public final class Observed<Value: Sendable> {
    public private(set) var value: Value

    // Releasing the cancellable (on deinit) stops the observation.
    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?
    @ObservationIgnored private let database: AppDatabase
    @ObservationIgnored private let fetch: @Sendable (Database) throws -> Value

    public init(initial: Value, database: AppDatabase,
                fetch: @escaping @Sendable (Database) throws -> Value) {
        value = initial
        self.database = database
        self.fetch = fetch
        cancellable = ValueObservation
            .tracking(fetch)
            .start(
                in: database.pool,
                scheduling: .async(onQueue: .main),
                // Sync is invisible: on error, keep showing the last known value.
                onError: { _ in },
                onChange: { [weak self] newValue in
                    MainActor.assumeIsolated { self?.value = newValue }
                })
    }

    // ValueObservation sees only this pool's writes; the app must refresh on
    // scenePhase.active / a Darwin notification (wiring is app-layer, wave 8).
    public func refresh() {
        if let fresh = try? database.pool.read(fetch) { value = fresh }
    }
}
