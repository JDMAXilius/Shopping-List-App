import XCTest
import Core

final class MergeTests: XCTestCase {
    let kitchenID = KitchenID()

    func testLastWriteWinsPerField() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)
        let item = ListItem(name: "Apples", createdAt: Date(timeIntervalSince1970: 10))
        let add = a.op(.add(item))
        b.receive(add)
        let editA = a.op(.edit(item.listItemID, [.quantity(3), .note("green")]))
        let editB = b.op(.edit(item.listItemID, [.quantity(5)]))

        let forward = Merge.apply([add, editA, editB], to: ListState())
        let backward = Merge.apply([editB, editA, add], to: ListState())
        XCTAssertEqual(forward, backward)

        guard let merged = forward.items.first else { return XCTFail("row missing") }
        XCTAssertEqual(merged.quantity, 5, "higher clock wins the contested field")
        XCTAssertEqual(merged.note, "green", "untouched field survives")
    }

    func testEqualClockAndWallFallsBackToDeviceID() {
        let deviceA = DeviceID(fixedUUID(0xAA))
        let deviceB = DeviceID(fixedUUID(0xBB))
        let wall = Date(timeIntervalSince1970: 50)
        let item = ListItem(name: "Salt", createdAt: Date(timeIntervalSince1970: 10))
        let add = Op(kitchenID: kitchenID, deviceID: deviceA, clock: 1, wallClock: wall,
                     kind: .add(item))
        let editA = Op(kitchenID: kitchenID, deviceID: deviceA, clock: 5, wallClock: wall,
                       kind: .edit(item.listItemID, [.note("from A")]))
        let editB = Op(kitchenID: kitchenID, deviceID: deviceB, clock: 5, wallClock: wall,
                       kind: .edit(item.listItemID, [.note("from B")]))

        let forward = Merge.apply([add, editA, editB], to: ListState())
        let backward = Merge.apply([editB, editA, add], to: ListState())
        XCTAssertEqual(forward, backward)
        XCTAssertEqual(forward.items.first?.note, "from B", "tie breaks on deviceID, deterministically")
    }

    func testIdempotentAddCollapsesOnNormalizedName() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 100)
        let milkA = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 50))
        let milkB = ListItem(name: "  milk ", quantity: 2, createdAt: Date(timeIntervalSince1970: 80))
        let addA = a.op(.add(milkA))
        let addB = b.op(.add(milkB))

        let forward = Merge.apply([addA, addB], to: ListState())
        let backward = Merge.apply([addB, addA], to: ListState())
        XCTAssertEqual(forward, backward)

        XCTAssertEqual(forward.items.count, 1, "two offline adds of the same name are one row")
        guard let merged = forward.items.first else { return XCTFail("row missing") }
        XCTAssertEqual(merged.listItemID, milkA.listItemID, "earlier createdAt keeps the identity")
        XCTAssertEqual(merged.createdAt, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(merged.quantity, 2, "the latest add's seed fills unedited fields")
    }

    func testEditNeverResurrectsAnAcknowledgedDelete() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 100)
        let eggs = ListItem(name: "Eggs", createdAt: Date(timeIntervalSince1970: 10))
        let add = a.op(.add(eggs))
        b.receive(add)
        let delete = b.op(.delete(eggs.listItemID))
        a.receive(delete)
        let lateEdit = a.op(.edit(eggs.listItemID, [.note("still here?")]))

        let forward = Merge.apply([add, delete, lateEdit], to: ListState())
        let backward = Merge.apply([lateEdit, delete, add], to: ListState())
        XCTAssertEqual(forward, backward)
        XCTAssertTrue(forward.items.isEmpty, "a later edit resurrects nothing; the tombstone holds")
    }

    func testCheckThenUncheckResolvesByTotalOrder() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        let item = ListItem(name: "Butter", createdAt: Date(timeIntervalSince1970: 10))
        let ops = [a.op(.add(item)), a.op(.check(item.listItemID)), a.op(.uncheck(item.listItemID))]

        let forward = Merge.apply(ops, to: ListState())
        let backward = Merge.apply(ops.reversed(), to: ListState())
        XCTAssertEqual(forward, backward)
        XCTAssertEqual(forward.items.first?.checked, false, "the later uncheck wins")
    }

    func testPriceOpsAppendAndReplayIsIdempotent() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        let itemID = ItemID()
        let shopID = ShopID()
        let first = PriceObservation(itemID: itemID, shopID: shopID,
                                     date: Date(timeIntervalSince1970: 1_000),
                                     amount: Money(minorUnits: 449), source: .receipt)
        let second = PriceObservation(itemID: itemID, shopID: shopID,
                                      date: Date(timeIntervalSince1970: 2_000),
                                      amount: Money(minorUnits: 479), source: .manual)
        let ops = [a.op(.price(first)), a.op(.price(second))]

        let once = Merge.apply(ops, to: ListState())
        XCTAssertEqual(once.priceObservations, [first, second], "observations accumulate, never overwrite")
        let replayed = Merge.apply(ops, to: once)
        XCTAssertEqual(replayed, once, "replaying the same ops changes nothing")
    }

    func testShopUpsertAndAisleOrderAreLastWriteWins() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 100)
        let shopID = ShopID()
        let firstShop = Shop(id: shopID, name: "TJ")
        let renamed = Shop(id: shopID, name: "Trader Joe's", branch: "Court St")
        let order = AisleOrder(shopID: shopID, ordered: [CategoryID("produce"), CategoryID("bakery")])
        let upsertA = a.op(.shop(.upsert(firstShop)))
        b.receive(upsertA)
        let upsertB = b.op(.shop(.upsert(renamed)))
        let aisles = b.op(.shop(.aisleOrder(order)))

        let forward = Merge.apply([upsertA, upsertB, aisles], to: ListState())
        let backward = Merge.apply([aisles, upsertB, upsertA], to: ListState())
        XCTAssertEqual(forward, backward)
        XCTAssertEqual(forward.shops, [renamed])
        XCTAssertEqual(forward.aisleOrder(for: shopID), order)
    }

    func testAliasKeySurvivesReceiptPunctuation() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        let spinach = ItemID()
        let milk = ItemID()
        let bread = ItemID()
        let state = Merge.apply([a.op(.alias(rawText: "TJ*ORG BABY SPNC", itemID: spinach)),
                                 a.op(.alias(rawText: "MILK 2% #4021", itemID: milk)),
                                 a.op(.alias(rawText: "BREAD/WHT", itemID: bread))], to: ListState())

        XCTAssertEqual(state.aliases.count, 3)
        for printed in ["TJ*ORG BABY SPNC", "TJ ORG BABY SPNC", "TJ-ORG  BABY SPNC."] {
            XCTAssertEqual(state.alias(for: printed), .some(.some(spinach)),
                           "the same product, printed differently, is one alias: \(printed)")
        }
        for printed in ["MILK 2% #4021", "MILK 2%  4021", "MILK 2%,4021"] {
            XCTAssertEqual(state.alias(for: printed), .some(.some(milk)), printed)
        }
        for printed in ["BREAD/WHT", "BREAD WHT", "BREAD.WHT"] {
            XCTAssertEqual(state.alias(for: printed), .some(.some(bread)), printed)
        }
        XCTAssertNil(state.alias(for: "MILK 2 4021"), "% is part of the product, not punctuation")
        XCTAssertEqual(state.aliases.keys.sorted(),
                       ["bread wht", "milk 2% 4021", "tj org baby spnc"])
    }

    // The list's idempotent add must NOT inherit the alias key's folding.
    func testItemNameNormalizationIsUnchangedByAliasFolding() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        let slashed = ListItem(name: "Bread/Wht", createdAt: Date(timeIntervalSince1970: 10))
        let spaced = ListItem(name: "Bread Wht", createdAt: Date(timeIntervalSince1970: 20))
        let state = Merge.apply([a.op(.add(slashed)), a.op(.add(spaced))], to: ListState())

        XCTAssertEqual(state.items.map(\.name), ["Bread/Wht", "Bread Wht"],
                       "punctuation still distinguishes two item names")
        XCTAssertEqual(Merge.normalized("Bread/Wht"), "bread/wht")
    }

    // The name of an ITEM and the name of a LIST ROW are two facts, and neither is the other.
    func testNamingAnItemIsNotRenamingTheRowThatHoldsIt() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        let itemID = ItemID()
        let row = ListItem(itemID: itemID, name: "TJ ORG BABY SPNC",
                           createdAt: Date(timeIntervalSince1970: 10))
        let state = Merge.apply([a.op(.add(row)),
                                 a.op(.name(itemID, "  Organic  baby spinach ")),
                                 a.op(.edit(row.listItemID, [.name("Spinach")]))], to: ListState())

        XCTAssertEqual(state.items.map(\.name), ["Spinach"], "the row keeps its own name")
        XCTAssertEqual(state.itemName(for: itemID), "Organic baby spinach",
                       "the item keeps the kitchen's name for it, whitespace-cleaned")
        XCTAssertEqual(state.itemNames, [itemID: "Organic baby spinach"])
    }

    func testABlankNameNeverErasesTheOneTheKitchenHas() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        let itemID = ItemID()
        let state = Merge.apply([a.op(.name(itemID, "Kombucha")),
                                 a.op(.name(itemID, "   ")),
                                 a.op(.name(ItemID(), ""))], to: ListState())

        XCTAssertEqual(state.itemName(for: itemID), "Kombucha",
                       "a later blank is dropped, not stored — it would name nothing")
        XCTAssertEqual(state.itemNames.count, 1, "and a blank for a fresh id writes no entry")
    }

    func testNamesAreNotSharedBetweenItems() {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        let kombucha = ItemID()
        let kefir = ItemID()
        let state = Merge.apply([a.op(.name(kombucha, "Kombucha")),
                                 a.op(.name(kefir, "Kefir"))], to: ListState())

        XCTAssertEqual(state.itemName(for: kombucha), "Kombucha")
        XCTAssertEqual(state.itemName(for: kefir), "Kefir")
        XCTAssertNil(state.itemName(for: ItemID()), "an item nobody named has no name, not a guess")
    }

    func testOpWireFormatRoundTrips() throws {
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 0)
        let item = ListItem(name: "Oat milk", quantity: 2, unit: "L",
                            createdAt: Date(timeIntervalSince1970: 10))
        let observation = PriceObservation(itemID: ItemID(), shopID: ShopID(),
                                           date: Date(timeIntervalSince1970: 1_000),
                                           amount: Money(minorUnits: 379), source: .typed)
        let ops = [a.op(.add(item)),
                   a.op(.edit(item.listItemID, [.name("Oat Milk"), .unit(nil), .checked(true)])),
                   a.op(.price(observation)),
                   a.op(.name(ItemID(), "Trader Joe's kombucha")),
                   a.op(.delete(item.listItemID))]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        for op in ops {
            let data = try encoder.encode(op)
            let json = try XCTUnwrap(String(data: data, encoding: .utf8))
            XCTAssertTrue(json.contains("\"type\":\"\(op.type)\""), json)
            XCTAssertTrue(json.contains("\"kitchen_id\""), json)
            XCTAssertTrue(json.contains("\"payload\""), json)
            let decoded = try JSONDecoder().decode(Op.self, from: data)
            XCTAssertEqual(decoded, op, "the wire format is lossless")
        }
    }
}
