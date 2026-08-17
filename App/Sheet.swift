import Core

// Every sheet in the app, presented through one `.sheet(item:)` — never a pile of booleans.
enum Sheet: Identifiable, Hashable {
    case itemDetail(ListItemID)
    case shopSwitcher
    case firstShop
    case capture
    case invite
    case paywall
    /// An invite opened from a link or pasted by hand. The token travels in the case because a
    /// sheet that has to go looking for it can be presented without one.
    case join(String)

    var id: Self { self }
}
