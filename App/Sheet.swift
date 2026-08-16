import Core

// Every sheet in the app, presented through one `.sheet(item:)` — never a pile of booleans.
enum Sheet: Identifiable, Hashable {
    case addItem
    case itemDetail(ListItemID)
    case shopSwitcher
    case firstShop
    case capture
    case invite
    case paywall

    var id: Self { self }
}
