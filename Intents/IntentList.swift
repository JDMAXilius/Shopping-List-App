import Core
import DesignKit
import Foundation

/// What the spoken answers are built from, derived exactly as the screen derives it: the app's
/// `PriceLookup`, the shop's saved aisle order, the app's `ListDerivation`. A second ordering or
/// pricing rule here would be a second list.
extension IntentContext {
    func shops() throws -> [Shop] {
        try repository.shops()
    }

    func rows() throws -> [ListRow] {
        let prices = try prices()
        return try items().map {
            ListRow(item: $0, price: prices.display($0.itemID),
                    category: catalog.category(for: $0.itemID))
        }
    }

    /// The walk: the unchecked rows in the aisle order this shop was walked in last. Nothing is
    /// promoted — on the screen an unpriced row rises to be tapped, but a spoken list reordered
    /// around what has no price yet would read out a shop nobody is walking.
    func walk() throws -> [AisleSection] {
        let order = activeShopID.flatMap { try? repository.aisleOrder(for: $0) }?.ordered ?? []
        return ListDerivation.aisles(try rows(), order: order, catalog: catalog, promoted: [])
            .filter { !$0.rows.isEmpty }
    }
}
