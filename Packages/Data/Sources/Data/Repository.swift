import Core
import Foundation
import GRDB
import Synchronization

// The ONLY SQL surface. Ops are the write path; materialized tables are a projection
// of Merge state, rewritten in the same transaction as every append.
public final class Repository: Sendable {
    struct MergeCache: Sendable {
        var state = ListState()
        var opCount = 0
        var aisleShopIDs: Set<ShopID> = []
    }

    private let database: AppDatabase
    private let cache: Mutex<MergeCache>

    // Requires a migrated database; seeds merge state by replaying the op log.
    public init(database: AppDatabase) throws {
        self.database = database
        cache = Mutex(try database.pool.read { try Repository.replay($0) })
    }

    // MARK: - Write path

    @discardableResult
    public func append(_ kind: Op.Kind, kitchenID: KitchenID) throws -> Op {
        try cache.withLock { cache in
            let snapshot = cache
            let (op, next) = try database.pool.write { db -> (Op, MergeCache) in
                var working = try Repository.current(snapshot, db)
                var identity = try DeviceIdentity.load(db)
                identity.clock.tick()
                let op = Op(kitchenID: kitchenID, deviceID: identity.deviceID,
                            clock: identity.clock.value, wallClock: Date(), kind: kind)
                try identity.save(db)
                let canonical = try Repository.insert(op, origin: .local, into: db)
                Repository.fold(canonical, into: &working)
                try Repository.materializePrice(canonical, db)
                try Repository.rewriteProjection(working, db)
                return (canonical, working)
            }
            cache = next
            return op
        }
    }

    // Remote ops land with origin=remote, advance the clock past theirs, and are never re-pushed.
    public func applyRemote(_ ops: [Op], cursor: Int64? = nil, kitchenID: KitchenID? = nil) throws {
        try cache.withLock { cache in
            let snapshot = cache
            cache = try database.pool.write { db -> MergeCache in
                let fresh = try ops.filter { try !Repository.exists($0.opID, db) }
                // Nothing new: advance only the cursor so ValueObservation stays quiet.
                guard !fresh.isEmpty else {
                    try Repository.saveCursor(cursor, kitchenID, db)
                    return snapshot
                }
                var working = try Repository.current(snapshot, db)
                var identity = try DeviceIdentity.load(db)
                for op in fresh {
                    identity.clock.merge(remote: op.clock)
                    let canonical = try Repository.insert(op, origin: .remote, into: db)
                    Repository.fold(canonical, into: &working)
                    try Repository.materializePrice(canonical, db)
                }
                try identity.save(db)
                try Repository.rewriteProjection(working, db)
                try Repository.saveCursor(cursor, kitchenID, db)
                return working
            }
        }
    }

    // The invariant: a full replay repopulates exactly the incrementally-maintained tables.
    public func rebuild() throws {
        try cache.withLock { cache in
            cache = try database.pool.write { db -> MergeCache in
                var fresh = MergeCache()
                try db.execute(sql: "DELETE FROM price_observation")
                for record in try OpRecord.fetchAll(db, sql: "SELECT * FROM op") {
                    let op = try OpCoding.op(from: record)
                    Repository.fold(op, into: &fresh)
                    try Repository.materializePrice(op, db)
                }
                try Repository.rewriteProjection(fresh, db)
                return fresh
            }
        }
    }

    // MARK: - Sync support

    public func unpushedOps() throws -> [Op] {
        try database.pool.read { db in
            try OpRecord.fetchAll(db, sql: """
                SELECT * FROM op WHERE origin = 'local' AND pushed_at IS NULL \
                ORDER BY clock, op_id
                """).map { try OpCoding.op(from: $0) }
        }
    }

    public func markPushed(_ ids: [OpID], at date: Date = Date()) throws {
        try database.pool.write { db in
            for id in ids {
                try db.execute(sql: "UPDATE op SET pushed_at = ? WHERE op_id = ?",
                               arguments: [date.msSince1970, id.rawValue.uuidString])
            }
        }
    }

    public func syncCursor(kitchenID: KitchenID) throws -> Int64 {
        try database.pool.read { db in
            try SyncStateRecord.fetchOne(db, key: kitchenID.rawValue.uuidString)?.cursor ?? 0
        }
    }

    public func deviceID() throws -> DeviceID {
        try database.pool.write { db in try DeviceIdentity.load(db).deviceID }
    }

    // MARK: - Reads

    public func items() throws -> [ListItem] {
        try database.pool.read { try Repository.fetchItems($0) }
    }

    public func shops() throws -> [Shop] {
        try database.pool.read { try Repository.fetchShops($0) }
    }

    public func aisleOrder(for shopID: ShopID) throws -> AisleOrder? {
        try database.pool.read { db in
            let records = try AisleOrderRecord.fetchAll(db, sql: """
                SELECT * FROM aisle_order WHERE shop_id = ? ORDER BY position
                """, arguments: [shopID.rawValue.uuidString])
            guard !records.isEmpty else { return nil }
            return AisleOrder(shopID: shopID, ordered: records.map { CategoryID($0.categoryID) })
        }
    }

    public func priceObservations() throws -> [PriceObservation] {
        try database.pool.read { try Repository.fetchPriceObservations($0) }
    }

    /// A key present with a nil value is "ignore this line forever"; a missing key is
    /// "never aliased". Read with `updateValue`/`index(forKey:)`, never `?? nil`.
    public func aliases() throws -> [String: ItemID?] {
        try database.pool.read { db in
            var result: [String: ItemID?] = [:]
            for record in try AliasRecord.fetchAll(db, sql: "SELECT * FROM alias") {
                result.updateValue(try record.itemID.map { ItemID(try requireUUID($0)) },
                                   forKey: record.rawText)
            }
            return result
        }
    }

    @MainActor public func observedItems() throws -> Observed<[ListItem]> {
        Observed(initial: try items(), database: database) { try Repository.fetchItems($0) }
    }

    @MainActor public func observedShops() throws -> Observed<[Shop]> {
        Observed(initial: try shops(), database: database) { try Repository.fetchShops($0) }
    }

    @MainActor public func observedPriceObservations() throws -> Observed<[PriceObservation]> {
        Observed(initial: try priceObservations(), database: database) {
            try Repository.fetchPriceObservations($0)
        }
    }

    // MARK: - Non-op rows (membership and receipt index are bookkeeping, not merge state)

    public func saveKitchen(_ kitchen: Kitchen) throws {
        try database.pool.write { try KitchenRecord(kitchen: kitchen).save($0) }
    }

    public func kitchens() throws -> [Kitchen] {
        try database.pool.read { db in
            try KitchenRecord.fetchAll(db, sql: "SELECT * FROM kitchen ORDER BY name, id")
                .map { try $0.kitchen() }
        }
    }

    public func saveMember(_ member: Member, kitchenID: KitchenID) throws {
        try database.pool.write { try MemberRecord(member: member, kitchenID: kitchenID).save($0) }
    }

    public func members(kitchenID: KitchenID) throws -> [Member] {
        try database.pool.read { db in
            try MemberRecord.fetchAll(db, sql: """
                SELECT * FROM member WHERE kitchen_id = ? ORDER BY joined_at, user_id
                """, arguments: [kitchenID.rawValue.uuidString]).map { try $0.member() }
        }
    }

    public func saveReceipt(_ receipt: Receipt) throws {
        try database.pool.write { try ReceiptRecord(receipt: receipt).save($0) }
    }

    public func receipts() throws -> [Receipt] {
        try database.pool.read { db in
            try ReceiptRecord.fetchAll(db, sql: "SELECT * FROM receipt ORDER BY captured_at DESC, id")
                .map { try $0.receipt() }
        }
    }

    // MARK: - Pending scans (device state, not household truth)

    // A pending scan is this phone's promise to parse a photo later: it is deliberately NOT an op,
    // so it never syncs and rebuild() never touches it. Do not "fix" that by making it one.
    public func enqueueScan(_ scan: PendingScan) throws {
        try database.pool.write { try PendingScanRecord(scan: scan).save($0) }
    }

    public func pendingScans() throws -> [PendingScan] {
        try database.pool.read { db in
            try PendingScanRecord.fetchAll(db, sql: """
                SELECT * FROM pending_scan ORDER BY captured_at, id
                """).map { try $0.scan() }
        }
    }

    public func queuedScans() throws -> [PendingScan] {
        try database.pool.read { db in
            try PendingScanRecord.fetchAll(db, sql: """
                SELECT * FROM pending_scan WHERE state = 'queued' ORDER BY captured_at, id
                """).map { try $0.scan() }
        }
    }

    // Also the way a scan left `parsing` by a killed app is put back in the queue.
    public func markScan(_ id: UUID, _ state: PendingScan.State) throws {
        try database.pool.write { db in
            try db.execute(sql: "UPDATE pending_scan SET state = ? WHERE id = ?",
                           arguments: [state.rawValue, id.uuidString])
        }
    }

    public func deleteScan(_ id: UUID) throws {
        let record = try database.pool.read { db in
            try PendingScanRecord.fetchOne(db, key: id.uuidString)
        }
        guard let record else { return }
        // Photo first: a leaked receipt image outlives the user's intent, while a row left behind
        // by a failed file delete is visible and retryable.
        if FileManager.default.fileExists(atPath: record.photoPath) {
            try FileManager.default.removeItem(atPath: record.photoPath)
        }
        try database.pool.write { db in
            try db.execute(sql: "DELETE FROM pending_scan WHERE id = ?", arguments: [id.uuidString])
        }
    }

    // MARK: - Merge plumbing

    private static func replay(_ db: Database) throws -> MergeCache {
        var cache = MergeCache()
        for record in try OpRecord.fetchAll(db, sql: "SELECT * FROM op") {
            fold(try OpCoding.op(from: record), into: &cache)
        }
        return cache
    }

    // Another process (widget, intent) may have appended since our cache was seeded.
    private static func current(_ snapshot: MergeCache, _ db: Database) throws -> MergeCache {
        let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM op") ?? 0
        return count == snapshot.opCount ? snapshot : try replay(db)
    }

    private static func fold(_ op: Op, into cache: inout MergeCache) {
        cache.state = Merge.apply(op, to: cache.state)
        cache.opCount += 1
        if case .shop(.aisleOrder(let order)) = op.kind {
            cache.aisleShopIDs.insert(order.shopID)
        }
    }

    private static func insert(_ op: Op, origin: OpRecord.Origin, into db: Database) throws -> Op {
        let record = try OpCoding.record(for: op, origin: origin)
        try record.insert(db)
        // Reading back through the stored form keeps applied state identical to replayed state.
        return try OpCoding.op(from: record)
    }

    private static func saveCursor(_ cursor: Int64?, _ kitchenID: KitchenID?, _ db: Database) throws {
        guard let cursor, let kitchenID else { return }
        try SyncStateRecord(kitchenID: kitchenID.rawValue.uuidString, cursor: cursor).save(db)
    }

    private static func exists(_ opID: OpID, _ db: Database) throws -> Bool {
        try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM op WHERE op_id = ?)",
                          arguments: [opID.rawValue.uuidString]) ?? false
    }

    private static func materializePrice(_ op: Op, _ db: Database) throws {
        guard case .price(let observation) = op.kind else { return }
        try PriceObservationRecord(opID: op.opID, observation: observation).save(db)
    }

    // Wholesale rewrite: at grocery-list scale diffing is a pessimization, and
    // equality with rebuild() holds by construction.
    private static func rewriteProjection(_ cache: MergeCache, _ db: Database) throws {
        try db.execute(sql: "DELETE FROM list_item")
        for item in cache.state.items {
            try ListItemRecord(item: item).insert(db)
        }
        try db.execute(sql: "DELETE FROM shop")
        for shop in cache.state.shops {
            try ShopRecord(shop: shop).insert(db)
        }
        try db.execute(sql: "DELETE FROM alias")
        for (rawText, itemID) in cache.state.aliases.sorted(by: { $0.key < $1.key }) {
            try AliasRecord(rawText: rawText, itemID: itemID?.rawValue.uuidString).insert(db)
        }
        try db.execute(sql: "DELETE FROM aisle_order")
        let shopIDs = cache.aisleShopIDs.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
        for shopID in shopIDs {
            guard let order = cache.state.aisleOrder(for: shopID) else { continue }
            for (position, categoryID) in order.ordered.enumerated() {
                try AisleOrderRecord(shopID: shopID.rawValue.uuidString, position: position,
                                     categoryID: categoryID.rawValue).insert(db)
            }
        }
    }

    private static func fetchItems(_ db: Database) throws -> [ListItem] {
        try ListItemRecord.fetchAll(db, sql: "SELECT * FROM list_item ORDER BY created_at, id")
            .map { try $0.listItem() }
    }

    private static func fetchShops(_ db: Database) throws -> [Shop] {
        try ShopRecord.fetchAll(db, sql: "SELECT * FROM shop ORDER BY name, id")
            .map { try $0.shop() }
    }

    private static func fetchPriceObservations(_ db: Database) throws -> [PriceObservation] {
        try PriceObservationRecord.fetchAll(db, sql: """
            SELECT * FROM price_observation ORDER BY observed_at, op_id
            """).map { try $0.observation() }
    }
}
