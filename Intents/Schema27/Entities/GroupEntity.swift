import AppIntents
import Core
import Foundation

/// The schema's group of lists is Bagged's kitchen: the household that holds the list. Today it
/// holds exactly one, which is a fact about v1, not a shape this entity pretends away.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.group)
struct GroupEntity {
    static let defaultQuery = GroupEntityQuery()

    let id: UUID

    var name: String
    var lists: [ListEntity]

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 27.0, *)
extension GroupEntity {
    init(_ kitchen: Kitchen) {
        id = kitchen.id.rawValue
        name = kitchen.name
        lists = [ListEntity(kitchen)]
    }

    @MainActor
    static func all() throws -> [GroupEntity] {
        try IntentContext.current().repository.kitchens().map(GroupEntity.init)
    }
}

@available(iOS 27.0, *)
struct GroupEntityQuery: EntityQuery {
    func entities(for identifiers: [GroupEntity.ID]) async throws -> [GroupEntity] {
        let wanted = Set(identifiers)
        return try await MainActor.run { try GroupEntity.all().filter { wanted.contains($0.id) } }
    }

    func suggestedEntities() async throws -> [GroupEntity] {
        try await MainActor.run { try GroupEntity.all() }
    }
}
