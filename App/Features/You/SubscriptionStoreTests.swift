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
