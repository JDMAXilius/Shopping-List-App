import Core

// Every push destination in the app. Item detail is a sheet (design 02), so it lives in `Sheet`.
enum Route: Hashable {
    case aisleOrder(ShopID)
    case priceHistory(ItemID)
    case monthSpend
    case shopEditor(ShopID?)
    case kitchen
    case places
    case setup
    case dataPrivacy
    case about
    case whyItWorksThisWay
}
