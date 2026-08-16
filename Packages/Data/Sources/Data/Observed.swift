import GRDB
import Observation

// Bridges GRDB's ValueObservation to @Observable, the one read path (ARCHITECTURE §5).
@MainActor @Observable
public final class Observed<Value: Sendable> {
    public private(set) var value: Value

    // Releasing the cancellable (on deinit) stops the observation.
    @ObservationIgnored private var cancellable: AnyDatabaseCancellable?

    public init(initial: Value, database: AppDatabase,
                fetch: @escaping @Sendable (Database) throws -> Value) {
        value = initial
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
}
