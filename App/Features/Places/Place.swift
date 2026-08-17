import Core
import Foundation

/// A shop's pin, its wake-up radius and whether it is armed. Deliberately NOT fields on `Shop`:
/// a `Shop` is an op and ops sync, so a coordinate written there would be uploaded the moment
/// somebody shares their kitchen. This type is never converted to an `Op.Kind`, anywhere.
struct Place: Hashable, Sendable, Codable, CustomStringConvertible {
    let shopID: ShopID
    var latitude: Double
    var longitude: Double
    /// Metres of horizontal uncertainty in the fix this pin was taken from.
    var accuracy: Double
    var pinnedAt: Date
    var radius: Double
    var wakeEnabled: Bool
    var lastArrival: Date?

    /// Coordinate-free on purpose: a stray print or an error dump of this value must not carry
    /// somebody's front door.
    var description: String {
        "Place(\(shopID.rawValue.uuidString), r=\(Int(radius))m, wake=\(wakeEnabled))"
    }
}

extension Place {
    static let defaultRadius: Double = 150
    /// Below ~100 m a geofence fires late, twice, or never; past 500 m "you have arrived" stops
    /// being true. Both ends are the honest limits of the mechanism, not a taste.
    static let radiusRange: ClosedRange<Double> = 100...500

    /// The last time this place meant anything — an arrival if there has been one, the pin if not.
    var recency: Date { lastArrival.map { Swift.max($0, pinnedAt) } ?? pinnedAt }

    var fence: LocationService.Fence {
        LocationService.Fence(id: shopID.rawValue.uuidString, latitude: latitude,
                              longitude: longitude, radius: radius)
    }

    /// iOS watches 20 regions per app, so with 30 shops SOMETHING picks 20 — and it must be the
    /// same 20 after a relaunch, or arrivals become luck. The rule: armed pins, most recently
    /// arrived-at or pinned first, ties broken by id so the order is total.
    static func monitored(_ places: [Place], limit: Int = LocationService.fenceLimit) -> [Place] {
        let ranked = places.filter(\.wakeEnabled).sorted { first, second in
            if first.recency != second.recency { return first.recency > second.recency }
            return first.shopID.rawValue.uuidString < second.shopID.rawValue.uuidString
        }
        return Array(ranked.prefix(limit))
    }
}
