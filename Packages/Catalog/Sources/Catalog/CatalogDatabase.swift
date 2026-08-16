import CSQLite
import Foundation

public enum CatalogError: Error, Equatable {
    case cannotOpen(String)
    case missingResource
    case sqlite(String)
}

public enum SQLiteValue: Sendable, Equatable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
}

// SQLITE_TRANSIENT tells sqlite to copy bound text before we return.
private let transientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Read-only connection to the bundled catalog. One connection per instance,
/// used single-threaded — callers create their own where needed.
public final class CatalogDatabase {
    private let handle: OpaquePointer

    public init(path: String) throws {
        var h: OpaquePointer?
        let rc = sqlite3_open_v2(path, &h, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK, let opened = h else {
            let message = h.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open \(path)"
            if let h { sqlite3_close(h) }
            throw CatalogError.cannotOpen(message)
        }
        handle = opened
    }

    public static func bundled() throws -> CatalogDatabase {
        guard let url = Bundle.module.url(forResource: "catalog.db", withExtension: nil) else {
            throw CatalogError.missingResource
        }
        return try CatalogDatabase(path: url.path)
    }

    deinit { sqlite3_close(handle) }

    /// Runs `sql` with positional bindings, returns every row as column values
    /// in SELECT order. The resolver decodes by index against fixed SELECTs.
    public func rows(_ sql: String, bind: [SQLiteValue] = []) throws -> [[SQLiteValue]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK, let prepared = stmt else {
            throw CatalogError.sqlite(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(prepared) }

        for (i, value) in bind.enumerated() {
            let index = Int32(i + 1)
            switch value {
            case .null: sqlite3_bind_null(prepared, index)
            case .integer(let v): sqlite3_bind_int64(prepared, index, v)
            case .real(let v): sqlite3_bind_double(prepared, index, v)
            case .text(let v): sqlite3_bind_text(prepared, index, v, -1, transientDestructor)
            }
        }

        var out: [[SQLiteValue]] = []
        while true {
            let rc = sqlite3_step(prepared)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else {
                throw CatalogError.sqlite(String(cString: sqlite3_errmsg(handle)))
            }
            let count = sqlite3_column_count(prepared)
            var row: [SQLiteValue] = []
            row.reserveCapacity(Int(count))
            for c in 0..<count {
                switch sqlite3_column_type(prepared, c) {
                case SQLITE_INTEGER: row.append(.integer(sqlite3_column_int64(prepared, c)))
                case SQLITE_FLOAT: row.append(.real(sqlite3_column_double(prepared, c)))
                case SQLITE_TEXT: row.append(.text(String(cString: sqlite3_column_text(prepared, c))))
                default: row.append(.null)
                }
            }
            out.append(row)
        }
        return out
    }
}

extension SQLiteValue {
    var textValue: String? {
        if case .text(let v) = self { return v }
        return nil
    }

    var integerValue: Int64? {
        if case .integer(let v) = self { return v }
        return nil
    }

    // SQLite REAL columns can surface integral values as INTEGER.
    var doubleValue: Double? {
        switch self {
        case .real(let v): return v
        case .integer(let v): return Double(v)
        default: return nil
        }
    }
}
