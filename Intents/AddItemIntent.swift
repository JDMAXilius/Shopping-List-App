import AppIntents
import Catalog
import Core
import Foundation

/// "Add milk", "add two pounds of chicken", "add oat milk at Trader Joe's". The add rule is the
/// app's — `QuantityParser`, then `ListDerivation.addPlan` — so a spoken add and a typed one
/// can never mean different things, including the merge onto a name already on the list.
struct AddItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to the list"
    static let description = IntentDescription(
        "Puts something on the list. Say how much, and a shop, if you want them.")

    @Parameter(title: "Item", requestValueDialog: "What should go on the list?")
    var text: String

    /// Optional, and unspecified means the shop the app is pointed at — exactly what a typed add
    /// does. Naming one is the thing only voice can do: hands full, at a different shop.
    @Parameter(title: "Shop")
    var shop: ShopEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$text) to the list") {
            \.$shop
        }
    }

    init() {}

    func perform() async throws -> some ReturnsValue<ListItemEntity> & ProvidesDialog {
        let text = self.text
        let shop = self.shop
        let outcome = try await MainActor.run { try AddItemIntent.add(text, shop: shop) }
        return .result(value: outcome.entity, dialog: IntentDialog("\(outcome.said)"))
    }

    @MainActor
    static func add(_ text: String,
                    shop: ShopEntity?) throws -> (entity: ListItemEntity, said: String) {
        let context = try IntentContext.current()
        // Naming a shop moves the list to it. Filing the row there while the app went on quoting
        // another shop's prices would be true about the database and misleading about the app.
        let moved = shop.map { $0.shopID != context.activeShopID } ?? false
        if let shop, moved { context.switchActiveShop(shop.shopID) }
        let parsed = QuantityParser.parse(text)
        let name = parsed.rest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw IntentRefusal.nothingToAdd }
        let items = try context.items()
        let key = Merge.normalized(name)
        let existing = items.first { Merge.normalized($0.name) == key }
        let plan = ListDerivation.addPlan(name: name, quantity: parsed.quantity, unit: parsed.unit,
                                          items: items, match: context.catalog.resolve(name),
                                          shopID: shop?.shopID ?? context.activeShopID)
        var ops = plan.ops
        // A merge edits the row already there and `addPlan` writes no shop on that path, so a
        // named shop is stamped here — otherwise the sentence below claims one that never landed.
        if let shop, let existing { ops.append(.edit(existing.listItemID, [.shopID(shop.shopID)])) }
        try context.append(ops)
        guard let row = try context.rows().first(where: { Merge.normalized($0.item.name) == key })
        else { throw IntentRefusal.couldNotWrite }
        // A named shop is always stamped (addPlan for a new row, the edit above for a merge),
        // so it is always safe to say — and the tests pin the rule as named → said,
        // unnamed → quiet, not "said only when the list moved".
        return (ListItemEntity(row),
                IntentVoice.added(row.item, merged: existing != nil, shop: shop?.name))
    }
}
