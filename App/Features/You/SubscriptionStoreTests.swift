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
                           restore: SubscriptionStore.RestoreAction? = nil,
                           entitlement: SubscriptionStore.EntitlementReader? = nil) throws
        -> SubscriptionStore {
        let suite = try defaults ?? makeDefaults()
        return SubscriptionStore(defaults: suite, role: role, purchase: purchase,
                                 restore: restore, entitlement: entitlement)
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

    // MARK: - Entitlement arrives without a scan

    func testTheServerSayingPlusEntitlesADeviceThatHasNeverScanned() async throws {
        let defaults = try makeDefaults()
        let store = try makeStore(defaults: defaults,
                                  entitlement: { .found(isPlus: true, scansUsed: 0) })
        XCTAssertFalse(store.isPlus, "nothing has been asked yet")

        await store.refreshEntitlement()

        XCTAssertTrue(store.isPlus)
        XCTAssertFalse(store.mayBeOffered, "a subscriber must never meet the sales card")
        XCTAssertEqual(store.gate(.moreThanOneShop), .allowed,
                       "nor be offered a second shop they already own")
        // And it is kept, so the next launch does not start by selling to them again.
        XCTAssertTrue(SubscriptionStore(defaults: defaults).isPlus)
    }

    func testAFailedReadChangesNeitherEntitlementNorQuota() async throws {
        let store = try makeStore(entitlement: { .unavailable })
        store.record(try scanned(isPlus: true, scansUsed: 2))

        await store.refreshEntitlement()

        XCTAssertTrue(store.isPlus, "a network fact is never an entitlement fact")
        XCTAssertEqual(store.scansUsed, 2)
    }

    /// The expectation here was inverted on purpose after W10-P2-REFUTE: it used to assert that an
    /// absent row takes Plus away, which was the P1. A row that is not there is the server saying
    /// it has never heard of this user — not a statement that they are not Plus.
    func testAnAbsentRowSetsTheQuotaAndNeverTakesPlusAway() async throws {
        let absent = try makeStore(entitlement: { .absent })
        let failed = try makeStore(entitlement: { .unavailable })
        for store in [absent, failed] { store.record(try scanned(isPlus: true, scansUsed: 3)) }

        await absent.refreshEntitlement()
        await failed.refreshEntitlement()

        // `consume_scan` creates the row lazily, so no row is a user the server would give three
        // free scans to. The quota is the server's and it is written.
        XCTAssertEqual(absent.scansUsed, 0)
        XCTAssertEqual(absent.freeScansLeft, 3)
        // The money is not. A purchase made before signing in is attributed to a RevenueCat alias
        // the webhook skips, so no row is ever written — and this line used to take Plus from
        // someone who had paid, then offer to sell it to her again. A genuine lapse cannot arrive
        // this way: both consume_scan and apply_entitlement_event CREATE the row first.
        XCTAssertTrue(absent.isPlus, "an absent row revoked Plus from a paying subscriber")
        // The failed read still writes nothing at all, which is a different rule from this one.
        XCTAssertTrue(failed.isPlus)
        XCTAssertEqual(failed.scansUsed, 3)
    }

    /// The other side of it: absence must not INVENT Plus either. It only ever leaves it alone.
    func testAnAbsentRowLeavesAFreeAccountFree() async throws {
        let store = try makeStore(entitlement: { .absent })
        store.record(try scanned(isPlus: false, scansUsed: 2))

        await store.refreshEntitlement()

        XCTAssertFalse(store.isPlus)
        XCTAssertEqual(store.freeScansLeft, 3)
    }

    /// A lapse still has to work, and it arrives the only way a lapse can: as a row that says so.
    func testALapseStillRevokesPlusBecauseItArrivesAsARowNotAsAnAbsence() async throws {
        let store = try makeStore(entitlement: { .found(isPlus: false, scansUsed: 0) })
        store.record(try scanned(isPlus: true, scansUsed: 0))

        await store.refreshEntitlement()

        XCTAssertFalse(store.isPlus, "a server that says false is still obeyed")
    }

    /// A foreground that arrives while a read is out used to be dropped on the floor — one slow
    /// read swallowing the very foreground the packet exists to honour. Driven from inside the
    /// reader, which is genuinely "while the first read is in flight" and needs no clock and no
    /// second task to be deterministic.
    func testAForegroundArrivingDuringAReadIsTakenAfterwardsRatherThanDropped() async throws {
        let box = ReaderBox()
        let store = try makeStore(entitlement: {
            box.reads += 1
            if box.reads == 1 { await box.store?.refreshEntitlement() }
            return .absent
        })
        box.store = store

        await store.refreshEntitlement()

        XCTAssertEqual(box.reads, 2, "the foreground was swallowed by a read already in flight")
    }

    /// And it stops: the queued ask is cleared before the read it queued, so one re-entrant
    /// foreground buys exactly one more read rather than a loop that never returns.
    func testAQueuedForegroundDoesNotBecomeAnEndlessLoop() async throws {
        let box = ReaderBox()
        let store = try makeStore(entitlement: {
            box.reads += 1
            if box.reads <= 2 { await box.store?.refreshEntitlement() }
            return .absent
        })
        box.store = store

        await store.refreshEntitlement()

        XCTAssertEqual(box.reads, 3, "each in-flight arrival buys one more read, not a cascade")
    }

    func testTheServersHigherScanCountWinsOverThisDevicesLowerOne() async throws {
        let store = try makeStore(entitlement: { .found(isPlus: false, scansUsed: 3) })
        store.record(try scanned(isPlus: false, scansUsed: 1))
        XCTAssertEqual(store.freeScansLeft, 2)

        await store.refreshEntitlement()

        XCTAssertEqual(store.scansUsed, 3)
        XCTAssertEqual(store.freeScansLeft, 0, "the app is never more generous than the server")
        XCTAssertEqual(store.gate(.receiptScanning), .paywall)
    }

    func testALapsedSubscriptionStopsBeingPlus() async throws {
        let defaults = try makeDefaults()
        let store = try makeStore(defaults: defaults,
                                  entitlement: { .found(isPlus: false, scansUsed: 3) })
        store.record(try scanned(isPlus: true, scansUsed: 0))
        XCTAssertTrue(store.isPlus)

        await store.refreshEntitlement()

        XCTAssertFalse(store.isPlus, "the server is the truth in both directions")
        XCTAssertEqual(store.gate(.priceHistory), .paywall)
        XCTAssertFalse(SubscriptionStore(defaults: defaults).isPlus, "and it stays lapsed")
    }

    func testAJoinerIsNeverOfferedThePaywallWhateverTheReadAnswers() async throws {
        let reads: [EntitlementRead] = [.found(isPlus: false, scansUsed: 3), .absent, .unavailable]
        for read in reads {
            let store = try makeStore(.guest, entitlement: { read })

            await store.refreshEntitlement()

            XCTAssertFalse(store.mayBeOffered, "after \(read)")
            for capability in Capability.allCases {
                XCTAssertNotEqual(store.gate(capability), .paywall,
                                  "\(capability) sent a joiner to the paywall after \(read)")
            }
        }
    }

    func testAnAnswerThatLandedWhileTheReadWasInFlightIsNotUndoneByIt() async throws {
        let reader = StaleReader()
        let store = try makeStore(entitlement: { reader.answer() })
        reader.store = store
        // The row as it was BEFORE the scan this read overlaps: the request left first.
        reader.read = .found(isPlus: false, scansUsed: 0)

        await store.refreshEntitlement()

        XCTAssertEqual(store.scansUsed, 3, "a spent free scan must not reappear")
        XCTAssertEqual(store.gate(.receiptScanning), .paywall)
    }

    // MARK: - A purchase outranks a server that has not caught up

    /// The case the write counter cannot cover: this read STARTS after the purchase, so it is the
    /// newer request — and it still must not take Plus away from someone who has just paid.
    func testAPurchaseSurvivesAServerAnswerTheWebhookHasNotReachedYet() async throws {
        let lagging = try makeStore(purchase: { _ in .purchased },
                                    entitlement: { .found(isPlus: false, scansUsed: 1) })
        let bought = await lagging.purchase(.annual)
        XCTAssertEqual(bought, .purchased)

        await lagging.refreshEntitlement()

        XCTAssertTrue(lagging.isPlus, "the money is spent; the webhook is seconds behind")
        XCTAssertFalse(lagging.mayBeOffered)
        XCTAssertEqual(lagging.scansUsed, 1, "the quota is not the contested fact")

        // No row yet is the same lag wearing different clothes, not a lapse.
        let noRowYet = try makeStore(purchase: { _ in .purchased }, entitlement: { .absent })
        _ = await noRowYet.purchase(.monthly)
        await noRowYet.refreshEntitlement()
        XCTAssertTrue(noRowYet.isPlus)
        XCTAssertEqual(noRowYet.scansUsed, 0)
    }

    func testOnceTheWindowHasPassedALapsedSubscriptionStopsBeingPlus() async throws {
        let defaults = try makeDefaults()
        let store = try makeStore(defaults: defaults, purchase: { _ in .purchased },
                                  entitlement: { .found(isPlus: false, scansUsed: 3) })
        _ = await store.purchase(.annual)
        // Standing at the far side of the window: the purchase is older than the grace allows.
        defaults.set(Date().timeIntervalSinceReferenceDate - SubscriptionStore.purchaseGrace - 1,
                     forKey: SubscriptionStore.purchasedAtKey)

        await store.refreshEntitlement()

        XCTAssertFalse(store.isPlus, "the window bridges a webhook; it does not shield a lapse")
        XCTAssertEqual(store.gate(.priceHistory), .paywall)
        XCTAssertEqual(store.scansUsed, 3)
    }

    // MARK: - Signing out takes entitlement with it

    func testSigningOutLeavesNoPlusOnTheDeviceForTheNextPerson() async throws {
        let defaults = try makeDefaults()
        let store = try makeStore(defaults: defaults, purchase: { _ in .purchased })
        _ = await store.purchase(.annual)
        store.record(try scanned(isPlus: true, scansUsed: 2))

        store.forgetEntitlement()

        XCTAssertFalse(store.isPlus, "one person's Plus is not the next person's")
        XCTAssertEqual(store.scansUsed, 0)
        // Including the purchase moment: the grace window must not outlive the account either.
        let relaunched = SubscriptionStore(defaults: defaults,
                                           entitlement: { .found(isPlus: false, scansUsed: 0) })
        XCTAssertFalse(relaunched.isPlus)
        XCTAssertEqual(relaunched.scansUsed, 0)
        // Plus arriving again from a scan, with the server then saying no: with the purchase
        // moment cleared there is nothing left to hold it up, which is what proves it is gone.
        relaunched.record(try scanned(isPlus: true, scansUsed: 0))
        await relaunched.refreshEntitlement()
        XCTAssertFalse(relaunched.isPlus, "no purchase moment survived the sign-out")
    }

    func testAfterSigningOutTheNextReadIsWhatTheAppShows() async throws {
        let store = try makeStore(entitlement: { .found(isPlus: true, scansUsed: 1) })
        store.record(try scanned(isPlus: false, scansUsed: 3))
        store.forgetEntitlement()

        // Signing back in — or a second person signing in — is answered by their own row.
        await store.refreshEntitlement()

        XCTAssertTrue(store.isPlus, "nobody is punished for signing out; the read restores it")
        XCTAssertEqual(store.scansUsed, 1)
    }

    /// A read that a scan answers underneath — the whole race, with no scheduling to hope for:
    /// the scan lands while the reader is still deciding what to say.
    @MainActor private final class StaleReader {
        weak var store: SubscriptionStore?
        var read: EntitlementRead = .absent

        func answer() -> EntitlementRead {
            store?.record(.quotaExhausted(scansUsed: 3))
            return read
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

        let outcome = await store.purchase(.annual)
        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(store.isPlus)
        XCTAssertEqual(store.gate(.priceHistory), .allowed)
    }
}

/// Lets a reader closure call back into the store it belongs to, which is how "a foreground
/// arrived while a read was in flight" is reproduced without a clock or a second task.
@MainActor
private final class ReaderBox {
    var reads = 0
    var store: SubscriptionStore?
}
