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
        let session = CaptureSession(repository: repository, kitchenID: kitchenID, store: store,
                                     catalog: catalog, backend: FakeScanBackend(outcomes: outcomes))
        return Harness(session: session, repository: repository, store: store)
    }

    private let receiptJSON = """
        {"lines":[{"raw_text":"MILK 1L","amount_minor":189,"quantity":1,"confidence":"sure",
        "match_hint":"milk"},
        {"raw_text":"TJ ORG BABY SPNC","amount_minor":299,"quantity":1,"confidence":"not_sure"},
        {"raw_text":"BAG FEE","amount_minor":10,"quantity":1,"confidence":"no_match"}],
        "shop_name":"Trader Joe's","total_minor":498,"currency":"USD","is_plus":false,
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

    func testQuotaExhaustedRoutesToThePaywallAndKeepsThePhoto() async throws {
        let harness = try makeHarness([.quotaExhausted(scansUsed: 3)])

        await harness.session.capture(jpeg: jpeg)

        XCTAssertEqual(harness.session.stage, .handoff(.paywall(scansUsed: 3)))
        XCTAssertEqual(try harness.repository.queuedScans().count, 1)
        XCTAssertTrue(try harness.repository.receipts().isEmpty)
    }

    // MARK: - The close

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

        XCTAssertTrue(try harness.repository.priceObservations().isEmpty)
        XCTAssertTrue(try harness.repository.aliases().isEmpty)
    }

    // MARK: - The money the two typed screens share

    func testMoneyIsBuiltFromMinorUnitsAndRefusesWhatIsNotAPrice() {
        XCTAssertEqual(TypedPriceEntry.money(from: "4.49", currencyCode: "USD"),
                       Money(minorUnits: 449))
        // "4.4" is $4.40, not $4.04 — padded on the right, like a till.
        XCTAssertEqual(TypedPriceEntry.money(from: "4.4", currencyCode: "USD"),
                       Money(minorUnits: 440))
        XCTAssertEqual(TypedPriceEntry.money(from: "4", currencyCode: "USD"),
                       Money(minorUnits: 400))
        XCTAssertEqual(TypedPriceEntry.money(from: ".49", currencyCode: "USD"),
                       Money(minorUnits: 49))
        XCTAssertEqual(TypedPriceEntry.money(from: "$4.49", currencyCode: "USD"),
                       Money(minorUnits: 449))
        XCTAssertEqual(TypedPriceEntry.money(from: "4,49", currencyCode: "USD"),
                       Money(minorUnits: 449))
        // A third decimal is not money: it is dropped, never rounded up into a price.
        XCTAssertEqual(TypedPriceEntry.money(from: "4.499", currencyCode: "USD"),
                       Money(minorUnits: 449))
        // Yen has no minor unit: 500 is ¥500 and must never become ¥5.00.
        XCTAssertEqual(TypedPriceEntry.money(from: "500", currencyCode: "JPY"),
                       Money(minorUnits: 500, currencyCode: "JPY"))
        XCTAssertNil(TypedPriceEntry.money(from: "", currencyCode: "USD"))
        XCTAssertNil(TypedPriceEntry.money(from: "4a9", currencyCode: "USD"))
        XCTAssertNil(TypedPriceEntry.money(from: "4.4.9", currencyCode: "USD"))
        XCTAssertNil(TypedPriceEntry.money(from: "1234567890", currencyCode: "USD"))
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
