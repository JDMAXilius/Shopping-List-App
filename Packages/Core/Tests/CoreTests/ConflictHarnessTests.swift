import XCTest
import Core

func fixedUUID(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, byte))
}

// One simulated device: its own logical clock and a controlled wall clock.
struct SimDevice {
    let deviceID: DeviceID
    let kitchenID: KitchenID
    var clock = LogicalClock()
    var wall: Date

    init(kitchenID: KitchenID, byte: UInt8, wallStart: TimeInterval) {
        self.deviceID = DeviceID(fixedUUID(byte))
        self.kitchenID = kitchenID
        self.wall = Date(timeIntervalSince1970: wallStart)
    }

    mutating func op(_ kind: Op.Kind) -> Op {
        wall = wall.addingTimeInterval(1)
        return Op(kitchenID: kitchenID, deviceID: deviceID,
                  clock: clock.tick(), wallClock: wall, kind: kind)
    }

    mutating func receive(_ remote: Op) {
        clock.merge(remote: remote.clock)
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class ConflictHarnessTests: XCTestCase {
    // Applies both exchange orders plus two seeded shuffles; all must match.
    @discardableResult
    func assertConverges(shared: [Op], device1: [Op], device2: [Op],
                         file: StaticString = #filePath, line: UInt = #line) -> ListState {
        let base = Merge.apply(shared, to: ListState())
        let ownFirst = Merge.apply(device1 + device2, to: base)
        let remoteFirst = Merge.apply(device2 + device1, to: base)
        XCTAssertEqual(ownFirst, remoteFirst, "exchange order changed the state", file: file, line: line)
        for seed: UInt64 in [0xBA66ED, 0x5EED] {
            var generator = SeededGenerator(state: seed)
            let shuffled = (shared + device1 + device2).shuffled(using: &generator)
            let replayed = Merge.apply(shuffled, to: ListState())
            XCTAssertEqual(ownFirst, replayed, "shuffled replay changed the state", file: file, line: line)
        }
        return ownFirst
    }

    func assertNoDuplicateNames(_ state: ListState, file: StaticString = #filePath, line: UInt = #line) {
        let names = state.items.map { Merge.normalized($0.name) }
        XCTAssertEqual(Set(names).count, names.count, "duplicate rows after merge", file: file, line: line)
    }

    func testSameNameOfflineAddsCollapseToOneRow() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let bread = ListItem(name: "Bread", createdAt: Date(timeIntervalSince1970: 10))
        let opBread = a.op(.add(bread))
        b.receive(opBread)

        let milkA = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 500))
        let opMilkA = a.op(.add(milkA))
        let opCheck = a.op(.check(milkA.listItemID))
        let milkB = ListItem(name: "  milk ", quantity: 2, note: "2%",
                             createdAt: Date(timeIntervalSince1970: 600))
        let opMilkB = b.op(.add(milkB))

        let state = assertConverges(shared: [opBread], device1: [opMilkA, opCheck], device2: [opMilkB])
        assertNoDuplicateNames(state)
        XCTAssertEqual(state.items.count, 2)

        guard let milk = state.items.first(where: { Merge.normalized($0.name) == "milk" }) else {
            return XCTFail("milk row missing")
        }
        XCTAssertEqual(milk.listItemID, milkA.listItemID, "earlier createdAt keeps the row identity")
        XCTAssertEqual(milk.createdAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(milk.name, "milk")
        XCTAssertEqual(milk.quantity, 2)
        XCTAssertEqual(milk.note, "2%")
        XCTAssertTrue(milk.checked, "check on one device survives the collapse")
        XCTAssertEqual(Set(milk.updatedFields.keys), [.name, .checked],
                       "an add stamps only name and checked; seed fields are unstamped fallbacks")
    }

    func testCheckVersusDeleteRaceDeletesInBothOrders() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let eggs = ListItem(name: "Eggs", createdAt: Date(timeIntervalSince1970: 10))
        let rice = ListItem(name: "Rice", createdAt: Date(timeIntervalSince1970: 20))
        let opEggs = a.op(.add(eggs))
        let opRice = a.op(.add(rice))
        b.receive(opEggs)
        b.receive(opRice)

        let opCheck = a.op(.check(eggs.listItemID))
        let opDelete = b.op(.delete(eggs.listItemID))

        let state = assertConverges(shared: [opEggs, opRice], device1: [opCheck], device2: [opDelete])
        assertNoDuplicateNames(state)
        XCTAssertEqual(state.items.map { $0.name }, ["Rice"], "the tombstone wins the race")
    }

    func testConcurrentFieldEditsMergeWithoutLoss() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let apples = ListItem(name: "Apples", createdAt: Date(timeIntervalSince1970: 10))
        let bananas = ListItem(name: "Bananas", createdAt: Date(timeIntervalSince1970: 20))
        let shared = [a.op(.add(apples)), a.op(.add(bananas))]
        for op in shared { b.receive(op) }

        let aOps = [a.op(.edit(apples.listItemID, [.quantity(3)])),
                    a.op(.check(bananas.listItemID))]
        let bOps = [b.op(.edit(apples.listItemID, [.note("granny smith")])),
                    b.op(.edit(bananas.listItemID, [.name("Plantains")])),
                    b.op(.edit(apples.listItemID, [.quantity(6)]))]

        let state = assertConverges(shared: shared, device1: aOps, device2: bOps)
        XCTAssertEqual(state.items.count, 2)

        guard let fruit = state.items.first(where: { $0.listItemID == apples.listItemID }),
              let renamed = state.items.first(where: { $0.listItemID == bananas.listItemID }) else {
            return XCTFail("rows missing after merge")
        }
        XCTAssertEqual(fruit.quantity, 6, "later write wins the contested field")
        XCTAssertEqual(fruit.note, "granny smith", "uncontested field is never lost")
        XCTAssertEqual(renamed.name, "Plantains")
        XCTAssertTrue(renamed.checked, "check and rename merge field by field")
        XCTAssertEqual(Set(fruit.updatedFields.keys), [.name, .checked, .quantity, .note])
        XCTAssertEqual(Set(renamed.updatedFields.keys), [.name, .checked])
    }

    func testReAddAfterDeleteResurrectsUnchecked() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let milk = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 10))
        let add = a.op(.add(milk))
        let check = a.op(.check(milk.listItemID))
        b.receive(add)
        b.receive(check)

        let delete = b.op(.delete(milk.listItemID))
        a.receive(delete)
        let milkAgain = ListItem(name: " milk ", createdAt: Date(timeIntervalSince1970: 900))
        let readd = a.op(.add(milkAgain))

        let state = assertConverges(shared: [add, check], device1: [readd], device2: [delete])
        assertNoDuplicateNames(state)
        XCTAssertEqual(state.items.count, 1, "a later-stamped add of a deleted name resurrects the row")
        guard let row = state.items.first else { return XCTFail("milk row missing") }
        XCTAssertEqual(row.listItemID, milkAgain.listItemID, "the new add carries the identity")
        XCTAssertEqual(row.name, "milk")
        XCTAssertFalse(row.checked, "a re-added item arrives unchecked")
        XCTAssertEqual(row.createdAt, Date(timeIntervalSince1970: 900))
    }

    // Two devices legitimately mint two "bread" rows; the app only ever sees the canonical id.
    func testDeletingACollapsedRowRemovesTheCrossDeviceTwin() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let breadA = ListItem(name: "Bread", createdAt: Date(timeIntervalSince1970: 10))
        let addA = a.op(.add(breadA))
        let breadB = ListItem(name: " bread ", createdAt: Date(timeIntervalSince1970: 20))
        let addB = b.op(.add(breadB))

        let collapsed = Merge.apply([addA, addB], to: ListState())
        XCTAssertEqual(collapsed.items.map { $0.listItemID }, [breadA.listItemID],
                       "only the canonical id is reachable, so only it can be deleted")

        a.receive(addB)
        let delete = a.op(.delete(breadA.listItemID))
        let state = assertConverges(shared: [], device1: [addA, delete], device2: [addB])
        XCTAssertTrue(state.items.isEmpty, "one delete takes the whole name off the list")
    }

    func testLaterAddResurrectsANameAfterATwinDelete() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let breadA = ListItem(name: "Bread", createdAt: Date(timeIntervalSince1970: 10))
        let addA = a.op(.add(breadA))
        let breadB = ListItem(name: " bread ", createdAt: Date(timeIntervalSince1970: 20))
        let addB = b.op(.add(breadB))
        a.receive(addB)
        let delete = a.op(.delete(breadA.listItemID))
        b.receive(delete)
        let breadAgain = ListItem(name: "bread", createdAt: Date(timeIntervalSince1970: 900))
        let readd = b.op(.add(breadAgain))

        let state = assertConverges(shared: [], device1: [addA, delete], device2: [addB, readd])
        assertNoDuplicateNames(state)
        XCTAssertEqual(state.items.map { $0.listItemID }, [breadAgain.listItemID],
                       "a later-stamped add still brings a swept name back")
        XCTAssertEqual(state.items.first?.createdAt, Date(timeIntervalSince1970: 900))
        XCTAssertEqual(state.items.first?.checked, false, "a re-added item arrives unchecked")
    }

    func testDeleteDoesNotSweepARowRenamedIntoTheNameAfterwards() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let milk = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 10))
        let rolls = ListItem(name: "Rolls", createdAt: Date(timeIntervalSince1970: 20))
        let shared = [a.op(.add(milk)), a.op(.add(rolls))]
        for op in shared { b.receive(op) }

        let delete = a.op(.delete(milk.listItemID))
        b.receive(delete)
        let rename = b.op(.edit(rolls.listItemID, [.name("Milk")]))

        let state = assertConverges(shared: shared, device1: [delete], device2: [rename])
        assertNoDuplicateNames(state)
        XCTAssertEqual(state.items.map { $0.listItemID }, [rolls.listItemID],
                       "a rename after the delete is a new intent, not a swept twin")
        XCTAssertEqual(state.items.map { $0.name }, ["Milk"])
    }

    func testRenameIntoExistingNameShowsOneRow() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let bread = ListItem(name: "Bread", createdAt: Date(timeIntervalSince1970: 10))
        let milk = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 20))
        let shared = [a.op(.add(bread)), a.op(.add(milk))]
        for op in shared { b.receive(op) }

        let note = a.op(.edit(milk.listItemID, [.note("2%")]))
        let rename = b.op(.edit(bread.listItemID, [.name("Milk")]))

        let state = assertConverges(shared: shared, device1: [note], device2: [rename])
        assertNoDuplicateNames(state)
        XCTAssertEqual(state.items.map { $0.name }, ["Milk"], "renaming into an existing name is one row")
        guard let row = state.items.first else { return XCTFail("milk row missing") }
        XCTAssertEqual(row.listItemID, bread.listItemID, "earlier createdAt keeps the identity")
        XCTAssertEqual(row.note, "2%", "fields from both rows merge into the collapsed row")
    }

    func testRenameAwayFreesTheNameForANewAdd() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let milk = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 10))
        let add = a.op(.add(milk))
        b.receive(add)

        let rename = a.op(.edit(milk.listItemID, [.name("Almond milk")]))
        let fresh = ListItem(name: "milk", createdAt: Date(timeIntervalSince1970: 300))
        let addFresh = b.op(.add(fresh))

        let state = assertConverges(shared: [add], device1: [rename], device2: [addFresh])
        assertNoDuplicateNames(state)
        XCTAssertEqual(state.items.map { $0.name }, ["Almond milk", "milk"],
                       "an add does not merge into a row renamed away from its name")
        XCTAssertEqual(state.items.map { $0.listItemID }, [milk.listItemID, fresh.listItemID])
    }

    func testDuplicateReceiptLinesSurviveAndReplayStaysIdempotent() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        let observation = PriceObservation(itemID: ItemID(), shopID: ShopID(),
                                           date: Date(timeIntervalSince1970: 1_000),
                                           amount: Money(minorUnits: 379), source: .receipt)
        let first = a.op(.price(observation))
        let second = a.op(.price(observation))

        let state = assertConverges(shared: [], device1: [first], device2: [second])
        XCTAssertEqual(state.priceObservations, [observation, observation],
                       "two identical receipt lines are two observations")
        let replayed = Merge.apply([second, first, second], to: state)
        XCTAssertEqual(replayed, state, "replaying the same ops stays at two, never four")
    }

    func testAliasCorrectionWinsInEveryDeliveryOrder() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let spinach = ItemID()
        let kale = ItemID()
        let match = a.op(.alias(rawText: "TJ ORG BABY SPNC", itemID: spinach))
        b.receive(match)
        let correction = b.op(.alias(rawText: "  tj org  baby   spnc ", itemID: kale))

        let state = assertConverges(shared: [], device1: [match], device2: [correction])
        XCTAssertEqual(state.aliases.count, 1, "case and spacing variants are one alias")
        XCTAssertEqual(state.alias(for: "TJ ORG BABY SPNC"), .some(.some(kale)),
                       "the later stamp wins: a correction beats the match it corrects")
        XCTAssertEqual(state.aliases["tj org baby spnc"], .some(.some(kale)),
                       "the map is keyed by normalized raw text")
    }

    func testAliasToNilIsIgnoreForeverAndNotAbsence() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let spinach = ItemID()
        let match = a.op(.alias(rawText: "TJ ORG BABY SPNC", itemID: spinach))
        b.receive(match)
        let ignore = b.op(.alias(rawText: "tj org baby spnc", itemID: nil))

        let state = assertConverges(shared: [], device1: [match], device2: [ignore])
        let ignored: ItemID?? = .some(nil)
        XCTAssertEqual(state.alias(for: "TJ ORG BABY SPNC"), ignored,
                       "aliased-to-nil means ignore this line forever")
        XCTAssertTrue(state.aliases.keys.contains("tj org baby spnc"))
        XCTAssertNil(state.alias(for: "SFY 2% MILK GAL"),
                     "a line nobody aliased has no entry — absence is not 'ignore'")
    }

    func testIgnoreCanBeUndoneByALaterMatch() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let spinach = ItemID()
        let ignore = a.op(.alias(rawText: "TJ ORG BABY SPNC", itemID: nil))
        b.receive(ignore)
        let match = b.op(.alias(rawText: "TJ ORG BABY SPNC", itemID: spinach))

        let state = assertConverges(shared: [], device1: [ignore], device2: [match])
        XCTAssertEqual(state.alias(for: "tj org baby spnc"), .some(.some(spinach)),
                       "a permanent ignore is still correctable by a later match")
    }

    func testAnEmptyAliasKeyIsDroppedInEveryDeliveryOrder() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let milk = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 10))
        let shared = [a.op(.add(milk))]
        for op in shared { b.receive(op) }

        let blanks = [a.op(.alias(rawText: "", itemID: ItemID())),
                      a.op(.alias(rawText: "   ", itemID: nil)),
                      a.op(.alias(rawText: "*** ///", itemID: ItemID()))]
        let spinach = ItemID()
        let real = [b.op(.alias(rawText: "TJ*ORG BABY SPNC", itemID: spinach))]

        let state = assertConverges(shared: shared, device1: blanks, device2: real)
        XCTAssertEqual(state.aliases.keys.sorted(), ["tj org baby spnc"],
                       "an alias that would match every blank OCR line is dropped, not stored")
        XCTAssertNil(state.alias(for: ""), "a blank line is never aliased")
        XCTAssertNil(state.alias(for: "  -- "), "and neither is a line that is only punctuation")
        XCTAssertEqual(state.items.map(\.name), ["Milk"], "dropping it leaves everything else alone")
    }

    func testAliasForALineNeverSeenAgainIsHarmless() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let milk = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 10))
        let shared = [a.op(.add(milk))]
        for op in shared { b.receive(op) }

        let stray = a.op(.alias(rawText: "WGMNS SPCLTY 4711", itemID: ItemID()))
        let bOps = [b.op(.check(milk.listItemID))]

        let state = assertConverges(shared: shared, device1: [stray], device2: bOps)
        let withoutAlias = Merge.apply(shared + bOps, to: ListState())
        XCTAssertEqual(state.items, withoutAlias.items,
                       "an alias for a line no receipt repeats touches nothing else")
        XCTAssertEqual(state.aliases.count, 1, "it is still remembered, costing one map entry")
    }

    func testMixedOfflineWeekConverges() {
        let kitchenID = KitchenID()
        var a = SimDevice(kitchenID: kitchenID, byte: 0xAA, wallStart: 100)
        var b = SimDevice(kitchenID: kitchenID, byte: 0xBB, wallStart: 0)

        let bread = ListItem(name: "Bread", createdAt: Date(timeIntervalSince1970: 10))
        let milk = ListItem(name: "Milk", createdAt: Date(timeIntervalSince1970: 20))
        let shared = [a.op(.add(bread)), a.op(.add(milk))]
        for op in shared { b.receive(op) }

        let coffeeA = ListItem(name: "Coffee", createdAt: Date(timeIntervalSince1970: 200))
        let milkItemID = ItemID()
        let observation = PriceObservation(itemID: milkItemID, shopID: ShopID(),
                                           date: Date(timeIntervalSince1970: 300),
                                           amount: Money(minorUnits: 379), source: .receipt)
        let aOps = [a.op(.add(coffeeA)),
                    a.op(.check(bread.listItemID)),
                    a.op(.edit(milk.listItemID, [.quantity(2)])),
                    a.op(.price(observation))]

        let coffeeB = ListItem(name: " coffee ", quantity: 3, createdAt: Date(timeIntervalSince1970: 300))
        let cheese = ListItem(name: "Cheese", createdAt: Date(timeIntervalSince1970: 400))
        let shop = Shop(name: "Trader Joe's", wakeRadius: 200, wakeEnabled: true)
        let order = AisleOrder(shopID: shop.id, ordered: [CategoryID("produce"), CategoryID("dairy")])
        let bOps = [b.op(.add(coffeeB)),
                    b.op(.add(cheese)),
                    b.op(.delete(bread.listItemID)),
                    b.op(.shop(.upsert(shop))),
                    b.op(.shop(.aisleOrder(order)))]

        let state = assertConverges(shared: shared, device1: aOps, device2: bOps)
        assertNoDuplicateNames(state)

        XCTAssertEqual(state.items.map { Merge.normalized($0.name) }, ["milk", "coffee", "cheese"])
        guard let mergedCoffee = state.items.first(where: { Merge.normalized($0.name) == "coffee" }),
              let mergedMilk = state.items.first(where: { $0.listItemID == milk.listItemID }) else {
            return XCTFail("rows missing after merge")
        }
        XCTAssertEqual(mergedCoffee.listItemID, coffeeA.listItemID)
        XCTAssertEqual(mergedCoffee.createdAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(mergedCoffee.quantity, 3)
        XCTAssertEqual(mergedMilk.quantity, 2)
        XCTAssertEqual(state.priceObservations, [observation])
        XCTAssertEqual(state.shops, [shop])
        XCTAssertEqual(state.aisleOrder(for: shop.id), order)
    }
}
