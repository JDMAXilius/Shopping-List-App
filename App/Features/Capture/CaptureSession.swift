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
    /// Photos this phone promised to read and hasn't; they outlive the app being killed. The one
    /// this flow is holding is not among them: reading it again would spend a second scan and
    /// replace every decision the user has made on it.
    private(set) var waiting: [PendingScan] = []
    private(set) var scan: PendingScan?
    /// A read in flight is not re-entrant, for the same reason.
    private var isReading = false
    private(set) var result: CaptureResult?
    private(set) var printedShopName: String?
    /// Chosen at review: at the till the shutter fires before anyone knows the shop.
    var shopID: ShopID?

    /// The KITCHEN's currency, never the last receipt's: a kitchen shops in one, and every
    /// price typed or scanned here is in it. The list holds it, so there is one reading of it.
    var currencyCode: String { store.currencyCode }
    /// What this receipt printed, when that is not what the kitchen shops in — the one case
    /// where two currencies could reach one total, so it stops the commit instead.
    private(set) var currencyMismatch: String?
    private var printedCurrency: String?
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
    /// assuming this session filled it. One left `parsing` by an app kill goes back in it — and
    /// so does one an earlier build marked `failed`, because nothing else in the app ever looks
    /// at that state and a photo no queue holds is a photo the user can neither read nor delete.
    private func resume() {
        for stranded in (try? repository.pendingScans()) ?? [] where stranded.state != .queued {
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
        guard !isReading else { return }
        guard let jpeg = (try? repository.scanPhoto(pending.id)) ?? nil else {
            // The row promises a photo that is gone; keeping it would promise it forever.
            discardPhoto(pending)
            stage = .failed(.storage)
            return
        }
        await read(pending, jpeg: jpeg)
    }

    private func read(_ pending: PendingScan, jpeg: Foundation.Data) async {
        guard !isReading else { return }
        isReading = true
        defer { isReading = false }
        scan = pending
        stage = .parsing
        refreshWaiting()
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
            discardPhoto(pending)
            stage = .failed(.unreadable)
        case .imageTooLarge:
            discardPhoto(pending)
            stage = .failed(.tooLarge)
        // Our bug or a gateway's: the user did nothing wrong, so the photo is kept and retryable.
        case .rejected, .unexpected:
            queue(pending)
            stage = .failed(.ourBug)
        }
    }

    // Queued means this photo is still worth reading.
    private func queue(_ pending: PendingScan) {
        try? repository.markScan(pending.id, .queued)
        refreshWaiting()
    }

    /// The two cases only a new photo can fix. The row goes with the file: nothing would ever
    /// read either again, and `.failed` is a state nothing in the app sweeps.
    private func discardPhoto(_ pending: PendingScan) {
        try? repository.deleteScan(pending.id)
        if scan?.id == pending.id { scan = nil }
        refreshWaiting()
    }

    private func refreshWaiting() {
        let held = scan?.id
        waiting = ((try? repository.queuedScans()) ?? []).filter { $0.id != held }
    }

    // MARK: - The parsed receipt

    private func build(_ receipt: ScanReceipt) {
        printedCurrency = receipt.currency
        currencyMismatch = receipt.currency == currencyCode ? nil : receipt.currency
        printedTotalMinor = receipt.totalMinor
        purchasedAt = receipt.purchasedAt
        printedShopName = receipt.shopName
        let aliases = (try? repository.aliases()) ?? [:]
        let names = (try? repository.itemNames()) ?? [:]
        lines = receipt.lines.map { captureLine($0, aliases: aliases, names: names) }
        if let printed = receipt.shopName.map(Merge.normalized),
           let known = store.shops.first(where: { Merge.normalized($0.name) == printed }) {
            shopID = known.id
        }
    }

    private func captureLine(_ scanned: ScanLine, aliases: [String: ItemID?],
                             names: [ItemID: String]) -> CaptureLine {
        // Shown in what the till printed, always — a foreign receipt is flagged, never relabelled.
        var line = CaptureLine(rawText: scanned.rawText,
                               amount: Money(minorUnits: scanned.amountMinor,
                                             currencyCode: printedCurrency ?? currencyCode),
                               quantity: scanned.quantity, confidence: scanned.confidence,
                               hint: scanned.matchHint)
        // A key present with a nil value is "ignore this forever" — not the same as a key that
        // was never written, so the table is read by index and never with `?? nil`.
        if let index = aliases.index(forKey: Merge.aliasKey(scanned.rawText)) {
            line.isRemembered = true
            if let itemID = aliases[index].value {
                line.match = match(itemID, names: names, fallback: scanned.rawText)
                // Money off is never accepted for the user: it has no price to accept.
                line.decision = line.isMoneyOff ? .unresolved : .accept
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
        line.decision = line.isMoneyOff ? .unresolved : .accept
        return line
    }

    // A remembered alias carries an id, not a name; ListCatalog owns the order they are tried in.
    private func match(_ itemID: ItemID, names: [ItemID: String], fallback: String) -> CaptureMatch {
        CaptureMatch(remembered: itemID, kitchenNames: names,
                     listName: store.rows.first { $0.item.itemID == itemID }?.item.name,
                     fallback: fallback, catalog: catalog)
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
        let chosen = match(itemID: itemID, name: name)
        update(id) { line in
            line.match = chosen
            line.decision = .accept
            line.alias = .remember(itemID)
        }
    }

    /// A line the catalog has never heard of. The id is minted here; its alias AND its name are
    /// written at commit, or the next receipt asks again and the price book cannot name it.
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

    /// What the till printed as its own total, and nil when the model read none. It is never
    /// computed: SUBTOTAL, TAX, TOTAL, CASH and CHANGE are all lines, and adding the lines up
    /// makes a number nobody was charged.
    var printedTotal: Money? {
        printedTotalMinor.map { Money(minorUnits: $0, currencyCode: lineCurrency) }
    }

    /// Ours, and never labelled as the till's: the lines being kept, added up as they printed.
    var recordedTotal: Money {
        Money(minorUnits: lines.filter(\.isPriced).reduce(0) { $0 + $1.amount.minorUnits },
              currencyCode: lineCurrency)
    }

    private var lineCurrency: String { printedCurrency ?? currencyCode }

    // A receipt in another currency cannot be committed at all: its lines would sum with the
    // kitchen's own prices under one label, and that total would be a lie about money.
    var canCommit: Bool { stage == .review && shopID != nil && currencyMismatch == nil }
    var shopName: String? { store.shops.first { $0.id == shopID }?.name }

    func suggestions(for text: String) -> [ListCatalog.Match] { catalog.matches(text) }

    /// The seeded estimate travels with the id, so the >3× gate has something to compare
    /// against wherever a match is made — a receipt line, a barcode, a typed one. An id minted
    /// by the caller is named nowhere else, so the match carries the name it has to teach.
    func match(itemID: ItemID, name: String) -> CaptureMatch {
        CaptureMatch(itemID: itemID, name: name, estimate: catalog.estimate(for: itemID),
                     teaches: itemID.catalogID == nil ? name : nil)
    }

    /// What this kitchen has already said this text means — a barcode it taught once, a till
    /// line it matched. nil is "nobody has said yet", which is not "unknown product".
    func remembered(_ rawText: String) -> CaptureMatch? {
        let aliases = (try? repository.aliases()) ?? [:]
        guard let index = aliases.index(forKey: Merge.aliasKey(rawText)),
              let itemID = aliases[index].value else { return nil }
        return match(itemID, names: (try? repository.itemNames()) ?? [:], fallback: rawText)
    }

    /// One transaction: one price op per accepted line, the alias each user decision earned, and
    /// the receipt that takes the photo over. All of it or none of it — a half-written commit
    /// cannot be retried, because the scan the retry needs is already gone.
    @discardableResult
    func commit() -> Bool {
        guard canCommit, let pending = scan, let shopID else { return false }
        let date = CaptureSession.honestDate(purchasedAt ?? pending.capturedAt)
        var ops: [Op.Kind] = []
        for line in lines {
            if let alias = line.alias {
                ops.append(.alias(rawText: line.rawText, itemID: alias.itemID))
            }
            guard line.isPriced, let match = line.match else { continue }
            // The name goes in with the price: an item minted at the resolver has no other
            // home for it, and a price book row it cannot name is the bug this closes.
            if let teaches = match.teaches {
                ops.append(.name(match.itemID, teaches))
            }
            ops.append(.price(PriceObservation(itemID: match.itemID, shopID: shopID, date: date,
                                               amount: line.unitAmount, source: .receipt)))
        }
        // The till's total or nothing, and beside it what this receipt actually recorded. A
        // receipt with no printed total is stored with none — never with a sum wearing its name.
        guard (try? repository.commitScan(pending.id, shopID: shopID, lineCount: lines.count,
                                          totalMinor: printedTotalMinor,
                                          recordedMinor: recordedTotal.minorUnits, ops: ops,
                                          kitchenID: kitchenID)) != nil else { return false }
        result = CaptureResult(lines: lines)
        scan = nil
        refreshWaiting()
        store.refresh()
        stage = .committed
        Haptics.play(.add)
        return true
    }

    /// One line with no receipt behind it — typed, or scanned off a packet. It writes what
    /// `commit` writes for a single line and nothing else: no receipt row, and not one touch of
    /// `stage`, `scan` or `lines`, so a review left open upstairs survives this.
    @discardableResult
    func record(_ line: CaptureLine, shopID: ShopID, date: Date) -> Bool {
        guard line.isPriced, let match = line.match, line.amount.minorUnits > 0,
              line.amount.currencyCode == currencyCode else { return false }
        let observation = PriceObservation(itemID: match.itemID, shopID: shopID,
                                           date: CaptureSession.honestDate(date),
                                           amount: line.unitAmount, source: .typed)
        guard (try? repository.append(.price(observation), kitchenID: kitchenID)) != nil else {
            return false
        }
        // An item minted on this screen is named nowhere else; the kitchen learns it here.
        if let teaches = match.teaches {
            try? repository.append(.name(match.itemID, teaches), kitchenID: kitchenID)
        }
        // The item written is the item the screen showed, always. What this kitchen already
        // knows is resolved before the user is asked (`remembered`), never behind them here.
        if let alias = line.alias, !Merge.aliasKey(line.rawText).isEmpty {
            _ = try? repository.append(.alias(rawText: line.rawText, itemID: alias.itemID),
                                       kitchenID: kitchenID)
        }
        store.refresh()
        Haptics.play(.add)
        return true
    }

    /// Never forward, whichever path wrote it: a future-dated observation reads as `trusted`,
    /// prints as "today", outranks every real price for 90 days and lands in a month that has
    /// not happened. A till with a mis-set clock produces one with no OCR error at all.
    static func honestDate(_ date: Date, now: Date = Date()) -> Date { min(date, now) }

    /// Back to the viewfinder. A queued photo stays queued: it is still a promise to read it,
    /// and letting go of it is what puts it back among the waiting.
    func retakePhoto() {
        scan = nil
        lines = []
        refreshWaiting()
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
