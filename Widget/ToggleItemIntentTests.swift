import Core
import Data
import Foundation
import XCTest

/// The wave gate: a lock-screen tick produces a valid op, and a schema this build disagrees
/// with produces nothing at all.
final class ToggleItemIntentTests: XCTestCase {
    private struct Stack {
        let url: URL
        let repository: Repository
        let kitchenID: KitchenID
    }

    private func makeStack() throws -> Stack {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("bagged.sqlite")
        let database = try AppDatabase(url: url)
        // The app migrates. Everything below this line is the widget's process.
        try database.migrate()
        let repository = try Repository(database: database)
        let kitchen = Kitchen(name: "Home")
        try repository.saveKitchen(kitchen)
        return Stack(url: url, repository: repository, kitchenID: kitchen.id)
    }

    /// A second `Repository` over the same file — the widget's own, exactly as in production.
    private func widgetAccess(_ stack: Stack) throws -> WidgetStore.Access {
        let (access, connection) = WidgetStore.connect(stack.url)
        XCTAssertNotNil(connection, "a migrated database must open")
        return access
    }

    // MARK: - The gate

    func testALockScreenTickWritesOneWellFormedCheckOp() throws {
        let stack = try makeStack()
        let item = ListItem(name: "Bananas")
        let add = try stack.repository.append(.add(item), kitchenID: stack.kitchenID)
        guard case .ready(let widget, let kitchenID) = try widgetAccess(stack) else {
            return XCTFail("a migrated database with a kitchen must be ready")
        }
        XCTAssertEqual(kitchenID, stack.kitchenID)

        try ToggleItemIntent.write(itemID: item.listItemID.rawValue.uuidString, isChecked: false,
                                   access: .ready(widget, kitchenID))

        let checks = try widget.unpushedOps().filter { $0.type == "check" }
        XCTAssertEqual(checks.count, 1, "one tick, one op")
        let op = try XCTUnwrap(checks.first)
        XCTAssertEqual(op.kind, .check(item.listItemID))
        XCTAssertEqual(op.kitchenID, stack.kitchenID)
        // This device's own identity and clock, not a fresh one minted per process.
        XCTAssertEqual(op.deviceID, try stack.repository.deviceID())
        XCTAssertGreaterThan(op.clock, add.clock)
        // Well-formed on the wire too: it is the SyncEngine's job next, and it must survive.
        let wire = try JSONDecoder().decode(Op.self, from: try JSONEncoder().encode(op))
        XCTAssertEqual(wire.kind, op.kind)
        XCTAssertEqual(wire.opID, op.opID)
        // And the app sees it: the op log is the write path, the projection follows from it.
        XCTAssertEqual(try stack.repository.items().first?.checked, true)
    }

    func testTickingACheckedRowWritesTheUncheckTheTilePromised() throws {
        let stack = try makeStack()
        let item = ListItem(name: "Oat milk", checked: true)
        try stack.repository.append(.add(item), kitchenID: stack.kitchenID)
        try ToggleItemIntent.write(itemID: item.listItemID.rawValue.uuidString, isChecked: true,
                                   access: try widgetAccess(stack))
        XCTAssertEqual(try stack.repository.items().first?.checked, false)
    }

    /// The tile may be a second behind the phone. The op written is the one the finger meant —
    /// the inverse of what was ON SCREEN — never a toggle read back from the file, which would
    /// undo somebody else's check-off instead of doing what was asked.
    func testAStaleTileStillWritesTheOpTheFingerMeant() throws {
        let stack = try makeStack()
        let item = ListItem(name: "Eggs")
        try stack.repository.append(.add(item), kitchenID: stack.kitchenID)
        let access = try widgetAccess(stack)
        // Somebody checked it off in the app after this tile rendered.
        try stack.repository.append(.check(item.listItemID), kitchenID: stack.kitchenID)

        try ToggleItemIntent.write(itemID: item.listItemID.rawValue.uuidString, isChecked: false,
                                   access: access)

        XCTAssertEqual(try stack.repository.items().first?.checked, true, "still checked, not undone")
    }

    // MARK: - The refusal

    func testASchemaMismatchWritesNothingAndMigratesNothing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("bagged.sqlite")
        // A database no app has migrated: it reads 0, and this build is on AppDatabase.schemaVersion.
        _ = try AppDatabase(url: url)

        let (access, connection) = WidgetStore.connect(url)
        guard case .needsApp = access else { return XCTFail("a version mismatch must refuse") }
        XCTAssertNil(connection, "a database the widget refuses is never held open for writing")

        XCTAssertThrowsError(try ToggleItemIntent.write(itemID: UUID().uuidString, isChecked: false,
                                                        access: access))

        let reopened = try AppDatabase(url: url)
        XCTAssertNotEqual(try reopened.installedSchemaVersion(), AppDatabase.schemaVersion,
                          "the widget migrated a database it does not own")
        // What the app finds when it finally launches: its own migration, and an empty log.
        try reopened.migrate()
        XCTAssertTrue(try Repository(database: reopened).unpushedOps().isEmpty,
                      "a refused tick left an op behind")
    }

    /// The same refusal with a perfectly good database sitting right there: the state decides,
    /// never the reachability of a file.
    func testARefusedTickLeavesAHealthyOpLogUntouched() throws {
        let stack = try makeStack()
        let item = ListItem(name: "Bread")
        try stack.repository.append(.add(item), kitchenID: stack.kitchenID)
        let before = try stack.repository.unpushedOps()

        XCTAssertThrowsError(try ToggleItemIntent.write(
            itemID: item.listItemID.rawValue.uuidString, isChecked: false, access: .needsApp))
        XCTAssertThrowsError(try ToggleItemIntent.write(
            itemID: item.listItemID.rawValue.uuidString, isChecked: false, access: .unreachable))
        XCTAssertThrowsError(try ToggleItemIntent.write(
            itemID: item.listItemID.rawValue.uuidString, isChecked: false, access: .noKitchen))

        XCTAssertEqual(try stack.repository.unpushedOps().map(\.opID), before.map(\.opID))
        XCTAssertEqual(try stack.repository.items().first?.checked, false)
    }

    func testATickOnARowThatIsGoneWritesNoGhostOp() throws {
        let stack = try makeStack()
        try stack.repository.append(.add(ListItem(name: "Butter")), kitchenID: stack.kitchenID)
        let before = try stack.repository.unpushedOps().count

        XCTAssertThrowsError(try ToggleItemIntent.write(itemID: UUID().uuidString, isChecked: false,
                                                        access: try widgetAccess(stack)))
        XCTAssertThrowsError(try ToggleItemIntent.write(itemID: "not-a-uuid", isChecked: false,
                                                        access: try widgetAccess(stack)))

        XCTAssertEqual(try stack.repository.unpushedOps().count, before)
    }
}
