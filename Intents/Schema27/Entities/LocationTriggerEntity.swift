import AppIntents
import Foundation
import GeoToolbox

/// Bagged wakes the whole list when you arrive at a shop; it has no per-item place alarm, and
/// geofences never leave the phone. The schema requires this type, so it exists and answers
/// truthfully: there are none.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.locationTrigger)
struct LocationTriggerEntity {
    static let defaultQuery = LocationTriggerEntityQuery()

    let id: UUID

    var place: PlaceDescriptor
    var event: LocationTriggerEvent

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Place reminder")
    }
}

@available(iOS 27.0, *)
@AppEnum(schema: .reminders.locationTriggerEvent)
enum LocationTriggerEvent: String {
    case arrive
    case depart

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .arrive: "Arrive",
        .depart: "Depart",
    ]
}

@available(iOS 27.0, *)
struct LocationTriggerEntityQuery: EntityQuery {
    func entities(for identifiers: [LocationTriggerEntity.ID]) async throws -> [LocationTriggerEntity] {
        []
    }
}
