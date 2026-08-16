import Core
import Data
import DesignKit
import Foundation

/// The per-flow store (ARCHITECTURE §3): created with `@State` when a capture starts, dead when
/// it ends. It owns the pending scan, the parsed lines with their per-line decisions, and the
/// commit — and it is the ONLY thing in the flow that writes.
@Observable @MainActor
final class CaptureSession {

    enum Stage: Hashable {
        case idle
        case parsing
        case review
        /// The photo is queued and unread — offline, or simply not asked for yet. Not an error.
        case waiting
        case failed(Failure)
        case handoff(Handoff)
        case committed
    }

    enum Failure: Hashable {
        case unreadable, tooLarge, rateLimited, upstream, ourBug, unauthenticated, storage
    }

    /// Screens wave 9 owns. The route is decided here; the destination says so rather than
    /// inventing a paywall.
    enum Handoff: Hashable {
        case paywall(scansUsed: Int?)
        case signIn
        case kitchen
    }

    let store: ListStore

    private let repository: Repository
    private let kitchenID: KitchenID
    private let catalog: ListCatalog
    private let backend: any ScanBackend

    private(set) var stage: Stage = .idle
    private(set) var lines: [CaptureLine] = []
    /// Photos this phone promised to read and hasn't; they outlive the app being killed.
    private(set) var waiting: [PendingScan] = []
    private(set) var scan: PendingScan?
    private(set) var result: CaptureResult?
    private(set) var printedShopName: String?
    /// Chosen at review: at the till the shutter fires before anyone knows the shop.
    var shopID: ShopID?

    private var currencyCode = "USD"
    private var purchasedAt: Date?
    private var printedTotalMinor: Int?

    init(repository: Repository, kitchenID: KitchenID, store: ListStore,
         catalog: ListCatalog, backend: any ScanBackend) {
        self.repository = repository
        self.kitchenID = kitchenID
        self.store = store
        self.catalog = catalog
        self.backend = backend
        shopID = store.activeShopID
        resume()
    }

    // MARK: - Entry

    /// A queued scan outlives the flow that made it, so entry reads the queue instead of
    /// assuming this session filled it; one left `parsing` by an app kill goes back in it.
    private func resume() {
        for stranded in (try? repository.pendingScans()) ?? [] where stranded.state == .parsing {
            try? repository.markScan(stranded.id, .queued)
        }
        refreshWaiting()
    }

    // MARK: - The shutter

    /// The shutter always succeeds: the photo is enqueued before anything is asked of the
    /// network, so an unreachable server costs the user nothing but a wait.
    func capture(jpeg: Foundation.Data) async {
        guard let enqueued = try? repository.enqueueScan(jpeg: jpeg) else {
            stage = .failed(.storage)
            return
        }
        refreshWaiting()
        await read(enqueued, jpeg: jpeg)
    }

    func read(_ pending: PendingScan) async {
        guard let jpeg = (try? repository.scanPhoto(pending.id)) ?? nil else {
            // The row promises a photo that is gone; keeping it would promise it forever.
            try? repository.deleteScan(pending.id)
            refreshWaiting()
            stage = .failed(.storage)
            return
        }
        await read(pending, jpeg: jpeg)
    }

    private func read(_ pending: PendingScan, jpeg: Foundation.Data) async {
        scan = pending
        stage = .parsing
        try? repository.markScan(pending.id, .parsing)
        let outcome = await backend.scan(image: jpeg, mediaType: .jpeg,
                                         shopHint: store.activeShop?.name)
        apply(outcome, to: pending)
    }

    private func apply(_ outcome: ScanOutcome, to pending: PendingScan) {
        switch outcome {
        case .scanned(let receipt):
            // Still queued: the receipt row is written by commit and by nothing else.
            queue(pending)
            build(receipt)
            stage = .review
        case .notReachable:
            queue(pending)
            stage = .waiting
        case .quotaExhausted(let scansUsed):
            queue(pending)
            stage = .handoff(.paywall(scansUsed: scansUsed))
        case .signInRequired:
            queue(pending)
            stage = .handoff(.signIn)
        case .kitchenRequired:
            queue(pending)
            stage = .handoff(.kitchen)
        case .unauthenticated:
            queue(pending)
            stage = .failed(.unauthenticated)
        case .rateLimited:
            queue(pending)
            stage = .failed(.rateLimited)
        case .upstreamFailure:
            queue(pending)
            stage = .failed(.upstream)
        case .unreadableImage:
            reject(pending)
            stage = .failed(.unreadable)
        case .imageTooLarge:
            reject(pending)
            stage = .failed(.tooLarge)
        case .rejected, .unexpected:
            reject(pending)
            stage = .failed(.ourBug)
        }
    }

    // Queued means this photo is still worth reading; failed means only a new photo will do.
    private func queue(_ pending: PendingScan) {
        try? repository.markScan(pending.id, .queued)
        refreshWaiting()
    }

    private func reject(_ pending: PendingScan) {
        try? repository.markScan(pending.id, .failed)
        refreshWaiting()
    }

    private func refreshWaiting() {
        waiting = (try? repository.queuedScans()) ?? []
    }

    // MARK: - The parsed receipt

    private func build(_ receipt: ScanReceipt) {
        currencyCode = receipt.currency
        printedTotalMinor = receipt.totalMinor
        purchasedAt = receipt.purchasedAt
        printedShopName = receipt.shopName
        let aliases = (try? repository.aliases()) ?? [:]
        lines = receipt.lines.map { captureLine($0, aliases: aliases) }
        if let printed = receipt.shopName.map(Merge.normalized),
           let known = store.shops.first(where: { Merge.normalized($0.name) == printed }) {
            shopID = known.id
        }
    }

    private func captureLine(_ scanned: ScanLine, aliases: [String: ItemID?]) -> CaptureLine {
        var line = CaptureLine(rawText: scanned.rawText,
                               amount: Money(minorUnits: scanned.amountMinor,
                                             currencyCode: currencyCode),
                               quantity: scanned.quantity, confidence: scanned.confidence,
                               hint: scanned.matchHint)
        // A key present with a nil value is "ignore this forever" — not the same as a key that
        // was never written, so the table is read by index and never with `?? nil`.
        if let index = aliases.index(forKey: Merge.aliasKey(scanned.rawText)) {
            line.isRemembered = true
            if let itemID = aliases[index].value {
                line.match = match(itemID, fallback: scanned.rawText)
                line.decision = .accept
            } else {
                line.decision = .ignore
            }
            return line
        }
        // The model's own "this is not a purchase" is taken at its word: a TOTAL line must not
        // walk into the price book because the catalog found something that rhymes.
        guard scanned.confidence != .noMatch else { return line }
        var hit = catalog.matches(scanned.matchHint ?? scanned.rawText, limit: 1).first
        if hit == nil, scanned.matchHint != nil {
            hit = catalog.matches(scanned.rawText, limit: 1).first
        }
        guard let hit else { return line }
        line.match = CaptureMatch(itemID: hit.itemID, name: hit.name,
                                  estimate: catalog.estimate(for: hit.itemID))
        line.decision = .accept
        return line
    }

    // A remembered alias carries an id, not a name, and the catalog can only name what it can
    // resolve — so an item that is not on the list is shown as the till printed it.
    private func match(_ itemID: ItemID, fallback: String) -> CaptureMatch {
        let name = store.rows.first { $0.item.itemID == itemID }?.item.name ?? fallback
        return CaptureMatch(itemID: itemID, name: name, estimate: catalog.estimate(for: itemID))
    }

    // MARK: - Per-line decisions

    /// Un-ignoring undoes no op, because no op was written: the decision is simply replaced.
    func accept(_ id: CaptureLine.ID) {
        update(id) { line in
            if case .forget? = line.alias { line.alias = nil }
            line.decision = line.match == nil ? .unresolved : .accept
        }
    }

    /// Permanent, and that is the point: the kitchen never asks about this line again.
    func ignore(_ id: CaptureLine.ID) {
        update(id) { line in
            line.decision = .ignore
            line.alias = .forget
        }
    }

    /// The correction the resolver comes back with. The alias is what makes it stick.
    func choose(itemID: ItemID, name: String, for id: CaptureLine.ID) {
        let chosen = CaptureMatch(itemID: itemID, name: name,
                                  estimate: catalog.estimate(for: itemID))
        update(id) { line in
            line.match = chosen
            line.decision = .accept
            line.alias = .remember(itemID)
        }
    }

    /// A line the catalog has never heard of. The id is minted here and its alias is written at
    /// commit, or the next receipt asks the same question again.
    func createItem(named name: String, for id: CaptureLine.ID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        choose(itemID: ItemID(), name: trimmed, for: id)
    }

    private func update(_ id: CaptureLine.ID, _ change: (inout CaptureLine) -> Void) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }
        change(&lines[index])
    }

    // MARK: - The commit, which is the only write

    var acceptedCount: Int { lines.filter(\.isPriced).count }
    var canCommit: Bool { stage == .review && shopID != nil }
    var shopName: String? { store.shops.first { $0.id == shopID }?.name }

    func suggestions(for text: String) -> [ListCatalog.Match] { catalog.matches(text) }

    /// `promoteScan` first — one transaction that writes the receipt and hands the photo over —
    /// then one price op per accepted line, and the alias each user decision earned.
    @discardableResult
    func commit() -> Bool {
        guard stage == .review, let pending = scan, let shopID else { return false }
        let date = purchasedAt ?? pending.capturedAt
        let total = printedTotalMinor ?? lines.reduce(0) { $0 + $1.amount.minorUnits }
        guard (try? repository.promoteScan(pending.id, shopID: shopID, lineCount: lines.count,
                                           totalMinor: total)) != nil else { return false }
        for line in lines {
            if let alias = line.alias {
                try? repository.append(.alias(rawText: line.rawText, itemID: alias.itemID),
                                       kitchenID: kitchenID)
            }
            guard line.isPriced, let match = line.match else { continue }
            let observation = PriceObservation(itemID: match.itemID, shopID: shopID, date: date,
                                               amount: line.unitAmount, source: .receipt)
            try? repository.append(.price(observation), kitchenID: kitchenID)
        }
        result = CaptureResult(lines: lines)
        scan = nil
        refreshWaiting()
        store.refresh()
        stage = .committed
        Haptics.play(.add)
        return true
    }

    /// Back to the viewfinder. A queued photo stays queued: it is still a promise to read it.
    func retakePhoto() {
        scan = nil
        lines = []
        stage = .idle
    }

    /// The photo goes with it — Data owns the file at both ends, so this is the one way out
    /// that leaves nothing behind.
    func discard() {
        if let pending = scan { try? repository.deleteScan(pending.id) }
        scan = nil
        lines = []
        refreshWaiting()
        stage = .idle
    }
}
