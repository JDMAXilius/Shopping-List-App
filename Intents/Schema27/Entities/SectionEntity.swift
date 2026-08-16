import AppIntents
import Core
import DesignKit
import Foundation

/// A section is an aisle. Bagged's aisles are the catalog's 22 categories, not rows a person
/// makes, so this entity enumerates what already exists and nothing else.
@available(iOS 27.0, *)
@AppEntity(schema: .reminders.section)
struct SectionEntity {
    static let defaultQuery = SectionEntityQuery()

    let id: String

    var name: String
    var list: ListEntity

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

@available(iOS 27.0, *)
extension SectionEntity {
    @MainActor
    static func all(_ context: IntentContext) -> [SectionEntity] {
        let list = ListEntity(context.kitchen)
        return CategoryGlyph.allCases.map {
            SectionEntity(id: $0.rawValue, name: context.catalog.name(for: $0), list: list)
        }
    }

    @MainActor
    static func named(_ name: String) throws -> SectionEntity? {
        let key = Merge.normalized(name)
        return all(try IntentContext.current())
            .first { Merge.normalized($0.name) == key || $0.id == key }
    }
}

@available(iOS 27.0, *)
struct SectionEntityQuery: EntityQuery {
    func entities(for identifiers: [SectionEntity.ID]) async throws -> [SectionEntity] {
        let wanted = Set(identifiers)
        return try await MainActor.run {
            SectionEntity.all(try IntentContext.current()).filter { wanted.contains($0.id) }
        }
    }

    /// The aisles this trip actually walks — the whole 22 is a catalog listing, not a suggestion.
    func suggestedEntities() async throws -> [SectionEntity] {
        try await MainActor.run {
            let context = try IntentContext.current()
            let present = Set(try context.items().map { context.catalog.category(for: $0.itemID).rawValue })
            return SectionEntity.all(context).filter { present.contains($0.id) }
        }
    }
}
