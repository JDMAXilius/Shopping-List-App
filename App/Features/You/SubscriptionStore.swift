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

    private static let plusKey = "plus.isPlus"
    private static let scansKey = "plus.scansUsed"
    private static let roleKey = "plus.role"

    private let defaults: UserDefaults
    /// RevenueCat plugs in here and nowhere else (ARCHITECTURE §9). No key is committed, so in
    /// every build today both are nil and the paywall says there is nothing on sale.
    private let purchaseAction: PurchaseAction?
    private let restoreAction: RestoreAction?

    private(set) var isPlus: Bool
    private(set) var scansUsed: Int
    private(set) var offer: PlusOffer?

    /// How this phone belongs to its kitchen. `KitchenStore` answers this asynchronously, so the
    /// last answer is remembered across launches: a joiner must not meet a paywall in the window
    /// before their session comes back.
    private(set) var role: Member.Role

    init(defaults: UserDefaults, role: Member.Role? = nil, purchase: PurchaseAction? = nil,
         restore: RestoreAction? = nil) {
        self.defaults = defaults
        self.role = role ?? SubscriptionStore.storedRole(defaults)
        purchaseAction = purchase
        restoreAction = restore
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

    func apply(offer: PlusOffer?) {
        self.offer = offer
    }

    func purchase(_ term: PlusPlan.Term) async -> PurchaseResult {
        guard let purchaseAction else { return .unavailable }
        let result = await purchaseAction(term)
        if result == .purchased { apply(isPlus: true, scansUsed: scansUsed) }
        return result
    }

    func restore() async -> PurchaseResult {
        guard let restoreAction else { return .unavailable }
        let result = await restoreAction()
        if result == .purchased { apply(isPlus: true, scansUsed: scansUsed) }
        return result
    }

    private func apply(isPlus: Bool, scansUsed: Int) {
        self.isPlus = isPlus
        self.scansUsed = max(0, scansUsed)
        defaults.set(isPlus, forKey: SubscriptionStore.plusKey)
        defaults.set(self.scansUsed, forKey: SubscriptionStore.scansKey)
    }
}
