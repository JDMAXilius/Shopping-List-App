import Core
import Foundation

/// The terms from `PRODUCT.md` §6, as constants. **Terms, never prices to render:** what a
/// person pays is whatever the App Store quotes them in their own currency, and only
/// `PlusOffer` carries that.
enum PlusPlan {
    enum Term: String, CaseIterable, Sendable, Hashable {
        case monthly, annual
    }

    static let freeScanLimit = 3
    static let headline = "The list is free forever. Plus makes the prices real."

    /// The US list prices the product was priced at — reference figures for tests and the store
    /// listing. No screen renders them: a reader in another currency is charged another number.
    static let listMonthlyUSDMinor = 299
    static let listAnnualUSDMinor = 2999
    static let listAnnualIntroUSDMinor = 1999

    /// Annual only. A monthly subscription has no trial, so nothing about monthly says "free".
    static let trialDays = 7

    static func trialDays(for term: Term) -> Int? { term == .annual ? trialDays : nil }
}

/// Everything the app can do, split once by the only line that exists: PRODUCT §6's free tier
/// against its three Plus features. The switch is exhaustive so a new capability cannot be
/// added without someone deciding which side of the line it is on.
enum Capability: CaseIterable, Sendable, Hashable {
    case theList, sharing, offline, aisleOrder, estimates, oneShop, siri, widget
    case receiptScanning, priceHistory, moreThanOneShop

    var isPlus: Bool {
        switch self {
        case .receiptScanning, .priceHistory, .moreThanOneShop:
            return true
        case .theList, .sharing, .offline, .aisleOrder, .estimates, .oneShop, .siri, .widget:
            return false
        }
    }

    var title: String {
        switch self {
        case .theList: return "The list"
        case .sharing: return "Sharing your kitchen"
        case .offline: return "Working offline"
        case .aisleOrder: return "Aisle order"
        case .estimates: return "Estimated prices"
        case .oneShop: return "One shop"
        case .siri: return "Siri"
        case .widget: return "The widget"
        case .receiptScanning: return "Scanning receipts"
        case .priceHistory: return "Price history"
        case .moreThanOneShop: return "More than one shop"
        }
    }
}

/// What happens when someone reaches for something. `.unavailable` carries the sentence a
/// joiner is shown instead of a paywall — a statement, never an offer and never a nag.
enum Gate: Equatable, Sendable {
    case allowed
    case paywall
    case unavailable(String)
}

/// What the server said about this user's entitlement when asked directly. Three answers, not
/// two: an absent row is a real one — a user who has never scanned has none, and the server would
/// grant them the three free scans — while `.unavailable` is a network fact and claims nothing.
enum EntitlementRead: Equatable, Sendable {
    case found(isPlus: Bool, scansUsed: Int)
    case absent
    case unavailable
}

/// What the App Store says today, in the reader's own currency. Built from live products only;
/// there is no path that composes a price out of `PlusPlan`'s US figures.
struct PlusOffer: Equatable, Sendable {
    struct Plan: Equatable, Sendable {
        let term: PlusPlan.Term
        let displayPrice: String
        /// The launch-window annual price while one is running.
        let introDisplayPrice: String?
        let trialDays: Int?

        init(term: PlusPlan.Term, displayPrice: String, introDisplayPrice: String? = nil,
             trialDays: Int? = nil) {
            self.term = term
            self.displayPrice = displayPrice
            self.introDisplayPrice = term == .annual ? introDisplayPrice : nil
            // Structural, not conventional: a monthly card cannot be handed a trial to show.
            self.trialDays = term == .annual ? trialDays : nil
        }
    }

    let monthly: Plan
    let annual: Plan

    func plan(_ term: PlusPlan.Term) -> Plan {
        term == .monthly ? monthly : annual
    }
}

enum PurchaseResult: Equatable, Sendable {
    case purchased
    /// The person changed their mind. Nothing happens — no second ask, no "are you sure".
    case cancelled
    case unavailable
    case failed(String)
}

/// Entitlement, scan quota and paywall presentation (ARCHITECTURE §3) — coordination only.
/// The server is the truth for both entitlement and quota; this caches the last answer so a
/// phone with no signal still knows what it has, and never locks anyone out of their own list.
@Observable @MainActor
final class SubscriptionStore {
    typealias PurchaseAction = @MainActor (PlusPlan.Term) async -> PurchaseResult
    typealias RestoreAction = @MainActor () async -> PurchaseResult
    /// The one way entitlement arrives without a scan. A closure, so this store still knows
    /// nothing about Supabase or about HTTP — the read itself lives behind `KitchenBackend`.
    typealias EntitlementReader = @MainActor () async -> EntitlementRead

    private static let plusKey = "plus.isPlus"
    private static let scansKey = "plus.scansUsed"
    private static let roleKey = "plus.role"
    /// Not private so a test can stand at the far side of the window below.
    static let purchasedAtKey = "plus.purchasedAt"

    /// How long this device's own purchase outranks a server answer that says it is not Plus.
    /// RevenueCat's webhook fires in seconds and retries over minutes, so 15 minutes covers every
    /// plausible delay before `apply_entitlement_event` has written the row; it is shorter than
    /// any billing period by three orders of magnitude, so it can never keep a genuinely lapsed
    /// subscription alive for long enough that anyone could notice, let alone rely on it.
    static let purchaseGrace: TimeInterval = 15 * 60

    private let defaults: UserDefaults
    /// RevenueCat plugs in here and nowhere else (ARCHITECTURE §9). No key is committed, so in
    /// every build today both are nil and the paywall says there is nothing on sale.
    private let purchaseAction: PurchaseAction?
    private let restoreAction: RestoreAction?
    private let readEntitlement: EntitlementReader?
    /// One read at a time: launch and the first foreground can both fire, and the second of them
    /// would put an identical request on the wire for nothing.
    private var isReading = false
    /// A foreground that arrived while a read was already out. It is not dropped: it is the next
    /// read, taken as soon as the current one lands.
    private var wantsAnotherRead = false
    /// Counts every write to entitlement state. A read that left before one of them is older
    /// than it, whatever the clock says — see `refreshEntitlement()`.
    private var writes = 0

    private(set) var isPlus: Bool
    private(set) var scansUsed: Int
    private(set) var offer: PlusOffer?

    /// How this phone belongs to its kitchen. `KitchenStore` answers this asynchronously, so the
    /// last answer is remembered across launches: a joiner must not meet a paywall in the window
    /// before their session comes back.
    private(set) var role: Member.Role

    init(defaults: UserDefaults, role: Member.Role? = nil, purchase: PurchaseAction? = nil,
         restore: RestoreAction? = nil, entitlement: EntitlementReader? = nil) {
        self.defaults = defaults
        self.role = role ?? SubscriptionStore.storedRole(defaults)
        purchaseAction = purchase
        restoreAction = restore
        readEntitlement = entitlement
        isPlus = defaults.bool(forKey: SubscriptionStore.plusKey)
        scansUsed = defaults.integer(forKey: SubscriptionStore.scansKey)
    }

    /// Called when the kitchen learns who this phone is (`KitchenStore.isGuest`).
    func adopt(_ role: Member.Role) {
        self.role = role
        defaults.set(role.rawValue, forKey: SubscriptionStore.roleKey)
    }

    private static func storedRole(_ defaults: UserDefaults) -> Member.Role {
        Member.Role(rawValue: defaults.string(forKey: roleKey) ?? "") ?? .owner
    }

    var freeScansLeft: Int { max(0, PlusPlan.freeScanLimit - scansUsed) }

    /// The paywall belongs to the person who set the kitchen up. A joiner arrived through an
    /// invite and is never sold to — sharing is the growth loop (PRODUCT §1).
    var mayBeOffered: Bool { role == .owner && !isPlus }

    func gate(_ capability: Capability) -> Gate {
        guard capability.isPlus, !isPlus else { return .allowed }
        // The loop has to run once before the paywall means anything (PRODUCT §5).
        if capability == .receiptScanning, freeScansLeft > 0 { return .allowed }
        switch role {
        case .owner: return .paywall
        case .guest: return .unavailable(SubscriptionStore.joinerSentence(capability))
        }
    }

    static func joinerSentence(_ capability: Capability) -> String {
        "\(capability.title) is part of Plus. You joined this kitchen, so the list, its prices "
            + "and sharing stay yours — free, forever."
    }

    /// Entitlement and quota as the scan function answered them; every other outcome is a
    /// network fact, not an entitlement fact, and claims nothing.
    func record(_ outcome: ScanOutcome) {
        switch outcome {
        case .scanned(let receipt):
            apply(isPlus: receipt.isPlus, scansUsed: receipt.scansUsed)
        case .quotaExhausted(let used):
            // The function only refuses a free account, so a 402 settles both fields.
            apply(isPlus: false, scansUsed: used ?? max(scansUsed, PlusPlan.freeScanLimit))
        case .unreadableImage(let freeScan), .upstreamFailure(let freeScan):
            // `free_scan_charged: true` is the server saying one was really spent. Absent or
            // refunded claims nothing — the count here is never the more generous of the two.
            if freeScan == .charged { apply(isPlus: isPlus, scansUsed: scansUsed + 1) }
        case .unauthenticated, .signInRequired, .kitchenRequired, .rejected, .imageTooLarge,
             .rateLimited, .notReachable, .unexpected:
            break
        }
    }

    /// Entitlement asked for directly, on launch and on every foreground: someone buys Plus on
    /// their phone and opens Bagged on their iPad, and until this existed the iPad sold them what
    /// they had already paid for (TERMINAL_TICKET_FOUNDER_BLOCKERS §9).
    ///
    /// Where this ends up: **once RevenueCat is in the binary, `isPlus` belongs to its customer
    /// info** — StoreKit-backed, answers offline, and it is what the App Store actually knows —
    /// **and this read is reduced to `scans_used`, the only half the server owns.** That dissolves
    /// the purchase/webhook race instead of timing it, and the grace window below can then go.
    ///
    /// To check this on TestFlight, three steps: buy Plus on device one; foreground Bagged on
    /// device two, signed in to the same account; the Setup sales card is gone. (Both devices
    /// signed in with email or Apple — entitlement is per `user_id`, so an anonymous session on
    /// device two proves nothing.)
    func refreshEntitlement() async {
        guard let readEntitlement else { return }
        // A second caller does not put an identical request on the wire — but it does not vanish
        // either. It asks the reader in flight to go again when it lands, because the foreground
        // it arrived on is exactly the moment a purchase made on another device must be honoured.
        // Dropping it outright meant one slow read swallowed the next foreground entirely, which
        // is the bug this whole packet exists to fix, reintroduced by its own guard.
        guard !isReading else {
            wantsAnotherRead = true
            return
        }
        isReading = true
        defer { isReading = false }
        // A loop rather than a spawned Task: the queued read is part of this call, so it has no
        // lifetime of its own to reason about and a test can watch it happen without a clock.
        repeat {
            wantsAnotherRead = false
            await readOnce(readEntitlement)
        } while wantsAnotherRead
    }

    private func readOnce(_ readEntitlement: EntitlementReader) async {
        let before = writes
        let read = await readEntitlement()
        // A scan answered — or a purchase completed — while this read was in flight. That answer
        // is newer than this request, which left before it, so the read is dropped rather than
        // allowed to reverse it. This is what stops a spent free scan reappearing.
        guard before == writes else { return }
        switch read {
        case .found(let isPlus, let scansUsed):
            // The server wins in both directions, downward included: a lapsed subscription has to
            // stop being Plus. That is only safe because `.unavailable` writes nothing — losing
            // Plus takes the server actually saying so, never a phone with no signal.
            apply(isPlus: keptPlus(serverSays: isPlus), scansUsed: scansUsed)
        case .absent:
            // No row is what a user who has never scanned looks like, and the server would grant
            // them three scans — so the QUOTA is written. Plus is not: an absent row is the server
            // saying it has never heard of this user, which is not the same statement as "this
            // user is not Plus". Both `consume_scan` and `apply_entitlement_event` CREATE the row,
            // so a genuine lapse always arrives as `.found(false)`; absence only ever means
            // nothing has been attributed to this user id yet.
            //
            // Revoking on it was a P1 with a real chain behind it (W10-P2-REFUTE): a purchase made
            // before signing in is attributed to a RevenueCat alias, the webhook skips any
            // `app_user_id` that is not a uuid, no row is ever written — and then this line took
            // Plus away from someone who had paid for it, and offered to sell it to her again.
            // Absence of evidence is not evidence, least of all about someone's money.
            apply(isPlus: isPlus, scansUsed: 0)
        case .unavailable:
            break
        }
    }

    /// The server turning Plus off is honoured — unless this device bought Plus minutes ago and
    /// the webhook that writes the row has not landed yet. The quota is never held back this way:
    /// `scans_used` is not the contested fact and the server owns it.
    private func keptPlus(serverSays isPlus: Bool) -> Bool {
        if isPlus { return true }
        return self.isPlus && withinPurchaseGrace
    }

    private var withinPurchaseGrace: Bool {
        let purchasedAt = defaults.double(forKey: SubscriptionStore.purchasedAtKey)
        guard purchasedAt > 0 else { return false }
        let age = Date().timeIntervalSinceReferenceDate - purchasedAt
        return age < SubscriptionStore.purchaseGrace
    }

    /// Signing out is the person saying they are not this account any more, and entitlement is per
    /// `user_id` — a statement, not a failed read, so nothing about ruling 3 applies. Signing back
    /// in restores it on the next read, and once the SDK lands the receipt restores it with no
    /// network at all; one person's Plus sitting on a device for the next person to inherit is the
    /// worse outcome, and it is about someone's money.
    func forgetEntitlement() {
        // Counted like any other write, so a read already on the wire — carrying the row of the
        // account that just left — cannot put it back.
        writes += 1
        isPlus = false
        scansUsed = 0
        for key in [SubscriptionStore.plusKey, SubscriptionStore.scansKey,
                    SubscriptionStore.purchasedAtKey] {
            defaults.removeObject(forKey: key)
        }
    }

    func apply(offer: PlusOffer?) {
        self.offer = offer
    }

    func purchase(_ term: PlusPlan.Term) async -> PurchaseResult {
        guard let purchaseAction else { return .unavailable }
        let result = await purchaseAction(term)
        if result == .purchased { adoptPurchase() }
        return result
    }

    func restore() async -> PurchaseResult {
        guard let restoreAction else { return .unavailable }
        let result = await restoreAction()
        if result == .purchased { adoptPurchase() }
        return result
    }

    /// The moment is kept, not just the fact: the server row is written by a webhook that arrives
    /// after this, and `keptPlus(serverSays:)` needs to know how long ago this was.
    private func adoptPurchase() {
        defaults.set(Date().timeIntervalSinceReferenceDate,
                     forKey: SubscriptionStore.purchasedAtKey)
        apply(isPlus: true, scansUsed: scansUsed)
    }

    private func apply(isPlus: Bool, scansUsed: Int) {
        writes += 1
        self.isPlus = isPlus
        self.scansUsed = max(0, scansUsed)
        defaults.set(isPlus, forKey: SubscriptionStore.plusKey)
        defaults.set(self.scansUsed, forKey: SubscriptionStore.scansKey)
    }
}
