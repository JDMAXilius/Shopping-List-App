import Catalog
import Core
import Data
import Foundation
import XCTest

@testable import Bagged

@MainActor
final class CaptureSessionTests: XCTestCase {
    private let kitchenID = KitchenID()

    private struct Harness {
        let session: CaptureSession
        let repository: Repository
        let store: ListStore
        let backend: FakeScanBackend
    }

    private func makeHarness(_ outcomes: [ScanOutcome]) throws -> Harness {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("capture-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        let repository = try Repository(database: database)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(UUID().uuidString)"))
        let catalog = ListCatalog(database: try? CatalogDatabase.bundled())
        let store = try ListStore(repository: repository, kitchenID: kitchenID, catalog: catalog,
                                  defaults: defaults)
        store.addShop(named: "Trader Joe's")
        let backend = FakeScanBackend(outcomes: outcomes)
        let session = CaptureSession(repository: repository, kitchenID: kitchenID, store: store,
                                     catalog: catalog, backend: backend)
        return Harness(session: session, repository: repository, store: store, backend: backend)
    }

    private let receiptJSON = """
        {"lines":[{"raw_text":"MILK 1L","amount_minor":189,"quantity":1,"confidence":"sure",
        "match_hint":"milk"},
        {"raw_text":"TJ ORG BABY SPNC","amount_minor":299,"quantity":1,"confidence":"not_sure"},
        {"raw_text":"BAG FEE","amount_minor":10,"quantity":1,"confidence":"no_match"}],
        "shop_name":"Trader Joe's","total_minor":498,"currency":"USD","is_plus":false,
        "scans_used":1}
        """

    // A per-item discount line, printed exactly as a till prints one.
    private let couponJSON = """
        {"lines":[{"raw_text":"MILK 1L","amount_minor":189,"quantity":1,"confidence":"sure",
        "match_hint":"milk"},
        {"raw_text":"MFR COUPON MILK 2%","amount_minor":-100,"quantity":1,"confidence":"sure",
        "match_hint":"milk"}],
        "shop_name":"Trader Joe's","total_minor":89,"currency":"USD","is_plus":false,
        "scans_used":1}
        """

    // The refutation's receipt, exactly: no grand total read, and every till line the model
    // refused to call a purchase still printed on the paper.
    private let noTotalJSON = """
        {"lines":[{"raw_text":"MILK","amount_minor":449,"quantity":1,"confidence":"sure",
        "match_hint":"milk"},
        {"raw_text":"SOURDOUGH","amount_minor":329,"quantity":1,"confidence":"sure",
        "match_hint":"bread"},
        {"raw_text":"SUBTOTAL","amount_minor":778,"quantity":1,"confidence":"no_match"},
        {"raw_text":"TAX","amount_minor":62,"quantity":1,"confidence":"no_match"},
        {"raw_text":"TOTAL","amount_minor":840,"quantity":1,"confidence":"no_match"},
        {"raw_text":"CASH","amount_minor":1000,"quantity":1,"confidence":"no_match"},
        {"raw_text":"CHANGE","amount_minor":160,"quantity":1,"confidence":"no_match"}],
        "shop_name":"Trader Joe's","total_minor":null,"currency":"USD","is_plus":false,
        "scans_used":1}
        """

    private func parsed(_ json: String) throws -> ScanOutcome {
        .scanned(try JSONDecoder().decode(ScanReceipt.self, from: Foundation.Data(json.utf8)))
    }

    private var jpeg: Foundation.Data { Foundation.Data([0xFF, 0xD8, 0xFF, 0xE0]) }

    // MARK: - The >3× gate

    private func line(amount: Int, quantity: Double = 1, estimate: Int?) -> CaptureLine {
        CaptureLine(rawText: "MILK 1L", amount: Money(minorUnits: amount), quantity: quantity,
                    confidence: .sure,
                    match: CaptureMatch(itemID: ItemID(), name: "Milk",
                                        estimate: estimate.map { Money(minorUnits: $0) }),
                    decision: .accept)
    }

    func testTheThreeTimesFlagNamesBothNumbersAndSparesNearMisses() {
        XCTAssertEqual(line(amount: 1400, estimate: 350).estimateFlag,
                       "$14.00 — more than 3× the usual $3.50")
        // Exactly 3× is not MORE than 3×, and a penny under it is not either.
        XCTAssertNil(line(amount: 1050, estimate: 350).estimateFlag)
        XCTAssertNil(line(amount: 1049, estimate: 350).estimateFlag)
        XCTAssertEqual(line(amount: 1051, estimate: 350).estimateFlag,
                       "$10.51 — more than 3× the usual $3.50")
        // No seed, no comparison — and therefore no claim.
        XCTAssertNil(line(amount: 9999, estimate: nil).estimateFlag)
    }

    func testTheFlagComparesTheEstimateItNames() {
        // The sentence says $3.50 because the app shows ~$3.50: the compared number and the
        // named number are the same number.
        XCTAssertEqual(line(amount: 1051, estimate: 337).estimateFlag,
                       "$10.51 — more than 3× the usual $3.50")
        XCTAssertNil(line(amount: 1050, estimate: 337).estimateFlag)
    }

    func testThreeOfSomethingIsNotThreeTimesItsPrice() {
        // The line's amount is what was printed; the comparison happens per unit, where the
        // seeded estimate lives.
        XCTAssertNil(line(amount: 1050, quantity: 3, estimate: 350).estimateFlag)
        XCTAssertEqual(line(amount: 3000, quantity: 2, estimate: 350).estimateFlag,
                       "$15.00 each — more than 3× the usual $3.50")
    }

    // MARK: - Zero or less is not a price

    func testZeroOrLessIsNotAPriceWhateverTheDecisionSays() {
        let free = line(amount: 0, estimate: 350)
        let coupon = line(amount: -100, estimate: 350)
        // Both are accepted lines with a match: the amount alone decides, structurally.
        XCTAssertEqual(free.decision, .accept)
        XCTAssertFalse(free.isPriced, "an amount of zero is not a price")
        XCTAssertFalse(coupon.isPriced, "and neither is money off")
        XCTAssertTrue(free.isMoneyOff)
        XCTAssertEqual(free.moneyOffText, "no amount")
        XCTAssertEqual(coupon.moneyOffText, "$1.00 off")
        XCTAssertNil(coupon.estimateFlag)
    }

    func testACouponIsShownAndMatchedButNeverBecomesAPrice() async throws {
        let harness = try makeHarness([try parsed(couponJSON)])
        let milkID = ItemID.catalog(1)
        // The kitchen already knows this till text, so the line arrives matched — the path that
        // used to walk it into the price book at -$1.00.
        try harness.repository.append(.alias(rawText: "MFR COUPON MILK 2%", itemID: milkID),
                                      kitchenID: kitchenID)

        await harness.session.capture(jpeg: jpeg)

        XCTAssertEqual(harness.session.lines.count, 2, "a coupon is on the receipt and stays shown")
        let coupon = try XCTUnwrap(harness.session.lines.first { $0.amount.minorUnits < 0 })
        XCTAssertNotNil(coupon.match, "the alias half is unaffected")
        XCTAssertNotEqual(coupon.decision, .accept, "it never arrives accepted")
        XCTAssertFalse(coupon.isPriced)

        // Not even the user matching it by hand can make it a price.
        harness.session.choose(itemID: milkID, name: "Milk", for: coupon.id)
        XCTAssertFalse(try XCTUnwrap(harness.session.lines.first { $0.id == coupon.id }).isPriced)
        XCTAssertTrue(harness.session.commit())

        let observations = try harness.repository.priceObservations()
        XCTAssertTrue(observations.allSatisfy { $0.amount.minorUnits > 0 },
                      "no observation with an amount of zero or less was ever written")
        XCTAssertTrue(observations.filter { $0.itemID == milkID && $0.amount.minorUnits < 0 }.isEmpty)
        // The alias the user's correction earned is still remembered.
        let aliases = try harness.repository.aliases()
        let index = try XCTUnwrap(aliases.index(forKey: Merge.aliasKey("MFR COUPON MILK 2%")))
        XCTAssertEqual(aliases[index].value, milkID)
    }

    // MARK: - Nothing commits unreviewed

    func testNothingAtAllIsWrittenBeforeCommit() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        let baseline = try harness.repository.unpushedOps().count

        await harness.session.capture(jpeg: jpeg)
        XCTAssertEqual(harness.session.stage, .review)
        XCTAssertEqual(harness.session.lines.count, 3)

        let spinach = try XCTUnwrap(harness.session.lines.first { $0.rawText == "TJ ORG BABY SPNC" })
        harness.session.choose(itemID: ItemID(), name: "Baby spinach", for: spinach.id)
        let fee = try XCTUnwrap(harness.session.lines.first { $0.rawText == "BAG FEE" })
        harness.session.ignore(fee.id)

        // Reviewing is not writing: not one op, not one price, not one alias, not one receipt.
        XCTAssertEqual(try harness.repository.unpushedOps().count, baseline)
        XCTAssertTrue(try harness.repository.priceObservations().isEmpty)
        XCTAssertTrue(try harness.repository.aliases().isEmpty)
        XCTAssertTrue(try harness.repository.receipts().isEmpty)
        // The photo is still the pending scan's, and still queued.
        XCTAssertEqual(try harness.repository.queuedScans().count, 1)
    }

    func testCommitWritesOnePriceOpPerAcceptedLineAndNoneForIgnoredOnes() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        await harness.session.capture(jpeg: jpeg)

        let milkID = ItemID.catalog(1)
        let spinachID = ItemID.catalog(2)
        let milk = try XCTUnwrap(harness.session.lines.first { $0.rawText == "MILK 1L" })
        let spinach = try XCTUnwrap(harness.session.lines.first { $0.rawText == "TJ ORG BABY SPNC" })
        let fee = try XCTUnwrap(harness.session.lines.first { $0.rawText == "BAG FEE" })
        harness.session.choose(itemID: milkID, name: "Milk", for: milk.id)
        harness.session.choose(itemID: spinachID, name: "Baby spinach", for: spinach.id)
        harness.session.ignore(fee.id)

        XCTAssertTrue(harness.session.commit())

        let observations = try harness.repository.priceObservations()
        XCTAssertEqual(observations.count, 2)
        XCTAssertEqual(Set(observations.map(\.itemID)), [milkID, spinachID])
        XCTAssertEqual(observations.map(\.source), [.receipt, .receipt])
        XCTAssertEqual(observations.first { $0.itemID == milkID }?.amount,
                       Money(minorUnits: 189, currencyCode: "USD"))
        // The receipt row took the photo over in the same transaction that dropped the scan.
        XCTAssertEqual(try harness.repository.receipts().count, 1)
        XCTAssertTrue(try harness.repository.pendingScans().isEmpty)
        XCTAssertEqual(harness.session.result?.pricedCount, 2)
        XCTAssertEqual(harness.session.result?.lineCount, 3)
    }

    func testIgnoringALineRemembersItWithNoItemAtAll() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        await harness.session.capture(jpeg: jpeg)
        let fee = try XCTUnwrap(harness.session.lines.first { $0.rawText == "BAG FEE" })
        harness.session.ignore(fee.id)
        XCTAssertTrue(harness.session.commit())

        let aliases = try harness.repository.aliases()
        let key = Merge.aliasKey("BAG FEE")
        let index = try XCTUnwrap(aliases.index(forKey: key), "the alias must exist")
        // Present with a nil value: "ignore forever", which is not the same as never asked.
        XCTAssertNil(aliases[index].value)
        XCTAssertTrue(try harness.repository.priceObservations().filter {
            $0.amount == Money(minorUnits: 10, currencyCode: "USD")
        }.isEmpty)
    }

    func testCorrectingAMatchRemembersTheItemThatWasChosen() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        await harness.session.capture(jpeg: jpeg)
        let spinach = try XCTUnwrap(harness.session.lines.first { $0.rawText == "TJ ORG BABY SPNC" })
        let chosen = ItemID.catalog(42)
        harness.session.choose(itemID: chosen, name: "Baby spinach", for: spinach.id)
        XCTAssertTrue(harness.session.commit())

        let aliases = try harness.repository.aliases()
        let index = try XCTUnwrap(aliases.index(forKey: Merge.aliasKey("TJ ORG BABY SPNC")))
        XCTAssertEqual(aliases[index].value, chosen)
    }

    func testARememberedAliasDecidesTheNextReceiptWithoutAsking() async throws {
        let harness = try makeHarness([try parsed(receiptJSON), try parsed(receiptJSON)])
        await harness.session.capture(jpeg: jpeg)
        let fee = try XCTUnwrap(harness.session.lines.first { $0.rawText == "BAG FEE" })
        harness.session.ignore(fee.id)
        XCTAssertTrue(harness.session.commit())

        harness.session.retakePhoto()
        await harness.session.capture(jpeg: jpeg)
        let second = try XCTUnwrap(harness.session.lines.first { $0.rawText == "BAG FEE" })
        XCTAssertEqual(second.decision, .ignore)
        XCTAssertTrue(second.isRemembered)
        // Already remembered: committing again writes no second alias for it.
        XCTAssertNil(second.alias)
    }

    // MARK: - Offline is the promised behaviour

    func testAnUnreachableServerKeepsThePhotoQueuedAndSaysSo() async throws {
        let harness = try makeHarness([.notReachable])
        let baseline = try harness.repository.unpushedOps().count

        await harness.session.capture(jpeg: jpeg)

        XCTAssertEqual(harness.session.stage, .waiting)
        let queued = try harness.repository.queuedScans()
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.state, .queued)
        XCTAssertNotNil(try harness.repository.scanPhoto(try XCTUnwrap(queued.first).id))
        XCTAssertEqual(try harness.repository.unpushedOps().count, baseline)
    }

    func testAQueuedScanIsPickedUpOnSessionEntry() async throws {
        let harness = try makeHarness([.notReachable])
        let stranded = try harness.repository.enqueueScan(jpeg: jpeg)
        // A scan the app was killed mid-parse leaves `parsing` behind; entry puts it back.
        try harness.repository.markScan(stranded.id, .parsing)

        let session = CaptureSession(repository: harness.repository, kitchenID: kitchenID,
                                     store: harness.store, catalog: ListCatalog(database: nil),
                                     backend: FakeScanBackend(outcomes: []))

        XCTAssertEqual(session.waiting.map(\.id), [stranded.id])
        XCTAssertEqual(session.stage, .idle)
    }

    func testAScanAnEarlierBuildLeftFailedIsSweptBackIntoTheQueue() throws {
        let harness = try makeHarness([])
        let orphan = try harness.repository.enqueueScan(jpeg: jpeg)
        // `failed` is a state nothing queries: a photo in it can be neither read nor deleted by
        // any screen, so entry is what sweeps it.
        try harness.repository.markScan(orphan.id, .failed)

        let session = CaptureSession(repository: harness.repository, kitchenID: kitchenID,
                                     store: harness.store, catalog: ListCatalog(database: nil),
                                     backend: FakeScanBackend(outcomes: []))

        XCTAssertEqual(session.waiting.map(\.id), [orphan.id])
        XCTAssertTrue(try harness.repository.pendingScans().allSatisfy { $0.state == .queued })
    }

    func testOurOwnBugKeepsThePhotoAndOffersItAgain() async throws {
        for outcome in [ScanOutcome.rejected, .unexpected(status: 418)] {
            let harness = try makeHarness([outcome])
            let pending = try harness.repository.enqueueScan(jpeg: jpeg)

            await harness.session.read(pending)

            XCTAssertEqual(harness.session.stage, .failed(.ourBug), "\(outcome)")
            // The user did nothing wrong — a shop name we sent too long, a gateway that answered
            // for us — so the photo stays readable instead of being stranded forever.
            XCTAssertEqual(try harness.repository.queuedScans().map(\.id), [pending.id])
            XCTAssertNotNil(try harness.repository.scanPhoto(pending.id))
            XCTAssertEqual(harness.session.scan?.id, pending.id, "so the screen can offer a retry")
            XCTAssertTrue(try harness.repository.pendingScans().filter { $0.state == .failed }
                .isEmpty, "and no row is left in a state nothing sweeps")
        }
        XCTAssertTrue(ReceiptCameraScreen.keepsThePhoto(.ourBug))
        XCTAssertFalse(ReceiptCameraScreen.sentence(.ourBug).contains("Take another"),
                       "the sentence must not send the user away from a photo we still hold")
    }

    func testAPhotoOnlyANewPhotoCanFixIsDeletedNotStranded() async throws {
        for outcome in [ScanOutcome.unreadableImage(freeScan: .refunded),
                        .imageTooLarge(maxBytes: 8 * 1024 * 1024)] {
            let harness = try makeHarness([outcome])
            let pending = try harness.repository.enqueueScan(jpeg: jpeg)

            await harness.session.read(pending)

            // Nothing will ever read this file again, so the bytes go with the row: no orphan
            // JPEG in the container, and no `failed` row waiting for a sweeper that isn't there.
            XCTAssertTrue(try harness.repository.pendingScans().isEmpty, "\(outcome)")
            XCTAssertFalse(FileManager.default.fileExists(atPath: pending.photoPath), "\(outcome)")
            XCTAssertNil(harness.session.scan)
            XCTAssertTrue(harness.session.waiting.isEmpty)
        }
        XCTAssertFalse(ReceiptCameraScreen.keepsThePhoto(.unreadable))
        XCTAssertFalse(ReceiptCameraScreen.keepsThePhoto(.tooLarge))
        XCTAssertTrue(ReceiptCameraScreen.sentence(.unreadable).contains("wasn't kept"),
                      "a photo we deleted is not described as kept")
    }

    func testTheReceiptUnderReviewIsNotAlsoWaitingToBeRead() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        await harness.session.capture(jpeg: jpeg)

        XCTAssertEqual(harness.session.stage, .review)
        // The row stays queued — that is what keeps the promise across an app kill — but the
        // flow must not offer to read it again and throw every hand-match away.
        XCTAssertEqual(try harness.repository.queuedScans().count, 1)
        XCTAssertTrue(harness.session.waiting.isEmpty)

        harness.session.retakePhoto()
        XCTAssertEqual(harness.session.waiting.count, 1, "letting go of it puts it back on offer")
    }

    func testASecondReadOfThePhotoInFlightIsNotStarted() async throws {
        let harness = try makeHarness([try parsed(receiptJSON), try parsed(receiptJSON)])
        let pending = try harness.repository.enqueueScan(jpeg: jpeg)

        async let first: Void = harness.session.read(pending)
        async let second: Void = harness.session.read(pending)
        _ = await (first, second)

        let calls = await harness.backend.calls
        XCTAssertEqual(calls.count, 1,
                       "one photo, one free scan — a read in flight is not re-entrant")
        XCTAssertEqual(harness.session.stage, .review)
        XCTAssertEqual(harness.session.lines.count, 3)
    }

    func testQuotaExhaustedRoutesToThePaywallAndKeepsThePhoto() async throws {
        let harness = try makeHarness([.quotaExhausted(scansUsed: 3)])

        await harness.session.capture(jpeg: jpeg)

        XCTAssertEqual(harness.session.stage, .handoff(.paywall(scansUsed: 3)))
        XCTAssertEqual(try harness.repository.queuedScans().count, 1)
        XCTAssertTrue(try harness.repository.receipts().isEmpty)
    }

    // MARK: - The shop this receipt is filed under

    func testFilingAReceiptNeverRePointsTheList() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        harness.store.addShop(named: "Whole Foods")
        let wholeFoods = try XCTUnwrap(harness.store.activeShopID)
        let traderJoes = try XCTUnwrap(harness.store.shops.first { $0.name == "Trader Joe's" }?.id)

        await harness.session.capture(jpeg: jpeg)

        // The printed name decided this receipt's shop; the list is pointed somewhere else and
        // stays there, through the commit and after it.
        XCTAssertEqual(harness.session.shopID, traderJoes)
        XCTAssertEqual(harness.store.activeShopID, wholeFoods)
        XCTAssertTrue(harness.session.commit())
        XCTAssertEqual(harness.store.activeShopID, wholeFoods, "the list stays where it was")
        XCTAssertEqual(try harness.repository.receipts().first?.shopID, traderJoes)
    }

    func testNoScreenInTheFlowReachesThroughToTheGlobalActiveShop() throws {
        // View code, so the pin is on the source: the picker returns a choice, and a dismissal
        // that chose nothing must leave the receipt's shop exactly as it was.
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for screen in ["ReceiptReviewScreen", "EnterByHandScreen"] {
            let source = try String(contentsOf: directory.appendingPathComponent("\(screen).swift"),
                                    encoding: .utf8)
            XCTAssertFalse(source.contains("session.store.activeShopID"),
                           "\(screen) must take the picker's choice, never the active shop")
            XCTAssertFalse(source.contains("ShopSwitcherSheet(store: session.store)"),
                           "\(screen) must not present the switcher, which re-points the list")
        }
    }

    func testAPrintedNameThatDisagreesWithTheChosenShopIsNotAFootnote() {
        XCTAssertEqual(ReceiptReviewScreen.disagreement(printed: "TRADER JOE'S #123",
                                                        chosen: "Whole Foods"),
                       "This receipt printed “TRADER JOE'S #123” but it will be filed under Whole Foods.")
        XCTAssertNil(ReceiptReviewScreen.disagreement(printed: "trader joe's", chosen: "Trader Joe's"),
                     "the same shop typed two ways is not a disagreement")
        XCTAssertNil(ReceiptReviewScreen.disagreement(printed: nil, chosen: "Whole Foods"))
        XCTAssertNil(ReceiptReviewScreen.disagreement(printed: "TRADER JOE'S", chosen: nil))
    }

    // MARK: - The commit is all of it or none of it

    func testACommitThatFailsWritesNothingAndLeavesTheReceiptRetryable() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        await harness.session.capture(jpeg: jpeg)
        let spinach = try XCTUnwrap(harness.session.lines.first { $0.rawText == "TJ ORG BABY SPNC" })
        harness.session.choose(itemID: ItemID.catalog(2), name: "Baby spinach", for: spinach.id)
        // The scan the commit needs is gone from under it — the shape a busy database takes when
        // the widget writes while we are backgrounded.
        try harness.repository.deleteScan(try XCTUnwrap(harness.session.scan).id)

        XCTAssertFalse(harness.session.commit())

        XCTAssertTrue(try harness.repository.priceObservations().isEmpty, "not one price")
        XCTAssertTrue(try harness.repository.aliases().isEmpty, "not one alias")
        XCTAssertTrue(try harness.repository.receipts().isEmpty)
        XCTAssertEqual(harness.session.stage, .review, "so the user can save again")
        XCTAssertNil(harness.session.result, "and the result screen has nothing to claim")
    }

    // MARK: - The till's total, or nothing

    /// W7 P1-A: the fallback summed SUBTOTAL + TAX + TOTAL + CASH + CHANGE into `totalMinor` and
    /// the Prices tab printed it in solid ink as "the till's own total". This receipt charged
    /// $8.40; the sum is $36.18. Neither is stored now, because neither was printed.
    func testAReceiptWithNoPrintedTotalStoresNoneAndInventsNothing() async throws {
        let harness = try makeHarness([try parsed(noTotalJSON)])
        await harness.session.capture(jpeg: jpeg)

        let milk = try XCTUnwrap(harness.session.lines.first { $0.rawText == "MILK" })
        let bread = try XCTUnwrap(harness.session.lines.first { $0.rawText == "SOURDOUGH" })
        harness.session.choose(itemID: ItemID.catalog(1), name: "Milk", for: milk.id)
        harness.session.choose(itemID: ItemID.catalog(2), name: "Sourdough", for: bread.id)

        XCTAssertNil(harness.session.printedTotal, "the model read no total, so there is none")
        XCTAssertTrue(harness.session.commit())

        let receipt = try XCTUnwrap(try harness.repository.receipts().first)
        XCTAssertNil(receipt.totalMinor,
                     "a sum of OCR lines is not the till's total and is never stored as one")
        XCTAssertNotEqual(receipt.totalMinor, 3_618, "the number that was 4.31× what was charged")
        // What it did do is stored as ours: the two lines that became prices, added up.
        XCTAssertEqual(receipt.recordedMinor, 778)
        XCTAssertEqual(try harness.repository.priceObservations().count, 2)
    }

    func testAPrintedTotalIsStoredExactlyAsPrintedAndNeverRecomputed() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        await harness.session.capture(jpeg: jpeg)
        let milk = try XCTUnwrap(harness.session.lines.first { $0.rawText == "MILK 1L" })
        let spinach = try XCTUnwrap(harness.session.lines.first { $0.rawText == "TJ ORG BABY SPNC" })
        harness.session.choose(itemID: ItemID.catalog(1), name: "Milk", for: milk.id)
        harness.session.choose(itemID: ItemID.catalog(2), name: "Baby spinach", for: spinach.id)
        let fee = try XCTUnwrap(harness.session.lines.first { $0.rawText == "BAG FEE" })
        harness.session.ignore(fee.id)

        XCTAssertEqual(harness.session.printedTotal, Money(minorUnits: 498))
        XCTAssertTrue(harness.session.commit())

        let receipt = try XCTUnwrap(try harness.repository.receipts().first)
        XCTAssertEqual(receipt.totalMinor, 498, "what the till printed, unchanged")
        // The $0.10 bag fee was ignored, so what reached the price book is less than the total —
        // and the two numbers are kept apart rather than reconciled into one.
        XCTAssertEqual(receipt.recordedMinor, 488)
    }

    /// RULING 3: the user is the last check, and until now they were shown no total at all.
    func testTheReviewScreenSaysWhoseNumberEachOneIs() {
        let none = ReceiptReviewScreen.totalNote(printed: nil, recorded: Money(minorUnits: 778))
        XCTAssertTrue(none.contains("wasn't read"))
        XCTAssertTrue(none.contains("$7.78"))
        XCTAssertTrue(none.contains("ours, not what the till charged"),
                      "a computed stand-in must never read as the printed total")
        let printed = ReceiptReviewScreen.totalNote(printed: Money(minorUnits: 840),
                                                    recorded: Money(minorUnits: 778))
        XCTAssertTrue(printed.contains("$7.78"))
        XCTAssertTrue(printed.contains("the rest is tax"))
        XCTAssertFalse(printed.contains("wasn't read"))
        // Nothing left over, so nothing is claimed to be left over.
        XCTAssertEqual(ReceiptReviewScreen.totalNote(printed: Money(minorUnits: 778),
                                                     recorded: Money(minorUnits: 778)),
                       "The lines you keep add up to $7.78.")
    }

    /// W7 P2: `commit` took the model's date unclamped while `record` clamped it. A smudged
    /// 01/03/27 read as 2027 made a `trusted` price that printed as "today" and outranked every
    /// real one for 90 days — and the month filter excluded it, so the money vanished twice.
    func testAFutureDatedReceiptIsClampedByTheCommitToo() async throws {
        let future = receiptJSON.replacingOccurrences(
            of: "\"scans_used\":1", with: "\"scans_used\":1,\"purchased_at\":\"2099-01-03\"")
        let harness = try makeHarness([try parsed(future)])
        await harness.session.capture(jpeg: jpeg)
        let milk = try XCTUnwrap(harness.session.lines.first { $0.rawText == "MILK 1L" })
        harness.session.choose(itemID: ItemID.catalog(1), name: "Milk", for: milk.id)

        XCTAssertTrue(harness.session.commit())

        XCTAssertFalse(try harness.repository.priceObservations().isEmpty)
        for observation in try harness.repository.priceObservations() {
            XCTAssertLessThanOrEqual(observation.date.timeIntervalSinceNow, 1,
                                     "one clamp, every path that writes a price")
        }
        XCTAssertEqual(CaptureSession.honestDate(Date(timeIntervalSince1970: 0),
                                                 now: Date(timeIntervalSince1970: 100)),
                       Date(timeIntervalSince1970: 0), "a real past date is left alone")
        XCTAssertEqual(CaptureSession.honestDate(Date(timeIntervalSince1970: 200),
                                                 now: Date(timeIntervalSince1970: 100)),
                       Date(timeIntervalSince1970: 100))
    }

    // MARK: - The typed price: enter by hand, and a barcode

    private func typedLine(_ amount: Int, quantity: Double = 1, itemID: ItemID = ItemID(),
                           rawText: String = "", teaches: Bool = false) -> CaptureLine {
        CaptureLine(rawText: rawText, amount: Money(minorUnits: amount), quantity: quantity,
                    confidence: .sure,
                    match: CaptureMatch(itemID: itemID, name: "Milk", estimate: nil),
                    decision: .accept, alias: teaches ? .remember(itemID) : nil)
    }

    func testATypedPriceIsTaggedTypedAndLeavesAReviewInProgressAlone() async throws {
        let harness = try makeHarness([try parsed(receiptJSON)])
        await harness.session.capture(jpeg: jpeg)
        let shopID = try XCTUnwrap(harness.store.activeShopID)
        let itemID = ItemID.catalog(7)

        XCTAssertTrue(harness.session.record(typedLine(449, itemID: itemID), shopID: shopID,
                                             date: Date()))

        let observations = try harness.repository.priceObservations()
        XCTAssertEqual(observations.count, 1)
        XCTAssertEqual(observations.first?.source, .typed)
        XCTAssertEqual(observations.first?.itemID, itemID)
        XCTAssertEqual(observations.first?.amount, Money(minorUnits: 449))
        // The receipt upstairs is untouched: same stage, same lines, same queued photo, no
        // receipt row, and nothing remembered that the user never matched.
        XCTAssertEqual(harness.session.stage, .review)
        XCTAssertEqual(harness.session.lines.count, 3)
        XCTAssertNotNil(harness.session.scan)
        XCTAssertTrue(try harness.repository.receipts().isEmpty)
        XCTAssertEqual(try harness.repository.queuedScans().count, 1)
        XCTAssertTrue(try harness.repository.aliases().isEmpty)
    }

    func testThreeOfSomethingRecordsWhatOneCost() throws {
        let harness = try makeHarness([])
        let shopID = try XCTUnwrap(harness.store.activeShopID)

        XCTAssertTrue(harness.session.record(typedLine(1050, quantity: 3), shopID: shopID,
                                             date: Date()))

        XCTAssertEqual(try harness.repository.priceObservations().first?.amount,
                       Money(minorUnits: 350))
    }

    func testATypedPriceIsNeverDatedIntoTheFuture() throws {
        let harness = try makeHarness([])
        let shopID = try XCTUnwrap(harness.store.activeShopID)

        XCTAssertTrue(harness.session.record(typedLine(449), shopID: shopID,
                                             date: Date().addingTimeInterval(10 * 86_400)))

        // A future date would outrank every real observation for 90 days, so it never lands.
        let observation = try XCTUnwrap(try harness.repository.priceObservations().first)
        XCTAssertLessThanOrEqual(observation.date.timeIntervalSinceNow, 1)
    }

    func testABarcodeIsTaughtOnceAndTheNextScanKnowsItWithoutAsking() throws {
        let harness = try makeHarness([])
        let shopID = try XCTUnwrap(harness.store.activeShopID)
        let code = "0071234567890"
        let taught = ItemID.catalog(11)

        XCTAssertTrue(harness.session.record(typedLine(199, itemID: taught, rawText: code,
                                                       teaches: true),
                                             shopID: shopID, date: Date()))

        let aliases = try harness.repository.aliases()
        let index = try XCTUnwrap(aliases.index(forKey: Merge.aliasKey(code)), "the code is taught")
        XCTAssertEqual(aliases[index].value, taught)

        // The next scan asks the kitchen, not the user — and prices the item it names, so the
        // two observations are one item's history.
        let known = try XCTUnwrap(harness.session.remembered(code))
        XCTAssertEqual(known.itemID, taught)
        XCTAssertTrue(harness.session.record(typedLine(209, itemID: known.itemID), shopID: shopID,
                                             date: Date()))

        XCTAssertEqual(Set(try harness.repository.priceObservations().map(\.itemID)), [taught])
        XCTAssertEqual(try harness.repository.aliases().count, 1)
    }

    func testTheItemWrittenIsTheItemTheScreenShowed() throws {
        let harness = try makeHarness([])
        let shopID = try XCTUnwrap(harness.store.activeShopID)
        let taught = ItemID.catalog(11)
        XCTAssertTrue(harness.session.record(typedLine(199, itemID: taught, rawText: "oat milk",
                                                       teaches: true),
                                             shopID: shopID, date: Date()))

        // The user answers the same text with a different item: the price follows what they were
        // looking at, and the alias follows the correction. Nothing is redirected behind them.
        let corrected = ItemID.catalog(12)
        XCTAssertTrue(harness.session.record(typedLine(209, itemID: corrected, rawText: "oat milk",
                                                       teaches: true),
                                             shopID: shopID, date: Date()))

        let observations = try harness.repository.priceObservations()
        XCTAssertEqual(Set(observations.map(\.itemID)), [taught, corrected])
        let aliases = try harness.repository.aliases()
        let index = try XCTUnwrap(aliases.index(forKey: Merge.aliasKey("oat milk")))
        XCTAssertEqual(aliases[index].value, corrected)
    }

    func testAnUnmatchedOrEmptyTypedLineWritesNothingAtAll() throws {
        let harness = try makeHarness([])
        let shopID = try XCTUnwrap(harness.store.activeShopID)
        var unmatched = typedLine(449)
        unmatched.match = nil
        unmatched.decision = .unresolved

        XCTAssertFalse(harness.session.record(unmatched, shopID: shopID, date: Date()))
        XCTAssertFalse(harness.session.record(typedLine(0), shopID: shopID, date: Date()))
        XCTAssertFalse(harness.session.record(typedLine(-100), shopID: shopID, date: Date()),
                       "money off is not a price on this path either")

        XCTAssertTrue(try harness.repository.priceObservations().isEmpty)
        XCTAssertTrue(try harness.repository.aliases().isEmpty)
    }

    func testTypingHalfAPoundSaysWhatTheScannedPathCanSay() throws {
        XCTAssertEqual(MoneyText.quantity(from: "0.5"), 0.5)
        XCTAssertEqual(MoneyText.quantity(from: "1,5"), 1.5)
        XCTAssertEqual(MoneyText.quantity(from: "2"), 2.0)
        XCTAssertNil(MoneyText.quantity(from: ""))
        XCTAssertNil(MoneyText.quantity(from: "0"), "nothing bought is not a quantity")
        XCTAssertNil(MoneyText.quantity(from: "two"))
        XCTAssertNil(MoneyText.quantity(from: "1.2.5"))
        XCTAssertEqual(MoneyText.quantityText(2), "2", "a whole count stays whole")
        XCTAssertEqual(MoneyText.quantityText(0.5), "0.5")

        let harness = try makeHarness([])
        let shopID = try XCTUnwrap(harness.store.activeShopID)
        XCTAssertTrue(harness.session.record(typedLine(449, quantity: 0.5), shopID: shopID,
                                             date: Date()))

        // Under one the printed amount stands, exactly as it does for a receipt line: $4.49 was
        // what was paid, and no per-unit price nobody paid is invented from it.
        XCTAssertEqual(try harness.repository.priceObservations().first?.amount,
                       Money(minorUnits: 449))
    }

    // MARK: - The money the two typed screens share

    func testMoneyIsBuiltFromMinorUnitsAndRefusesWhatIsNotAPrice() {
        XCTAssertEqual(MoneyText.money(from: "4.49", currencyCode: "USD"),
                       Money(minorUnits: 449))
        // "4.4" is $4.40, not $4.04 — padded on the right, like a till.
        XCTAssertEqual(MoneyText.money(from: "4.4", currencyCode: "USD"),
                       Money(minorUnits: 440))
        XCTAssertEqual(MoneyText.money(from: "4", currencyCode: "USD"),
                       Money(minorUnits: 400))
        XCTAssertEqual(MoneyText.money(from: ".49", currencyCode: "USD"),
                       Money(minorUnits: 49))
        XCTAssertEqual(MoneyText.money(from: "$4.49", currencyCode: "USD"),
                       Money(minorUnits: 449))
        XCTAssertEqual(MoneyText.money(from: "4,49", currencyCode: "USD"),
                       Money(minorUnits: 449))
        // A third decimal is not money: it is dropped, never rounded up into a price.
        XCTAssertEqual(MoneyText.money(from: "4.499", currencyCode: "USD"),
                       Money(minorUnits: 449))
        // Yen has no minor unit: 500 is ¥500 and must never become ¥5.00.
        XCTAssertEqual(MoneyText.money(from: "500", currencyCode: "JPY"),
                       Money(minorUnits: 500, currencyCode: "JPY"))
        XCTAssertNil(MoneyText.money(from: "", currencyCode: "USD"))
        XCTAssertNil(MoneyText.money(from: "4a9", currencyCode: "USD"))
        XCTAssertNil(MoneyText.money(from: "4.4.9", currencyCode: "USD"))
        XCTAssertNil(MoneyText.money(from: "1234567890", currencyCode: "USD"))
    }

    func testTheSavedSentenceNamesThePriceOfOne() {
        let item = CaptureMatch(itemID: ItemID(), name: "Milk", estimate: nil)
        let one = typedLine(449, itemID: item.itemID)
        XCTAssertEqual(TypedPriceEntry.savedSentence(item: item, line: one, shop: "Trader Joe's"),
                       "Saved: Milk — $4.49 at Trader Joe's, typed.")
        let three = typedLine(900, quantity: 3, itemID: item.itemID)
        XCTAssertEqual(TypedPriceEntry.savedSentence(item: item, line: three, shop: nil),
                       "Saved: Milk — $3.00 each, typed.")
    }

    // MARK: - The aha, once

    func testTheFirstReceiptSheetIsShownOnceAndOnlyForPricesThatExist() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "bagged.tests.\(UUID().uuidString)"))
        let priced = CaptureResult(lines: [line(amount: 100, estimate: nil)])
        var ignored = line(amount: 100, estimate: nil)
        ignored.decision = .ignore
        let nothingPriced = CaptureResult(lines: [ignored])

        XCTAssertFalse(FirstReceiptSheet.shouldShow(nil, defaults: defaults))
        // A receipt that produced no price has no aha to show, and does not spend the showing.
        XCTAssertFalse(FirstReceiptSheet.shouldShow(nothingPriced, defaults: defaults))
        XCTAssertTrue(FirstReceiptSheet.shouldShow(priced, defaults: defaults))

        FirstReceiptSheet.markShown(defaults)

        XCTAssertFalse(FirstReceiptSheet.shouldShow(priced, defaults: defaults))
        XCTAssertEqual(FirstReceiptSheet.headline(priced), "1 price is yours now")
    }

    func testTheResultOnlyClaimsEveryLineWhenEveryLineIsTrue() {
        let priced = CaptureResult(lines: [line(amount: 100, estimate: nil),
                                           line(amount: 200, estimate: nil)])
        XCTAssertEqual(priced.summary, "2 lines · 2 matched · every line became a price")

        var ignored = line(amount: 300, estimate: nil)
        ignored.decision = .ignore
        ignored.alias = .forget
        let mixed = CaptureResult(lines: [line(amount: 100, estimate: nil), ignored])
        XCTAssertEqual(mixed.summary, "2 lines · 2 matched · 1 became a price")
        XCTAssertEqual(mixed.ignoredCount, 1)
        XCTAssertEqual(mixed.rememberedCount, 1)
    }
}
