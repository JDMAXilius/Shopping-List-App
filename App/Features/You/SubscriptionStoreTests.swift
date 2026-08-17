import Core
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class SubscriptionStoreTests: XCTestCase {
    private func makeDefaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(UUID().uuidString)"))
    }

    private func makeStore(_ role: Member.Role = .owner, defaults: UserDefaults? = nil,
                           purchase: SubscriptionStore.PurchaseAction? = nil,
                           restore: SubscriptionStore.RestoreAction? = nil) throws
        -> SubscriptionStore {
        let suite = try defaults ?? makeDefaults()
        return SubscriptionStore(defaults: suite, role: role, purchase: purchase,
                                 restore: restore)
    }

    private func scanned(isPlus: Bool, scansUsed: Int) throws -> ScanOutcome {
        let json = #"{"lines":[],"currency":"USD","is_plus":\#(isPlus),"#
            + #""scans_used":\#(scansUsed)}"#
        return .scanned(try JSONDecoder().decode(ScanReceipt.self, from: Foundation.Data(json.utf8)))
    }

    private func offer() -> PlusOffer {
        PlusOffer(monthly: PlusOffer.Plan(term: .monthly, displayPrice: "$2.99"),
                  annual: PlusOffer.Plan(term: .annual, displayPrice: "$29.99",
                                         introDisplayPrice: nil, trialDays: PlusPlan.trialDays))
    }

    // MARK: - The free tier keeps exactly what PRODUCT says it keeps

    func testTheFreeTierKeepsTheListSharingOfflineAisleOrderEstimatesOneShopSiriAndTheWidget()
        throws {
        let store = try makeStore()

        let free = Capability.allCases.filter { store.gate($0) == .allowed }
        XCTAssertEqual(Set(free), [.theList, .sharing, .offline, .aisleOrder, .estimates,
                                   .oneShop, .siri, .widget, .receiptScanning],
                       "receipt scanning is here only because the first three scans are free")
        XCTAssertEqual(Set(Capability.allCases.filter(\.isPlus)),
                       [.receiptScanning, .priceHistory, .moreThanOneShop])
    }

    func testTheTermsAreTheOnesProductSets() {
        XCTAssertEqual(PlusPlan.freeScanLimit, 3)
        XCTAssertEqual(PlusPlan.listMonthlyUSDMinor, 299)
        XCTAssertEqual(PlusPlan.listAnnualUSDMinor, 2_999)
        XCTAssertEqual(PlusPlan.listAnnualIntroUSDMinor, 1_999)
        XCTAssertEqual(PlusPlan.trialDays, 7)
        XCTAssertEqual(PlusPlan.trialDays(for: .annual), 7)
        XCTAssertNil(PlusPlan.trialDays(for: .monthly), "the trial is on annual only")
        XCTAssertEqual(PlusPlan.headline,
                       "The list is free forever. Plus makes the prices real.")
    }

    func testThePaywallNamesWhatIsKeptForFree() {
        let line = PaywallCopy.freeForever
        for capability in Capability.allCases where !capability.isPlus {
            XCTAssertTrue(line.contains(capability.title), "\(capability) is missing: \(line)")
        }
        for capability in Capability.allCases where capability.isPlus {
            XCTAssertFalse(line.contains(capability.title), "\(capability) is not free: \(line)")
        }
    }

    // MARK: - The paywall is for the owner, and only after the loop has run

    func testAJoinerNeverMeetsThePaywall() throws {
        let store = try makeStore(.guest)
        store.record(.quotaExhausted(scansUsed: PlusPlan.freeScanLimit))

        XCTAssertFalse(store.mayBeOffered)
        for capability in Capability.allCases {
            XCTAssertNotEqual(store.gate(capability), .paywall,
                              "\(capability) sent a joiner to the paywall")
        }
        // What they get instead is a statement, and it says what stays theirs.
        XCTAssertEqual(store.gate(.priceHistory),
                       .unavailable(SubscriptionStore.joinerSentence(.priceHistory)))
        XCTAssertTrue(SubscriptionStore.joinerSentence(.priceHistory).contains("free, forever"))
    }

    func testOnceThisPhoneIsKnownToHaveJoinedItStaysKnown() throws {
        let defaults = try makeDefaults()
        let store = try makeStore(defaults: defaults)

        store.adopt(.guest)

        // The kitchen answers asynchronously; the next launch must not start by guessing owner.
        let relaunched = SubscriptionStore(defaults: defaults)
        XCTAssertEqual(relaunched.role, .guest)
        XCTAssertFalse(relaunched.mayBeOffered)
    }

    func testTheOwnerSeesThePaywallOnlyAfterTheThreeFreeScans() throws {
        let store = try makeStore()

        XCTAssertEqual(store.freeScansLeft, 3)
        XCTAssertEqual(store.gate(.receiptScanning), .allowed)
        store.record(try scanned(isPlus: false, scansUsed: 2))
        XCTAssertEqual(store.freeScansLeft, 1)
        XCTAssertEqual(store.gate(.receiptScanning), .allowed)
        store.record(try scanned(isPlus: false, scansUsed: 3))
        XCTAssertEqual(store.freeScansLeft, 0)
        XCTAssertEqual(store.gate(.receiptScanning), .paywall)
    }

    func testPlusOpensEverythingAndIsRememberedWithNoSignal() throws {
        let defaults = try makeDefaults()
        let store = try makeStore(defaults: defaults)
        store.record(try scanned(isPlus: true, scansUsed: 3))

        for capability in Capability.allCases {
            XCTAssertEqual(store.gate(capability), .allowed)
        }
        XCTAssertFalse(store.mayBeOffered, "nobody is sold what they already have")

        // Offline is the normal case in a shop: the cached answer is what the next launch reads.
        let relaunched = try makeStore(defaults: defaults)
        XCTAssertTrue(relaunched.isPlus)
        relaunched.record(.notReachable)
        XCTAssertTrue(relaunched.isPlus, "a network failure is not an entitlement fact")
    }

    func testTheListIsNeverGatedForAnyone() throws {
        for role in [Member.Role.owner, .guest] {
            let store = try makeStore(role)
            store.record(.quotaExhausted(scansUsed: 9))
            for capability in Capability.allCases where !capability.isPlus {
                XCTAssertEqual(store.gate(capability), .allowed, "\(role) lost \(capability)")
            }
        }
    }

    // MARK: - Sold only where it is withheld

    /// Every capability the paywall sells, and the file that withholds it. Exhaustive, so a new
    /// Plus feature cannot be sold without someone naming where it is refused.
    private func gateSite(_ capability: Capability) -> (file: String, pin: String)? {
        switch capability {
        // The server withholds this one: it 402s, and the answer reaches the store through here.
        case .receiptScanning:
            return ("Capture/CaptureSession.swift", "onOutcome(outcome)")
        case .priceHistory:
            return ("Prices/PriceHistoryScreen.swift", "subscription.gate(.priceHistory)")
        case .moreThanOneShop:
            return ("List/ShopSwitcherSheet.swift", "subscription.gate(.moreThanOneShop)")
        case .theList, .sharing, .offline, .aisleOrder, .estimates, .oneShop, .siri, .widget:
            return nil
        }
    }

    func testEveryFeatureThePaywallSellsIsOneTheAppActuallyWithholds() throws {
        let features = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent()
        for capability in Capability.allCases {
            guard capability.isPlus else {
                XCTAssertNil(gateSite(capability), "\(capability) is free and must not be gated")
                continue
            }
            let site = try XCTUnwrap(gateSite(capability),
                                     "\(capability) is on the paywall with nowhere it is refused")
            let source = try String(contentsOf: features.appendingPathComponent(site.file),
                                    encoding: .utf8)
            XCTAssertTrue(source.contains(site.pin),
                          "\(site.file) no longer withholds \(capability): \(site.pin)")
        }
    }

    func testTheFullHistoryIsWithheldFromAFreeOwnerAndNothingElseIs() throws {
        let store = try makeStore()
        let gate = store.gate(.priceHistory)

        XCTAssertEqual(PriceHistoryScreen.shown(entries: 4, shops: 2, gate: gate), .plus)
        // An item nothing has priced has no history to withhold, so no gate is advertised over it.
        XCTAssertEqual(PriceHistoryScreen.shown(entries: 0, shops: 0, gate: gate), .estimateOnly)
        // The current price above it is never withheld — the list and the price book show it free.
        XCTAssertTrue(PriceHistoryScreen.plusSentence.contains("The price above stays free"))
        XCTAssertTrue(PriceHistoryScreen.plusSentence.contains("nothing you've recorded is deleted"))
        XCTAssertEqual(PriceHistoryScreen.shown(entries: 4, shops: 2, gate: .allowed), .full)
    }

    func testTheFirstShopIsFreeAndTheOnesAKitchenHasAreNeverTakenAway() throws {
        let free = try makeStore()
        let plus = try makeStore()
        plus.record(try scanned(isPlus: true, scansUsed: 0))

        XCTAssertEqual(ShopSwitcherSheet.addShopGate(shopCount: 0, free), .allowed)
        XCTAssertEqual(ShopSwitcherSheet.addShopGate(shopCount: 1, free), .paywall)
        // Three shops already: the gate is on adding a fourth, and the three keep working —
        // `.moreThanOneShop` is the only capability consulted, and it removes nothing.
        XCTAssertEqual(ShopSwitcherSheet.addShopGate(shopCount: 3, free), .paywall)
        XCTAssertEqual(free.gate(.oneShop), .allowed)
        XCTAssertEqual(free.gate(.aisleOrder), .allowed)
        XCTAssertEqual(ShopSwitcherSheet.addShopGate(shopCount: 3, plus), .allowed)
    }

    func testAJoinerMeetingAPlusSurfaceIsToldWhatItIsAndNeverShownAPrice() throws {
        let joiner = try makeStore(.guest)
        let sentence = SubscriptionStore.joinerSentence(.priceHistory)

        XCTAssertEqual(PriceHistoryScreen.shown(entries: 4, shops: 2,
                                                gate: joiner.gate(.priceHistory)),
                       .unavailable(sentence))
        XCTAssertEqual(ShopSwitcherSheet.addShopGate(shopCount: 2, joiner),
                       .unavailable(SubscriptionStore.joinerSentence(.moreThanOneShop)))
        // A statement, never an offer: no figure, no currency, and nothing to buy.
        XCTAssertFalse(sentence.contains(where: \.isNumber), sentence)
        XCTAssertFalse(sentence.contains("$"), sentence)
        XCTAssertFalse(sentence.lowercased().contains("upgrade"), sentence)
        XCTAssertFalse(joiner.mayBeOffered, "so the paywall's purchase block never renders")
    }

    // MARK: - The quota the app shows is the one the server counted

    func testTheAppSaysWhatTheServerSaidAboutTheQuotaInBothDirections() throws {
        let store = try makeStore()

        store.record(.quotaExhausted(scansUsed: nil))
        XCTAssertEqual(store.freeScansLeft, 0, "a 402 is never shown as scans still left")
        XCTAssertEqual(SetupScreen.scansChip(store.freeScansLeft), "3 free scans used")

        // And downward: the count the function reports wins over the one cached here.
        store.record(try scanned(isPlus: false, scansUsed: 1))
        XCTAssertEqual(store.scansUsed, 1)
        XCTAssertEqual(SetupScreen.scansChip(store.freeScansLeft), "2 free scans left")
    }

    func testAFreeScanTheServerChargedIsNeverShownAsUnspent() throws {
        let store = try makeStore()

        store.record(.unreadableImage(freeScan: .charged))
        XCTAssertEqual(store.scansUsed, 1)
        store.record(.upstreamFailure(freeScan: .charged))
        XCTAssertEqual(store.scansUsed, 2)
        // Absent and refunded are not "spent", and neither is a claim we may invent.
        store.record(.upstreamFailure(freeScan: .refunded))
        store.record(.unreadableImage(freeScan: .notReached))
        store.record(.unreadableImage(freeScan: .unreported))
        XCTAssertEqual(store.scansUsed, 2)
    }

    // MARK: - No dark patterns, structurally

    func testAMonthlyPlanCannotShowATrialOrAnIntroPrice() {
        let plan = PlusOffer.Plan(term: .monthly, displayPrice: "$2.99",
                                  introDisplayPrice: "$1.99", trialDays: 7)

        XCTAssertNil(plan.trialDays)
        XCTAssertNil(plan.introDisplayPrice)
        let copy = PaywallCopy.callToAction(.monthly, offer: offer())
        XCTAssertFalse(copy.lowercased().contains("free"), copy)
        XCTAssertTrue(copy.contains("$2.99"), copy)
    }

    func testBothPricesAndBothTermsReadWithoutATap() {
        let offer = offer()

        XCTAssertEqual(PaywallCopy.callToAction(.annual, offer: offer),
                       "Start 7 days free — then $29.99 a year")
        for term in PlusPlan.Term.allCases {
            let terms = PaywallCopy.terms(term, offer: offer)
            XCTAssertTrue(terms.contains(offer.plan(term).displayPrice), terms)
            XCTAssertTrue(terms.contains("until you cancel"), terms)
            XCTAssertTrue(terms.contains("Cancel any time in the App Store."), terms)
        }
    }

    func testTheIntroPriceIsStatedWithWhatFollowsIt() {
        let offer = PlusOffer(monthly: PlusOffer.Plan(term: .monthly, displayPrice: "$2.99"),
                              annual: PlusOffer.Plan(term: .annual, displayPrice: "$29.99",
                                                     introDisplayPrice: "$19.99",
                                                     trialDays: PlusPlan.trialDays))

        let terms = PaywallCopy.terms(.annual, offer: offer)
        XCTAssertTrue(terms.contains("$19.99 for the first year"), terms)
        XCTAssertTrue(terms.contains("then $29.99 a year"), terms)
        XCTAssertEqual(PaywallCopy.callToAction(.annual, offer: offer),
                       "Start 7 days free — then $19.99 for the first year")
    }

    func testTheScanCountIsAFactAndNeverANag() {
        XCTAssertNil(PaywallCopy.scansLine(used: 0))
        XCTAssertEqual(PaywallCopy.scansLine(used: 1), "You've used 1 free receipt scan.")
        XCTAssertEqual(PaywallCopy.scansLine(used: 3), "You've used 3 free receipt scans.")
    }

    func testDismissingAsksNothingASecondTime() {
        XCTAssertNil(PaywallScreen.message(for: .cancelled))
        XCTAssertNil(PaywallScreen.message(for: .purchased))
        XCTAssertNotNil(PaywallScreen.message(for: .unavailable))
    }

    // MARK: - No key, no sale

    func testNothingIsSoldWhenNoSubscriptionIsConfigured() async throws {
        let store = try makeStore()

        let bought = await store.purchase(.annual)
        let restored = await store.restore()

        XCTAssertEqual(bought, .unavailable)
        XCTAssertEqual(restored, .unavailable)
        XCTAssertNil(store.offer, "no configuration means no price to quote")
        XCTAssertFalse(store.isPlus)
    }

    func testABoughtSubscriptionIsHeldImmediately() async throws {
        let store = try makeStore(purchase: { _ in .purchased })

        XCTAssertEqual(await store.purchase(.annual), .purchased)
        XCTAssertTrue(store.isPlus)
        XCTAssertEqual(store.gate(.priceHistory), .allowed)
    }
}
