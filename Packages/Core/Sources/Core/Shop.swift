import Foundation

public struct Shop: Hashable, Sendable, Codable {
    public let id: ShopID
    public var name: String
    public var branch: String?
    // Meters. Geofences are evaluated on-device only.
    public var wakeRadius: Double
    public var wakeEnabled: Bool

    public init(id: ShopID = ShopID(), name: String, branch: String? = nil,
                wakeRadius: Double = 150, wakeEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.branch = branch
        self.wakeRadius = wakeRadius
        self.wakeEnabled = wakeEnabled
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
