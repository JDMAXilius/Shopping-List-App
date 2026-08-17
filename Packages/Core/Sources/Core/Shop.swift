import Foundation

public struct Shop: Hashable, Sendable, Codable {
    public let id: ShopID
    public var name: String
    public var branch: String?
    // A shop syncs; WHERE it is does not. The pin and its radius live in a local file that the
    // sync engine cannot reach (App/Features/Places) — a geofence field here would ride an op
    // into every phone in the kitchen, arming a wake-up on a device with no pin for it and
    // telling a household member which shops you watch.

    public init(id: ShopID = ShopID(), name: String, branch: String? = nil) {
        self.id = id
        self.name = name
        self.branch = branch
    }
}

public struct AisleOrder: Hashable, Sendable, Codable {
    public let shopID: ShopID
    public var ordered: [CategoryID]

    public init(shopID: ShopID, ordered: [CategoryID]) {
        self.shopID = shopID
        self.ordered = ordered
    }
}
