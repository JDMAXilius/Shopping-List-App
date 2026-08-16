import Core
import Foundation
import GRDB
import XCTest
@testable import Data

final class RepositoryTests: XCTestCase {
    private let kitchenID = KitchenID()

    // A directory per stack: it stands in for the App Group container the photos live in.
    private func makeStack() throws -> (AppDatabase, Repository) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("repository-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let database = try AppDatabase(url: directory.appendingPathComponent("bagged.sqlite"))
        try database.migrate()
        return (database, try Repository(database: database))
    }

    private func snapshot(_ database: AppDatabase) throws -> [String: [Row]] {
        let orders = ["list_item": "id", "shop": "id", "aisle_order": "shop_id, position",
                      "price_observation": "op_id", "alias": "raw_text", "item_name": "item_id"]
        return try database.pool.read { db in
            var tables: [String: [Row]] = [:]
            for (table, order) in orders {
                tables[table] = try Row.fetchAll(db, sql: "SELECT * FROM \(table) ORDER BY \(order)")
            }
            return tables
        }
    }

    // The wave's invariant: incrementally-maintained tables == full-replay tables.
    private func assertRebuildEquivalent(_ database: AppDatabase, _ repository: Repository,
                                         file: StaticString = #filePath, line: UInt = #line) throws {
        let incremental = try snapshot(database)
        try repository.rebuild()
        let replayed = try snapshot(database)
        XCTAssertEqual(incremental, replayed, "incremental state diverged from full replay",
                       file: file, line: line)
    }

    private func allOps(_ database: AppDatabase) throws -> [Op] {
        try database.pool.read { db in
            try OpRecord.fetchAll(db, sql: "SELECT * FROM op ORDER BY clock, op_id")
                .map { try OpCoding.op(from: $0) }
        }
    }

    private func stripped(_ item: ListItem) -> ListItem {
        var copy = item
        copy.updatedFields = [:]
        return copy
    }

    func testEveryOpTypeRoundTrips() throws {
        let (database, repository) = try makeStack()
        let item = ListItem(name: "Milk")
        let shop = Shop(name: "Trader Joe's", branch: "Court St", wakeRadius: 200, wakeEnabled: true)
        let observation = PriceObservation(itemID: ItemID(), shopID: shop.id, date: Date(),
                                           amount: Money(minorUnits: 449), source: .receipt)
        let order = AisleOrder(shopID: shop.id, ordered: [CategoryID("produce"), CategoryID("dairy")])
        let appended = [
            try repository.append(.add(item), kitchenID: kitchenID),
            try repository.append(.check(item.listItemID), kitchenID: kitchenID),
            try repository.append(.uncheck(item.listItemID), kitchenID: kitchenID),
            try repository.append(.edit(item.listItemID, [.quantity(2), .note("2%")]),
                                  kitchenID: kitchenID),
            try repository.append(.price(observation), kitchenID: kitchenID),
            try repository.append(.shop(.upsert(shop)), kitchenID: kitchenID),
            try repository.append(.shop(.aisleOrder(order)), kitchenID: kitchenID),
            try repository.append(.alias(rawText: "TJ ORG BABY SPNC", itemID: observation.itemID),
                                  kitchenID: kitchenID),
            try repository.append(.alias(rawText: "TJ BAG FEE", itemID: nil), kitchenID: kitchenID),
            try repository.append(.name(observation.itemID, "Ginger kombucha"),
                                  kitchenID: kitchenID),
            try repository.append(.delete(item.listItemID), kitchenID: kitchenID),
        ]
        XCTAssertEqual(try repository.unpushedOps(), appended,
                       "every op kind round-trips through storage unchanged")
        XCTAssertEqual(try repository.shops(), [shop])
        XCTAssertEqual(try repository.aisleOrder(for: shop.id), order)
        XCTAssertEqual(try repository.priceObservations().count, 1)
        XCTAssertEqual(try repository.itemNames(), [observation.itemID: "Ginger kombucha"])
        try assertRebuildEquivalent(database, repository)
    }

    func testItemNamesSurviveRebuildAndAreExactlyCoresProjection() throws {
        let (database, repository) = try makeStack()
        let kombucha = ItemID()
        let kefir = ItemID()
        // The receipt-resolver shape: a minted id gets an alias, a price and a name together.
        try repository.append(.name(kombucha, " Ginger  kombucha "), kitchenID: kitchenID)
        try repository.append(.alias(rawText: "TJ GNGR KMB", itemID: kombucha),
                              kitchenID: kitchenID)
        try repository.append(.price(PriceObservation(itemID: kombucha, shopID: ShopID(),
                                                      date: Date(msSince1970: 1_000),
                                                      amount: Money(minorUnits: 399),
                                                      source: .receipt)),
                              kitchenID: kitchenID)
        try repository.append(.name(kefir, "Kefir"), kitchenID: kitchenID)
        try repository.append(.name(kombucha, "   "), kitchenID: kitchenID)

        XCTAssertEqual(try repository.itemNames(),
                       [kombucha: "Ginger kombucha", kefir: "Kefir"],
                       "names are cleaned, and a blank never erases the one the kitchen has")
        try assertRebuildEquivalent(database, repository)
        let state = Merge.apply(try allOps(database), to: ListState())
        XCTAssertEqual(try repository.itemNames(), state.itemNames,
                       "the item_name table is exactly Core's projection")
    }

    func testANameArrivingLateDoesNotOverwriteTheNewerOne() throws {
        let (database, repository) = try makeStack()
        let itemID = ItemID()
        try repository.append(.name(itemID, "Ginger kombucha"), kitchenID: kitchenID)

        let stale = Op(kitchenID: kitchenID, deviceID: DeviceID(), clock: 1,
                       wallClock: Date(msSince1970: 1_000), kind: .name(itemID, "Kombucha"))
        try repository.applyRemote([stale], cursor: 1, kitchenID: kitchenID)
        XCTAssertEqual(try repository.itemNames()[itemID], "Ginger kombucha",
                       "an older name arriving late loses LWW, in the table as well as in Core")

        let newer = Op(kitchenID: kitchenID, deviceID: DeviceID(), clock: 99,
                       wallClock: Date(msSince1970: 9_000_000),
                       kind: .name(itemID, "Ginger kombucha 1L"))
        try repository.applyRemote([newer], cursor: 2, kitchenID: kitchenID)
        XCTAssertEqual(try repository.itemNames()[itemID], "Ginger kombucha 1L")
        XCTAssertEqual(try repository.itemNames().count, 1, "one item, one name")
        try assertRebuildEquivalent(database, repository)
    }

    // FIX 4's shape again: naming one item must not rewrite the table.
    func testNameProjectionIsIncrementalNotARewrite() throws {
        let (database, repository) = try makeStack()
        try repository.append(.name(ItemID(), "Kombucha"), kitchenID: kitchenID)
        try repository.append(.name(ItemID(), "Kefir"), kitchenID: kitchenID)
        try database.pool.write { try $0.execute(sql: "UPDATE item_name SET rowid = rowid + 500") }
        let before = try nameRows(database)
        XCTAssertEqual(before.count, 2)

        try repository.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)
        XCTAssertEqual(try nameRows(database), before, "an unrelated op leaves item_name alone")

        try repository.append(.name(ItemID(), "Labneh"), kitchenID: kitchenID)
        let after = try nameRows(database)
        XCTAssertEqual(after.count, 3)
        XCTAssertEqual(Array(after.prefix(2)), before, "a new name upserts one key, not the table")
        try assertRebuildEquivalent(database, repository)
    }

    // A kitchen shops in one currency: the price book must never take another one locally.
    func testAPriceInAnotherCurrencyIsRefusedLocallyAndAcceptedFromAPeer() throws {
        let (database, repository) = try makeStack()
        let kitchen = Kitchen(id: kitchenID, name: "Cocina", currencyCode: "MXN")
        try repository.saveKitchen(kitchen)
        XCTAssertEqual(try repository.kitchens().first?.currencyCode, "MXN")

        let foreign = PriceObservation(itemID: ItemID(), shopID: ShopID(), date: Date(),
                                       amount: Money(minorUnits: 350, currencyCode: "USD"),
                                       source: .typed)
        XCTAssertThrowsError(try repository.append(.price(foreign), kitchenID: kitchenID)) { error in
            guard let dataError = error as? DataError,
                  case .currencyMismatch(let kitchenCode, let written) = dataError else {
                return XCTFail("expected a currency mismatch, got \(error)")
            }
            XCTAssertEqual(kitchenCode, "MXN")
            XCTAssertEqual(written, "USD")
        }
        XCTAssertTrue(try repository.priceObservations().isEmpty,
                      "a refused price writes no op and no row — the total stays in one currency")

        let native = PriceObservation(itemID: ItemID(), shopID: ShopID(), date: Date(),
                                      amount: Money(minorUnits: 4_500, currencyCode: "MXN"),
                                      source: .typed)
        XCTAssertNoThrow(try repository.append(.price(native), kitchenID: kitchenID))

        // A peer's op is already truth: refusing it here would break convergence, not protect it.
        let remote = Op(kitchenID: kitchenID, deviceID: DeviceID(), clock: 99,
                        wallClock: Date(msSince1970: 9_000_000), kind: .price(foreign))
        try repository.applyRemote([remote], cursor: 1, kitchenID: kitchenID)
        XCTAssertEqual(try repository.priceObservations().count, 2,
                       "the log is the truth; it is the local write path that guards it")
        try assertRebuildEquivalent(database, repository)
    }

    func testAWholeReceiptIsRefusedIfOneLineIsInAnotherCurrency() throws {
        let (database, repository) = try makeStack()
        try repository.saveKitchen(Kitchen(id: kitchenID, name: "Cocina", currencyCode: "MXN"))
        let scan = try repository.enqueueScan(jpeg: Foundation.Data([0xFF, 0xD8, 0xFF]))
        let itemID = ItemID()
        let shopID = ShopID()
        let ops: [Op.Kind] = [
            .name(itemID, "Kombucha"),
            .price(PriceObservation(itemID: itemID, shopID: shopID, date: Date(),
                                    amount: Money(minorUnits: 4_500, currencyCode: "MXN"),
                                    source: .receipt)),
            .price(PriceObservation(itemID: ItemID(), shopID: shopID, date: Date(),
                                    amount: Money(minorUnits: 350, currencyCode: "USD"),
                                    source: .receipt)),
        ]
        XCTAssertThrowsError(try repository.commitScan(scan.id, shopID: shopID, lineCount: 2,
                                                       totalMinor: 4_850, recordedMinor: 4_500,
                                                       ops: ops, kitchenID: kitchenID))
        XCTAssertTrue(try repository.priceObservations().isEmpty)
        XCTAssertTrue(try repository.itemNames().isEmpty,
                      "all of it or none of it: the good lines roll back with the bad one")
        XCTAssertEqual(try repository.pendingScans().map(\.id), [scan.id],
                       "and the photo is still there to retry")
        try assertRebuildEquivalent(database, repository)
    }

    private func nameRows(_ database: AppDatabase) throws -> [Row] {
        try database.pool.read { db in
            try Row.fetchAll(db, sql: "SELECT rowid, * FROM item_name ORDER BY rowid")
        }
    }

    func testReAddAfterDeleteResurrects() throws {
        let (database, repository) = try makeStack()
        let first = ListItem(name: "Milk")
        try repository.append(.add(first), kitchenID: kitchenID)
        try repository.append(.check(first.listItemID), kitchenID: kitchenID)
        try repository.append(.delete(first.listItemID), kitchenID: kitchenID)
        let again = ListItem(name: " milk ")
        try repository.append(.add(again), kitchenID: kitchenID)
        let items = try repository.items()
        XCTAssertEqual(items.map(\.name), ["milk"], "a later add of a deleted name resurrects")
        XCTAssertEqual(items.first?.listItemID, again.listItemID)
        XCTAssertEqual(items.first?.checked, false, "a re-added item arrives unchecked")
        try assertRebuildEquivalent(database, repository)
    }

    func testRenameCollisionCollapsesToOneRow() throws {
        let (database, repository) = try makeStack()
        let bread = ListItem(name: "Bread")
        let milk = ListItem(name: "Milk")
        try repository.append(.add(bread), kitchenID: kitchenID)
        try repository.append(.add(milk), kitchenID: kitchenID)
        try repository.append(.edit(milk.listItemID, [.note("2%")]), kitchenID: kitchenID)
        try repository.append(.edit(bread.listItemID, [.name("Milk")]), kitchenID: kitchenID)
        let items = try repository.items()
        XCTAssertEqual(items.map(\.name), ["Milk"], "renaming into an existing name is one row")
        XCTAssertEqual(items.first?.listItemID, bread.listItemID, "earlier createdAt keeps identity")
        XCTAssertEqual(items.first?.note, "2%", "fields from both rows merge into the collapsed row")
        try assertRebuildEquivalent(database, repository)
    }

    func testDeletingACrossDeviceTwinHoldsThroughRebuild() throws {
        let (_, remote) = try makeStack()
        let (database, repository) = try makeStack()
        let mine = ListItem(name: "Bread", createdAt: Date(msSince1970: 10_000))
        let theirs = ListItem(name: " bread ", createdAt: Date(msSince1970: 20_000))
        try repository.append(.add(mine), kitchenID: kitchenID)
        try remote.append(.add(theirs), kitchenID: kitchenID)
        let theirOps = try remote.unpushedOps()
        try repository.applyRemote(theirOps, cursor: 1, kitchenID: kitchenID)
        XCTAssertEqual(try repository.items().map(\.listItemID), [mine.listItemID],
                       "the twin collapses into the canonical row")
        try assertRebuildEquivalent(database, repository)

        try repository.append(.delete(mine.listItemID), kitchenID: kitchenID)
        XCTAssertTrue(try repository.items().isEmpty, "one delete removes the twin too")
        try assertRebuildEquivalent(database, repository)

        let again = ListItem(name: "Bread", createdAt: Date(msSince1970: 900_000))
        try repository.append(.add(again), kitchenID: kitchenID)
        XCTAssertEqual(try repository.items().map(\.listItemID), [again.listItemID],
                       "a later add of the swept name resurrects it")
        try assertRebuildEquivalent(database, repository)

        let everyOp = try allOps(database)
        let state = Merge.apply(everyOp, to: ListState())
        XCTAssertEqual(try repository.items(), state.items.map(stripped),
                       "the materialized list is exactly Core's projection")
    }

    func testDuplicatePriceLinesBothSurvive() throws {
        let (database, repository) = try makeStack()
        let observation = PriceObservation(itemID: ItemID(), shopID: ShopID(), date: Date(),
                                           amount: Money(minorUnits: 379), source: .receipt)
        try repository.append(.price(observation), kitchenID: kitchenID)
        try repository.append(.price(observation), kitchenID: kitchenID)
        XCTAssertEqual(try repository.priceObservations().count, 2,
                       "two identical receipt lines are two observations")
        try assertRebuildEquivalent(database, repository)
    }

    func testNormalizedNameGroupingMatchesCore() throws {
        let (database, repository) = try makeStack()
        try repository.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)
        try repository.append(.add(ListItem(name: "  milk ")), kitchenID: kitchenID)
        try repository.append(.add(ListItem(name: "MILK")), kitchenID: kitchenID)
        try repository.append(.add(ListItem(name: "Bread")), kitchenID: kitchenID)
        let items = try repository.items()
        XCTAssertEqual(items.count, 2)
        let normalized = try database.pool.read { db in
            try String.fetchAll(db, sql: "SELECT normalized_name FROM list_item")
        }
        XCTAssertEqual(normalized.count, Set(normalized).count,
                       "materialized normalized names are unique")
        let state = Merge.apply(try repository.unpushedOps(), to: ListState())
        XCTAssertEqual(items, state.items.map(stripped),
                       "the materialized list is exactly Core's projection")
        try assertRebuildEquivalent(database, repository)
    }

    func testAliasCorrectionAndIgnoreSurviveRebuild() throws {
        let (database, repository) = try makeStack()
        let spinach = ItemID()
        let kale = ItemID()
        try repository.append(.alias(rawText: "TJ ORG BABY SPNC", itemID: spinach),
                              kitchenID: kitchenID)
        try repository.append(.alias(rawText: " tj org  baby spnc ", itemID: kale),
                              kitchenID: kitchenID)
        try repository.append(.alias(rawText: "TJ BAG FEE", itemID: nil), kitchenID: kitchenID)

        let aliases = try repository.aliases()
        XCTAssertEqual(aliases.count, 2, "case and spacing variants are one alias")
        XCTAssertEqual(aliases["tj org baby spnc"], .some(.some(kale)), "the correction wins")
        let ignored: ItemID?? = .some(nil)
        XCTAssertEqual(aliases["tj bag fee"], ignored, "aliased-to-nil is ignore forever")
        XCTAssertNil(aliases["sfy 2% milk gal"], "a never-aliased line has no row")

        try assertRebuildEquivalent(database, repository)
        let state = Merge.apply(try allOps(database), to: ListState())
        XCTAssertEqual(try repository.aliases(), state.aliases,
                       "the alias table is exactly Core's projection")
    }

    func testAliasKeyFoldsReceiptPunctuationThroughStorage() throws {
        let (database, repository) = try makeStack()
        let spinach = ItemID()
        let kale = ItemID()
        try repository.append(.alias(rawText: "TJ*ORG BABY SPNC", itemID: spinach),
                              kitchenID: kitchenID)
        try repository.append(.alias(rawText: "TJ-ORG  BABY SPNC.", itemID: kale),
                              kitchenID: kitchenID)
        try repository.append(.alias(rawText: "MILK 2% #4021", itemID: ItemID()),
                              kitchenID: kitchenID)

        let aliases = try repository.aliases()
        XCTAssertEqual(aliases.count, 2, "the same product printed two ways is one alias row")
        XCTAssertEqual(aliases["tj org baby spnc"], .some(.some(kale)), "the correction wins")
        XCTAssertNotNil(aliases["milk 2% 4021"], "% survives the fold; # does not")
        try assertRebuildEquivalent(database, repository)
    }

    func testAnEmptyAliasKeyWritesNoRow() throws {
        let (database, repository) = try makeStack()
        try repository.append(.alias(rawText: "   ", itemID: ItemID()), kitchenID: kitchenID)
        try repository.append(.alias(rawText: "*** ///", itemID: nil), kitchenID: kitchenID)

        XCTAssertTrue(try repository.aliases().isEmpty,
                      "an alias that would match every blank line never reaches the projection")
        XCTAssertEqual(try allOps(database).map(\.type), ["alias", "alias"],
                       "the op is still in the log — it is the merge that drops it")
        try assertRebuildEquivalent(database, repository)
    }

    // FIX 4: a check-off must not rewrite the alias table it never touched.
    func testAliasProjectionIsIncrementalNotARewrite() throws {
        let (database, repository) = try makeStack()
        let item = ListItem(name: "Milk")
        try repository.append(.add(item), kitchenID: kitchenID)
        try repository.append(.alias(rawText: "TJ*ORG BABY SPNC", itemID: ItemID()),
                              kitchenID: kitchenID)
        try repository.append(.alias(rawText: "TJ BAG FEE", itemID: nil), kitchenID: kitchenID)

        // Sentinel rowids: any DELETE + re-insert of the table would lose them.
        try database.pool.write { try $0.execute(sql: "UPDATE alias SET rowid = rowid + 500") }
        let before = try aliasRows(database)
        XCTAssertEqual(before.count, 2)

        try repository.append(.check(item.listItemID), kitchenID: kitchenID)
        XCTAssertEqual(try aliasRows(database), before, "a check-off leaves the alias table alone")
        try repository.append(.edit(item.listItemID, [.quantity(2)]), kitchenID: kitchenID)
        XCTAssertEqual(try aliasRows(database), before, "and so does any other non-alias op")

        try repository.append(.alias(rawText: "BREAD/WHT", itemID: ItemID()), kitchenID: kitchenID)
        let after = try aliasRows(database)
        XCTAssertEqual(after.count, 3)
        XCTAssertEqual(Array(after.prefix(2)), before, "a new alias upserts one key, not the table")
        try assertRebuildEquivalent(database, repository)
    }

    func testRemoteAliasesResolveByStampNotByArrival() throws {
        let (database, repository) = try makeStack()
        let spinach = ItemID()
        let kale = ItemID()
        let chard = ItemID()
        try repository.append(.alias(rawText: "TJ*ORG BABY SPNC", itemID: kale),
                              kitchenID: kitchenID)

        let stale = Op(kitchenID: kitchenID, deviceID: DeviceID(), clock: 1,
                       wallClock: Date(msSince1970: 1_000),
                       kind: .alias(rawText: "TJ ORG BABY SPNC", itemID: spinach))
        try repository.applyRemote([stale], cursor: 1, kitchenID: kitchenID)
        XCTAssertEqual(try repository.aliases()["tj org baby spnc"], .some(.some(kale)),
                       "an older alias arriving late does not overwrite the newer one")

        let newer = Op(kitchenID: kitchenID, deviceID: DeviceID(), clock: 99,
                       wallClock: Date(msSince1970: 9_000_000),
                       kind: .alias(rawText: "TJ-ORG BABY SPNC.", itemID: chard))
        try repository.applyRemote([newer], cursor: 2, kitchenID: kitchenID)
        XCTAssertEqual(try repository.aliases()["tj org baby spnc"], .some(.some(chard)),
                       "a newer one does, without a full-table rewrite")
        XCTAssertEqual(try repository.aliases().count, 1, "all three are the same printed line")

        try assertRebuildEquivalent(database, repository)
        let state = Merge.apply(try allOps(database), to: ListState())
        XCTAssertEqual(try repository.aliases(), state.aliases,
                       "the incrementally-maintained alias table is exactly Core's projection")
    }

    func testPendingScanLifecycleAndPhotoDeletion() throws {
        let (database, repository) = try makeStack()
        let scan = try repository.enqueueScan(jpeg: Foundation.Data([0xFF, 0xD8, 0xFF]),
                                              capturedAt: Date(msSince1970: 1_000))
        XCTAssertNil(scan.shopID, "the shop is resolved at review, not at capture")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scan.photoPath),
                      "Data writes the photo it will later delete")
        XCTAssertTrue(scan.photoPath.hasPrefix(database.url.deletingLastPathComponent().path),
                      "the photo lands beside the database, inside the App Group container")
        XCTAssertEqual(try repository.scanPhoto(scan.id), Foundation.Data([0xFF, 0xD8, 0xFF]))

        XCTAssertEqual(try repository.queuedScans(), [scan], "a capture is queued, not parsed")
        try repository.markScan(scan.id, .parsing)
        XCTAssertTrue(try repository.queuedScans().isEmpty, "a parsing scan is off the queue")
        XCTAssertEqual(try repository.pendingScans().map(\.state), [.parsing])
        try repository.markScan(scan.id, .failed)
        XCTAssertEqual(try repository.pendingScans().map(\.state), [.failed])
        try repository.markScan(scan.id, .queued)
        XCTAssertEqual(try repository.queuedScans().map(\.id), [scan.id],
                       "a scan the app was killed mid-parse goes back in the queue")

        try repository.deleteScan(scan.id)
        XCTAssertTrue(try repository.pendingScans().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: scan.photoPath),
                       "deleting a pending scan deletes the photo it points at")
        XCTAssertNil(try repository.scanPhoto(scan.id), "and there is nothing left to read")
        XCTAssertNoThrow(try repository.deleteScan(scan.id), "deleting twice is not an error")
    }

    // RULING 5: one file, one owner — the scan's claim ends exactly where the receipt's begins.
    func testPromotingAScanTransfersThePhotoToTheReceipt() throws {
        let (_, repository) = try makeStack()
        let shopID = ShopID()
        let scan = try repository.enqueueScan(jpeg: Foundation.Data([0xFF, 0xD8]),
                                              capturedAt: Date(msSince1970: 3_000))
        let receipt = try repository.promoteScan(scan.id, shopID: shopID, lineCount: 14,
                                                 totalMinor: 8_450, recordedMinor: 7_100)

        let photoPath = try XCTUnwrap(receipt.photoPath)
        XCTAssertEqual(photoPath, scan.photoPath, "the file does not move, its owner changes")
        XCTAssertEqual(receipt.capturedAt, scan.capturedAt, "the receipt keeps the capture time")
        XCTAssertEqual(receipt.shopID, shopID, "the shop the review screen chose")
        XCTAssertTrue(try repository.pendingScans().isEmpty, "the scan no longer claims the photo")
        XCTAssertEqual(try repository.receipts(), [receipt])
        XCTAssertTrue(FileManager.default.fileExists(atPath: photoPath),
                      "and the photo survived the handover")
        XCTAssertThrowsError(try repository.promoteScan(scan.id, shopID: shopID, lineCount: 1,
                                                        totalMinor: 1, recordedMinor: 1),
                             "a scan can only be promoted once")

        try repository.deleteReceipt(receipt.id)
        XCTAssertTrue(try repository.receipts().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoPath),
                       "the receipt's owner deletes the photo when the receipt goes")
    }

    // A commit is all of it or none of it: the ops and the promotion share one transaction, so a
    // failure cannot leave two prices written, ten missing and no scan left to retry with.
    func testCommittingAScanWritesEveryOpAndTheReceiptOrNeither() throws {
        let (database, repository) = try makeStack()
        let shopID = ShopID()
        let scan = try repository.enqueueScan(jpeg: Foundation.Data([0xFF, 0xD8]),
                                              capturedAt: Date(msSince1970: 5_000))
        let kinds: [Op.Kind] = [
            .price(PriceObservation(itemID: ItemID(), shopID: shopID, date: Date(),
                                    amount: Money(minorUnits: 189), source: .receipt)),
            .alias(rawText: "BAG FEE", itemID: nil),
            .price(PriceObservation(itemID: ItemID(), shopID: shopID, date: Date(),
                                    amount: Money(minorUnits: 299), source: .receipt)),
        ]

        // The promotion runs last and fails here: everything written before it must roll back.
        XCTAssertThrowsError(try repository.commitScan(UUID(), shopID: shopID, lineCount: 3,
                                                       totalMinor: 488, recordedMinor: 488,
                                                       ops: kinds, kitchenID: kitchenID))
        XCTAssertTrue(try allOps(database).isEmpty, "no half of the commit survived")
        XCTAssertTrue(try repository.priceObservations().isEmpty)
        XCTAssertTrue(try repository.aliases().isEmpty)
        XCTAssertEqual(try repository.queuedScans().map(\.id), [scan.id],
                       "the photo is still there, so the user can commit again")

        let receipt = try repository.commitScan(scan.id, shopID: shopID, lineCount: 3,
                                                totalMinor: 488, recordedMinor: 488, ops: kinds,
                                                kitchenID: kitchenID)

        XCTAssertEqual(try allOps(database).count, 3, "the retry writes each op exactly once")
        XCTAssertEqual(try repository.priceObservations().count, 2)
        XCTAssertEqual(try repository.aliases().count, 1)
        XCTAssertEqual(try repository.receipts(), [receipt])
        XCTAssertEqual(try repository.unpushedOps().count, 3, "and all three are pushable")
        XCTAssertTrue(try repository.pendingScans().isEmpty, "the receipt owns the photo now")
        XCTAssertEqual(receipt.photoPath, scan.photoPath)
        try assertRebuildEquivalent(database, repository)
    }

    // W7 RULING 1: the till's total is what the till printed, or it is nothing. A receipt whose
    // grand total was never read stores nil — and the money it did produce is a separate number,
    // stored as ours.
    func testAReceiptWithNoPrintedTotalStoresNoTotalAtAll() throws {
        let (_, repository) = try makeStack()
        let shopID = ShopID()
        let scan = try repository.enqueueScan(jpeg: Foundation.Data([0xFF, 0xD8]))
        let kinds: [Op.Kind] = [
            .price(PriceObservation(itemID: ItemID(), shopID: shopID, date: Date(),
                                    amount: Money(minorUnits: 449), source: .receipt)),
            .price(PriceObservation(itemID: ItemID(), shopID: shopID, date: Date(),
                                    amount: Money(minorUnits: 329), source: .receipt)),
        ]

        let receipt = try repository.commitScan(scan.id, shopID: shopID, lineCount: 7,
                                                totalMinor: nil, recordedMinor: 778, ops: kinds,
                                                kitchenID: kitchenID)

        XCTAssertNil(receipt.totalMinor, "no total was printed, so none is stored as the till's")
        XCTAssertEqual(receipt.recordedMinor, 778, "what it wrote into the price book, and ours")
        let stored = try XCTUnwrap(try repository.receipts().first)
        XCTAssertNil(stored.totalMinor, "and nil survives the round trip through SQLite")
        XCTAssertEqual(stored.recordedMinor, 778)
        // A receipt that priced nothing recorded nothing — which is 0, not "unknown".
        let second = try repository.enqueueScan(jpeg: Foundation.Data([0xFF, 0xD8]))
        let empty = try repository.commitScan(second.id, shopID: shopID, lineCount: 2,
                                              totalMinor: nil, recordedMinor: 0, ops: [],
                                              kitchenID: kitchenID)
        XCTAssertEqual(empty.recordedMinor, 0)
    }

    // The pattern setPrice needs: an identity, the name that makes it readable and the price
    // land together, or the row is left exactly as it was.
    func testManyOpsInOneAppendAreAllOfItOrNoneOfIt() throws {
        let (database, repository) = try makeStack()
        try repository.saveKitchen(Kitchen(id: kitchenID, name: "Cocina", currencyCode: "EUR"))
        let item = ListItem(name: "unicorn steaks")
        try repository.append(.add(item), kitchenID: kitchenID)
        let itemID = ItemID()
        let refused: [Op.Kind] = [
            .edit(item.listItemID, [.itemID(itemID)]),
            .name(itemID, "unicorn steaks"),
            .price(PriceObservation(itemID: itemID, shopID: ShopID(), date: Date(),
                                    amount: Money(minorUnits: 479, currencyCode: "USD"),
                                    source: .manual)),
        ]

        XCTAssertThrowsError(try repository.append(refused, kitchenID: kitchenID))

        XCTAssertNil(try repository.items().first?.itemID,
                     "a refused price leaves the row no identity it never earned")
        XCTAssertTrue(try repository.itemNames().isEmpty, "and teaches the kitchen nothing")
        XCTAssertTrue(try repository.priceObservations().isEmpty)
        XCTAssertEqual(try allOps(database).map(\.type), ["add"], "not one op of the three")
        try assertRebuildEquivalent(database, repository)
    }

    func testPendingScansSurviveRebuildAndNeverBecomeOps() throws {
        let (database, repository) = try makeStack()
        let scan = try repository.enqueueScan(jpeg: Foundation.Data([0x01]), shopID: ShopID(),
                                              capturedAt: Date(msSince1970: 2_000))
        try repository.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)

        XCTAssertEqual(try allOps(database).map(\.type), ["add"],
                       "a pending scan is device state: enqueueing one writes no op")
        XCTAssertEqual(try repository.unpushedOps().count, 1, "so there is nothing extra to push")

        try repository.rebuild()
        XCTAssertEqual(try repository.queuedScans(), [scan],
                       "rebuild() replays ops only — it must not touch pending scans")
    }

    func testDuplicatePullAdvancesCursorWithoutChurn() throws {
        let (_, remote) = try makeStack()
        let (database, repository) = try makeStack()
        try remote.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)
        let ops = try remote.unpushedOps()
        try repository.applyRemote(ops, cursor: 1, kitchenID: kitchenID)

        // A sentinel rowid: any projection rewrite would recreate the row without it.
        try database.pool.write { try $0.execute(sql: "UPDATE list_item SET rowid = 100") }
        let before = try rowidSnapshot(database)

        try repository.applyRemote(ops, cursor: 2, kitchenID: kitchenID)
        XCTAssertEqual(try rowidSnapshot(database), before,
                       "a duplicate-only pull leaves projection rows untouched")
        try repository.applyRemote([], cursor: 3, kitchenID: kitchenID)
        XCTAssertEqual(try rowidSnapshot(database), before,
                       "an empty pull leaves projection rows untouched")
        XCTAssertEqual(try repository.syncCursor(kitchenID: kitchenID), 3)
        XCTAssertEqual(try repository.items().map(\.name), ["Milk"])
    }

    @MainActor
    func testObservedRefreshSeesOtherPoolWrites() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("observed-tests-\(UUID().uuidString).sqlite")
        let databaseA = try AppDatabase(url: url)
        try databaseA.migrate()
        let observed = try Repository(database: databaseA).observedItems()
        XCTAssertTrue(observed.value.isEmpty)

        // A second pool on the same file stands in for the widget process.
        let repoB = try Repository(database: try AppDatabase(url: url))
        try repoB.append(.add(ListItem(name: "Milk")), kitchenID: kitchenID)

        observed.refresh()
        XCTAssertEqual(observed.value.map(\.name), ["Milk"],
                       "refresh() re-fetches writes ValueObservation cannot see")
    }

    private func aliasRows(_ database: AppDatabase) throws -> [Row] {
        try database.pool.read { db in
            try Row.fetchAll(db, sql: "SELECT rowid, * FROM alias ORDER BY rowid")
        }
    }

    private func rowidSnapshot(_ database: AppDatabase) throws -> [String: [Row]] {
        try database.pool.read { db in
            var tables: [String: [Row]] = [:]
            for table in ["list_item", "shop", "aisle_order", "price_observation"] {
                tables[table] = try Row.fetchAll(db,
                                                 sql: "SELECT rowid, * FROM \(table) ORDER BY rowid")
            }
            return tables
        }
    }
}
