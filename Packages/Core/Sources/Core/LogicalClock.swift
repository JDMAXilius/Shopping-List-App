public struct LogicalClock: Hashable, Sendable, Codable {
    public private(set) var value: UInt64

    public init(value: UInt64 = 0) {
        self.value = value
    }

    @discardableResult
    public mutating func tick() -> UInt64 {
        value += 1
        return value
    }

    // On receiving a remote op: jump past it, so local causality stays ahead.
    public mutating func merge(remote: UInt64) {
        value = max(value, remote) + 1
    }
}
