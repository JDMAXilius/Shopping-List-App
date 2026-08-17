import CoreLocation
import Foundation
import Observation

/// The only file in the app that imports CoreLocation. Everything it hands back is a plain
/// value — no `CLLocation`, no `CLMonitor`, no manager — so nothing above it can hold, log or
/// upload something it did not deliberately ask for (ARCHITECTURE §3).
@Observable @MainActor
final class LocationService {
    /// iOS watches 20 regions per app, app-wide and unnegotiable. WHICH 20 is `Place.monitored`'s
    /// decision; this only refuses to hand the system more than it will honour.
    static let fenceLimit = 20
    /// CLMonitor state outlives the process and is keyed by this name, so it must never change.
    private static let monitorName = "app.bagged.places"

    enum Permission: Sendable, Hashable {
        case notAsked
        case denied
        case whileUsing
        case always

        var canLocate: Bool { self == .whileUsing || self == .always }
    }

    /// A fix reduced to numbers. Its description is deliberately coordinate-free: a stray
    /// `print`, a crash report or an error dump of this value must not carry someone's address.
    struct Fix: Sendable, Equatable, CustomStringConvertible {
        let latitude: Double
        let longitude: Double
        /// Metres of horizontal uncertainty. CoreLocation reports negative for "invalid".
        let accuracy: Double
        let takenAt: Date

        var description: String { "Fix(±\(Int(accuracy.rounded()))m)" }
    }

    struct Fence: Sendable, Hashable {
        let id: String
        let latitude: Double
        let longitude: Double
        let radius: Double
    }

    private(set) var permission: Permission

    /// The fence id that was entered. Arrival re-points the list and does nothing else — there
    /// is no notification here, and PRODUCT is why: nothing in this app asks to be opened.
    @ObservationIgnored var onArrival: ((String) -> Void)?

    @ObservationIgnored private let manager: CLLocationManager?
    @ObservationIgnored private let forwarder = Forwarder()
    @ObservationIgnored private var pendingFix: CheckedContinuation<Fix?, Never>?
    @ObservationIgnored private var fences: [Fence] = []
    @ObservationIgnored private var watch: Task<Void, Never>?

    /// A nil manager is a device with no CoreLocation to talk to, which behaves exactly like one
    /// that refused permission — the state every screen already has to work in, and the one the
    /// tests run in, since a simulator-less machine cannot exercise the real thing.
    init(manager: CLLocationManager? = CLLocationManager()) {
        self.manager = manager
        permission = manager.map { Self.permission(for: $0.authorizationStatus) } ?? .denied
        manager?.delegate = forwarder
        forwarder.service = self
    }

    // MARK: - Permission

    /// `whenInUse` first, always. A wake-up radius really wants `always`, but asking for it cold
    /// is how an app gets refused permanently, and a refusal has no second chance.
    func requestWhenInUse() {
        guard permission == .notAsked else { return }
        manager?.requestWhenInUseAuthorization()
    }

    /// The one upgrade iOS allows, from an explicit tap and only once `whileUsing` is in hand.
    /// Without it a fence can only fire while the app is already open, which is worth saying.
    func requestAlways() {
        guard permission == .whileUsing else { return }
        manager?.requestAlwaysAuthorization()
    }

    static func permission(for status: CLAuthorizationStatus) -> Permission {
        switch status {
        case .notDetermined: return .notAsked
        case .authorizedAlways: return .always
        case .authorizedWhenInUse: return .whileUsing
        // Denied and restricted have one consequence between them, so they get one word.
        default: return .denied
        }
    }

    // MARK: - One fix

    /// One fix, or nil for every way there is of not getting one — off, denied, no signal, a fix
    /// the system itself calls invalid. The caller behaves identically for all of them.
    func currentFix() async -> Fix? {
        guard let manager, permission.canLocate, pendingFix == nil else { return nil }
        return await withCheckedContinuation { continuation in
            pendingFix = continuation
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            manager.requestLocation()
        }
    }

    // MARK: - Fences

    /// Replaces the watched set whole.
    func monitor(_ wanted: [Fence]) {
        let capped = Self.capped(wanted)
        // The first call of a launch always runs: the system's set survives process death, so
        // "watch nothing" is a real instruction — a pin deleted last launch must stop firing.
        guard capped != fences || watch == nil else { return }
        fences = capped
        restartWatch()
    }

    static func capped(_ wanted: [Fence]) -> [Fence] {
        Array(wanted.prefix(fenceLimit))
    }

    private func restartWatch() {
        watch?.cancel()
        guard manager != nil, permission.canLocate else {
            watch = nil
            return
        }
        watch = Task { [weak self] in await self?.reconcile() }
    }

    private func reconcile() async {
        let wanted = fences
        let monitor = await CLMonitor(Self.monitorName)
        for identifier in await monitor.identifiers
        where !wanted.contains(where: { $0.id == identifier }) {
            await monitor.remove(identifier)
        }
        for fence in wanted {
            let centre = CLLocationCoordinate2D(latitude: fence.latitude,
                                                longitude: fence.longitude)
            await monitor.add(
                CLMonitor.CircularGeographicCondition(center: centre, radius: fence.radius),
                identifier: fence.id)
        }
        guard !wanted.isEmpty else { return }
        do {
            for try await event in await monitor.events {
                guard !Task.isCancelled else { return }
                guard event.state == .satisfied else { continue }
                onArrival?(event.identifier)
            }
        } catch {
            // Monitoring stopped. There is nothing to tell the user: a list that does not wake
            // by itself is the same list, and the switcher is one tap away.
        }
    }

    // MARK: - Delegate hops

    fileprivate func adopt(_ status: CLAuthorizationStatus) {
        permission = Self.permission(for: status)
        // A refusal mid-ask fails the waiting fix, like every other way of not getting one.
        if !permission.canLocate { deliver(nil) }
        restartWatch()
    }

    fileprivate func deliver(_ fix: Fix?) {
        guard let continuation = pendingFix else { return }
        pendingFix = nil
        // A fix CoreLocation itself marks invalid is not a pin — better no pin than a wrong one.
        continuation.resume(returning: fix.flatMap { $0.accuracy > 0 ? $0 : nil })
    }
}

// CLLocationManager wants an NSObject delegate and `@Observable` does not want to be one, so
// the conformance sits here and hops to the main actor carrying plain values only.
private final class Forwarder: NSObject, CLLocationManagerDelegate {
    weak var service: LocationService?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [service] in service?.adopt(status) }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let fix = LocationService.Fix(latitude: last.coordinate.latitude,
                                      longitude: last.coordinate.longitude,
                                      accuracy: last.horizontalAccuracy, takenAt: last.timestamp)
        Task { @MainActor [service] in service?.deliver(fix) }
    }

    // The error is deliberately not read: every failure has the same answer, and its
    // description can carry the region it failed in.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [service] in service?.deliver(nil) }
    }
}
