import Foundation

// Test scope only (test-target membership, like ListStoreTests): the fake half of the one seam
// ARCHITECTURE §2 sanctions a protocol for.
actor FakeScanBackend: ScanBackend {
    struct Call: Equatable {
        let image: Data
        let mediaType: ScanMediaType
        let shopHint: String?
    }

    private var queued: [ScanOutcome]
    private(set) var calls: [Call] = []

    init(outcomes: [ScanOutcome]) {
        queued = outcomes
    }

    // Runs out of scripted outcomes rather than repeating one: a test that scans twice has to
    // say what the second scan does.
    func scan(image: Data, mediaType: ScanMediaType, shopHint: String?) async -> ScanOutcome {
        calls.append(Call(image: image, mediaType: mediaType, shopHint: shopHint))
        guard !queued.isEmpty else { return .notReachable }
        return queued.removeFirst()
    }
}
