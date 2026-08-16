import GRDB

enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "op") { t in
                t.column("op_id", .text).primaryKey()
                t.column("kitchen_id", .text).notNull()
                t.column("device_id", .text).notNull()
                t.column("clock", .integer).notNull()
                t.column("wall_clock", .integer).notNull()
                t.column("type", .text).notNull()
                t.column("payload", .text).notNull()
                t.column("origin", .text).notNull().check { ["local", "remote"].contains($0) }
                t.column("pushed_at", .integer)
            }
            try db.create(table: "list_item") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("normalized_name", .text).notNull()
                t.column("item_id", .text)
                t.column("quantity", .double).notNull()
                t.column("unit", .text)
                t.column("note", .text)
                t.column("checked", .boolean).notNull()
                t.column("shop_id", .text)
                t.column("created_at", .integer).notNull()
                t.column("deleted", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "kitchen") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
            }
            try db.create(table: "member") { t in
                t.column("kitchen_id", .text).notNull()
                t.column("user_id", .text).notNull()
                t.column("role", .text).notNull().check { ["owner", "guest"].contains($0) }
                t.column("joined_at", .integer).notNull()
                t.primaryKey(["kitchen_id", "user_id"])
            }
            try db.create(table: "shop") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("branch", .text)
                t.column("wake_radius", .double).notNull()
                t.column("wake_enabled", .boolean).notNull()
            }
            try db.create(table: "aisle_order") { t in
                t.column("shop_id", .text).notNull()
                t.column("position", .integer).notNull()
                t.column("category_id", .text).notNull()
                t.primaryKey(["shop_id", "position"])
            }
            try db.create(table: "price_observation") { t in
                t.column("op_id", .text).primaryKey()
                t.column("item_id", .text).notNull()
                t.column("shop_id", .text).notNull()
                t.column("observed_at", .integer).notNull()
                t.column("amount_minor", .integer).notNull()
                t.column("currency", .text).notNull()
                t.column("source", .text).notNull()
            }
            try db.create(table: "receipt") { t in
                t.column("id", .text).primaryKey()
                t.column("shop_id", .text).notNull()
                t.column("captured_at", .integer).notNull()
                t.column("line_count", .integer).notNull()
                t.column("total_minor", .integer).notNull()
                // Path only — receipt photos never leave the device.
                t.column("photo_path", .text)
            }
            try db.create(table: "sync_state") { t in
                t.column("kitchen_id", .text).primaryKey()
                t.column("cursor", .integer).notNull()
            }
            try db.create(table: "device") { t in
                t.column("id", .integer).primaryKey().check { $0 == 1 }
                t.column("device_id", .text).notNull()
                t.column("clock", .integer).notNull()
            }
            try db.execute(sql: "CREATE INDEX list_item_normalized_name ON list_item(normalized_name)")
            try db.execute(sql: """
                CREATE INDEX price_observation_item_shop_date \
                ON price_observation(item_id, shop_id, observed_at)
                """)
            try db.execute(sql: "CREATE INDEX op_unpushed ON op(pushed_at) WHERE pushed_at IS NULL")
            // The widget reads this pragma cheaply, without touching the migrator.
            try db.execute(sql: "PRAGMA user_version = 1")
        }
        migrator.registerMigration("v2") { db in
            // Projection of ListState.aliases: no row = never aliased, null item_id = ignore forever.
            try db.create(table: "alias") { t in
                t.column("raw_text", .text).primaryKey()
                t.column("item_id", .text)
            }
            // Device state, never an op: a queued parse is this phone's promise, not household
            // truth, and the photo it points at stays on the phone — this table never syncs.
            try db.create(table: "pending_scan") { t in
                t.column("id", .text).primaryKey()
                t.column("shop_id", .text).notNull()
                t.column("captured_at", .integer).notNull()
                t.column("photo_path", .text).notNull()
                t.column("state", .text).notNull()
                    .check { ["queued", "parsing", "failed"].contains($0) }
            }
            try db.execute(sql: "PRAGMA user_version = 2")
        }
        migrator.registerMigration("v3") { db in
            // shop_id relaxes to NULL: the shop is resolved at review, not at capture — at the till
            // you shoot the receipt, and being asked to pick a shop first is friction and offline risk.
            try db.create(table: "pending_scan_v3") { t in
                t.column("id", .text).primaryKey()
                t.column("shop_id", .text)
                t.column("captured_at", .integer).notNull()
                t.column("photo_path", .text).notNull()
                t.column("state", .text).notNull()
                    .check { ["queued", "parsing", "failed"].contains($0) }
            }
            try db.execute(sql: """
                INSERT INTO pending_scan_v3 (id, shop_id, captured_at, photo_path, state) \
                SELECT id, shop_id, captured_at, photo_path, state FROM pending_scan
                """)
            try db.execute(sql: "DROP TABLE pending_scan")
            try db.execute(sql: "ALTER TABLE pending_scan_v3 RENAME TO pending_scan")
            try db.execute(sql: "PRAGMA user_version = \(AppDatabase.schemaVersion)")
        }
        return migrator
    }
}
