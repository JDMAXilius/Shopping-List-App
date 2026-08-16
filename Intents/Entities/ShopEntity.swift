import AppIntents
import Core
import Foundation

/// The thing the assistant schema had no word for. A shop is only ever chosen from the shops the
/// kitchen already has: a mis-heard name that made one would be a shop nobody can see they own,
/// and every price filed against it would be filed at a place that does not exist.
struct ShopEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shop")
    static let defaultQuery = ShopEntityQuery()

    let id: UUID
    let name: String

    var shopID: ShopID { ShopID(id) }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ shop: Shop) {
        id = shop.id.rawValue
        name = shop.name
    }
}

struct ShopEntityQuery: EntityStringQuery {
    func entities(for identifiers: [ShopEntity.ID]) async throws -> [ShopEntity] {
        let wanted = Set(identifiers)
        return try await MainActor.run {
            try IntentContext.current().shops().filter { wanted.contains($0.id.rawValue) }
                .map(ShopEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [ShopEntity] {
        try await MainActor.run {
            let shops = try IntentContext.current().shops()
            return ShopEntityQuery.matching(string, in: shops).map(ShopEntity.init)
        }
    }

    func suggestedEntities() async throws -> [ShopEntity] {
        try await MainActor.run { try IntentContext.current().shops().map(ShopEntity.init) }
    }

    static func matching(_ text: String, in shops: [Shop]) -> [Shop] {
        let key = Merge.normalized(text)
        guard !key.isEmpty else { return [] }
        let exact = shops.filter { Merge.normalized($0.name) == key }
        return exact.isEmpty ? shops.filter { Merge.normalized($0.name).contains(key) } : exact
    }
}
