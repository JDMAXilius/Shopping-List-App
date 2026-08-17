import Core
import Foundation
import Observation

/// The half of a shop that never syncs. `ListStore` writes shops as ops because a household
/// shares its shops; this writes pins to one local file because a household does not share a
/// geofence. The transport cannot reach it: `SyncEngine` pushes what `Repository` holds, and
/// nothing here ever appends an op.
@Observable @MainActor
final class PlaceStore {
    /// A fence wobbles at the door. Once a trip is enough — the second switch would land while
    /// the phone is already out and being read.
    static let arrivalCooldown: TimeInterval = 30 * 60

    private(set) var places: [ShopID: Place] = [:]

    /// Wired by the app: an arrival points the list at that shop, and does nothing else.
    @ObservationIgnored var onArrival: ((ShopID) -> Void)?

    @ObservationIgnored let location: LocationService
    @ObservationIgnored let file: URL

    init(location: LocationService = LocationService(), directory: URL? = nil) {
        self.location = location
        file = (directory ?? Self.defaultDirectory).appendingPathComponent("places.json")
        load()
        location.onArrival = { [weak self] identifier in self?.arrived(identifier) }
        location.monitor(monitored.map(\.fence))
    }

    // MARK: - Reads

    var permission: LocationService.Permission { location.permission }
    var canPin: Bool { permission.canLocate }

    func place(_ shopID: ShopID) -> Place? { places[shopID] }

    var monitored: [Place] { Place.monitored(Array(places.values)) }

    /// Armed pins iOS has no room to watch. Said on screen, never quietly dropped.
    var waiting: Int {
        max(0, places.values.filter(\.wakeEnabled).count - monitored.count)
    }

    // MARK: - Permission

    func requestPermission() { location.requestWhenInUse() }

    /// Only offered once a pin exists and the lesser grant is already given — see `ShopEditorScreen`.
    func requestBackgroundPermission() { location.requestAlways() }

    // MARK: - Writes

    /// Pins the shop to where the phone is standing, and that is the only way to make a pin: a
    /// "search nearby" box sends a coordinate to somebody's server, which is the one thing this
    /// app promises not to do.
    @discardableResult
    func pinHere(_ shopID: ShopID) async -> Bool {
        guard let fix = await location.currentFix() else { return false }
        setPin(fix, for: shopID)
        return true
    }

    func setPin(_ fix: LocationService.Fix, for shopID: ShopID) {
        let existing = places[shopID]
        places[shopID] = Place(shopID: shopID, latitude: fix.latitude, longitude: fix.longitude,
                               accuracy: fix.accuracy, pinnedAt: fix.takenAt,
                               radius: existing?.radius ?? Place.defaultRadius,
                               wakeEnabled: existing?.wakeEnabled ?? true,
                               lastArrival: existing?.lastArrival)
        save()
    }

    func removePin(_ shopID: ShopID) {
        guard places[shopID] != nil else { return }
        places[shopID] = nil
        save()
    }

    func setRadius(_ radius: Double, for shopID: ShopID) {
        guard var place = places[shopID] else { return }
        place.radius = min(max(radius, Place.radiusRange.lowerBound),
                           Place.radiusRange.upperBound)
        places[shopID] = place
        save()
    }

    func setWake(_ enabled: Bool, for shopID: ShopID) {
        guard var place = places[shopID], place.wakeEnabled != enabled else { return }
        place.wakeEnabled = enabled
        places[shopID] = place
        save()
    }

    /// A shop that no longer exists takes its pin with it — including one deleted on the other
    /// phone, which reaches us as an op and never mentions this file.
    func prune(to shops: [ShopID]) {
        let live = Set(shops)
        let kept = places.filter { live.contains($0.key) }
        guard kept.count != places.count else { return }
        places = kept
        save()
    }

    private func arrived(_ identifier: String) {
        guard let uuid = UUID(uuidString: identifier) else { return }
        let shopID = ShopID(uuid)
        guard var place = places[shopID], place.wakeEnabled else { return }
        let now = Date()
        if let last = place.lastArrival, now.timeIntervalSince(last) < Self.arrivalCooldown {
            return
        }
        place.lastArrival = now
        places[shopID] = place
        save()
        onArrival?(shopID)
    }

    // MARK: - The file

    /// The watched set is derived and never edited: every write recomputes it, so the 20 iOS
    /// allows are always the 20 this store would name today.
    private func save() {
        location.monitor(monitored.map(\.fence))
        let ordered = places.values.sorted {
            $0.shopID.rawValue.uuidString < $1.shopID.rawValue.uuidString
        }
        guard let data = try? JSONEncoder().encode(ordered) else { return }
        let directory = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        excludeFromBackup(directory)
        // Readable after a reboot before the first unlock, because a fence can fire then.
        try? data.write(to: file,
                        options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        excludeFromBackup(file)
    }

    private func load() {
        guard let data = try? Foundation.Data(contentsOf: file),
              let stored = try? JSONDecoder().decode([Place].self, from: data) else { return }
        places = Dictionary(stored.map { ($0.shopID, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// An iCloud backup is off-device, and "never leaves the phone" has to mean the backup too.
    private func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    /// Application Support, NOT the App Group container: the group is the surface the widget and
    /// the intents read, and a pin has no business being reachable from either.
    private static var defaultDirectory: URL {
        let root = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask, appropriateFor: nil,
                                                create: true)
        return (root ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("Places", isDirectory: true)
    }
}
