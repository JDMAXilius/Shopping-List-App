#if DEBUG
import Foundation

/// Walkthrough scaffolding, DEBUG-only: the simulator has no camera and no backend, so the
/// review screens could never render. Launching with `--uitest-scripted-scan` swaps this in;
/// the receipt is the test fixtures' shape — a sure line, an unsure line, a coupon and a fee —
/// so review, the line resolver and the coupon rule all get exercised on screen.
struct ScriptedScanBackend: ScanBackend {
    static let isRequested = CommandLine.arguments.contains("--uitest-scripted-scan")
        || isOfflineFirst
    /// First scan answers "not reachable" (the photo queues, the offline promise renders),
    /// every later one succeeds — so the retry path is walkable on screen.
    static let isOfflineFirst = CommandLine.arguments.contains("--uitest-scripted-scan-offline")

    @MainActor private static var callCount = 0

    private static let receiptJSON = """
        {"lines":[
          {"raw_text":"MILK 1L","amount_minor":189,"quantity":1,"confidence":"sure","match_hint":"milk"},
          {"raw_text":"TJ ORG BABY SPNC","amount_minor":299,"quantity":1,"confidence":"not_sure"},
          {"raw_text":"MFR COUPON MILK 2%","amount_minor":-100,"quantity":1,"confidence":"sure","match_hint":"milk"},
          {"raw_text":"BAG FEE","amount_minor":10,"quantity":1,"confidence":"no_match"}],
         "shop_name":"Trader Joe's","total_minor":398,"currency":"USD","is_plus":false,"scans_used":1}
        """

    func scan(image: Foundation.Data, mediaType: ScanMediaType,
              shopHint: String?) async -> ScanOutcome {
        let calls = await MainActor.run {
            Self.callCount += 1
            return Self.callCount
        }
        if Self.isOfflineFirst && calls == 1 { return .notReachable }
        guard let receipt = try? JSONDecoder()
            .decode(ScanReceipt.self, from: Foundation.Data(Self.receiptJSON.utf8)) else {
            return .unexpected(status: 0)
        }
        return .scanned(receipt)
    }
}
#endif
