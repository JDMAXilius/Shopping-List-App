import AppIntents
import Core
import Foundation

/// The schema says "lists", the app has one per kitchen — so a list IS a kitchen here, named
/// with the household's own word for itself. Nothing plural is invented to fill the vocabulary.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.list)
struct ListEntity {
    static let defaultQuery = ListEntityQuery()

    let id: UUID

    var name: String
    var type: ListType

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 27.0, *)
extension ListEntity {
    init(_ kitchen: Kitchen) {
        id = kitchen.id.rawValue
        name = kitchen.name
        type = .standard
    }

    @MainActor
    static func all() throws -> [ListEntity] {
        try IntentContext.current().repository.kitchens().map(ListEntity.init)
    }
}

/// Bagged has one kind of list. The schema offers one case and the app means exactly it.
@available(iOS 27.0, *)
@AppEnum(schema: .reminders.listType)
enum ListType: String {
    case standard

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .standard: "Standard"
    ]
}

@available(iOS 27.0, *)
struct ListEntityQuery: EntityQuery {
    func entities(for identifiers: [ListEntity.ID]) async throws -> [ListEntity] {
        let wanted = Set(identifiers)
        return try await MainActor.run { try ListEntity.all().filter { wanted.contains($0.id) } }
    }

    func suggestedEntities() async throws -> [ListEntity] {
        try await MainActor.run { try ListEntity.all() }
    }
}
