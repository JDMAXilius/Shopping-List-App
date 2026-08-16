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
        XCTAssertEqual(Set(milk.updatedFields.keys), Set(ListItemField.allCases), "no lost fields")
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
        XCTAssertEqual(Set(fruit.updatedFields.keys), Set(ListItemField.allCases))
        XCTAssertEqual(Set(renamed.updatedFields.keys), Set(ListItemField.allCases))
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
