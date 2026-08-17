import Core
import Foundation
@testable import Data

/// A server that behaves like `supabase/migrations/0001_schema.sql` + `0002_rls.sql`, not like a
/// friendly stub. Everything here mirrors a line of SQL:
///
/// - `push_ops` is `ON CONFLICT (id) DO NOTHING` and returns the number INSERTED — a
///   re-delivered batch is a 200 with a smaller number, never a 409.
/// - `op_assign_seq` draws `seq` from ONE global sequence under a per-kitchen lock, so two
///   kitchens interleave in the numbers and a cursor that jumps to the global max skips ops.
/// - `op_insert`'s WITH CHECK is evaluated per row and a violation aborts the whole call
///   (403 / 42501) — nothing in the batch lands.
/// - `op_select` FILTERS: a kitchen you are not a member of is an empty answer, not an error.
///   That is what makes enumeration useless, and it is what the attack tests assert.
actor FakeSupabaseServer: SupabaseHTTP {
    struct StoredRow {
        let seq: Int64
        let id: String
        let kitchenID: UUID
        let body: String
    }

    private var memberships: [UUID: Set<UUID>] = [:]
    private var sessions: [String: UUID] = [:]
    private var rows: [StoredRow] = []
    private var knownOpIDs: Set<String> = []
    private var nextSeq: Int64 = 0
    private var pushFailures = 0
    private var pushFailureStatus = 503
    private var pushFailureCode = "53300"
    private var failedPushNumbers: Set<Int> = []
    private var shufflesPages = false

    private(set) var pushCount = 0
    private(set) var lastPushBody = ""
    private(set) var lastAPIKey: String?
    private(set) var requestedPaths: [String] = []

    // MARK: - Test setup

    func signIn(token: String, userID: UUID) {
        sessions[token] = userID
    }

    func addMember(_ userID: UUID, to kitchenID: KitchenID) {
        memberships[userID, default: []].insert(kitchenID.rawValue)
    }

    /// Kicks the caller out the way `member_delete` does — their ops stop being accepted.
    func removeMember(_ userID: UUID, from kitchenID: KitchenID) {
        memberships[userID]?.remove(kitchenID.rawValue)
    }

    /// The status matters, not just the failure: since W10-P1 a refused push is quarantined and
    /// eventually held for good, so which statuses count as "refused" is now a correctness
    /// question rather than a cosmetic one. A rate limiter must not be able to strand an edit.
    func failNextPushes(_ count: Int, status: Int = 503, code: String = "53300") {
        pushFailures = count
        pushFailureStatus = status
        pushFailureCode = code
    }

    /// Fail one specific call — how a multi-batch push lands its first batch and loses its
    /// second, which is the case idempotency exists for.
    func failPush(number: Int) {
        failedPushNumbers.insert(number)
    }

    /// PostgREST honours `order=seq.asc`; this proves the client does not DEPEND on it.
    func shufflePages(_ shuffles: Bool) {
        shufflesPages = shuffles
    }

    var storedOpIDs: [String] { rows.map(\.id) }

    func storedOpIDs(kitchen: KitchenID) -> [String] {
        rows.filter { $0.kitchenID == kitchen.rawValue }.map(\.id)
    }

    /// Lets a test insert a row for another kitchen so the two share the global sequence.
    func seed(_ ops: [Op], as userID: UUID) throws {
        for op in ops {
            memberships[userID, default: []].insert(op.kitchenID.rawValue)
            let data = try OpCoding.encoder().encode(op)
            let text = String(decoding: data, as: UTF8.self)
            insert(id: op.opID.rawValue.uuidString.lowercased(),
                   kitchenID: op.kitchenID.rawValue, body: text)
        }
    }

    // MARK: - The wire

    func send(_ request: SupabaseRequest) async throws -> SupabaseResponse {
        requestedPaths.append(request.url.path)
        lastAPIKey = request.headers["apikey"]
        // The gateway wants the anon key alongside the user's JWT; without it nothing is served.
        guard request.headers["apikey"] != nil else { return json(401, ["code": "PGRST301"]) }
        guard let header = request.headers["authorization"], header.hasPrefix("Bearer "),
              let user = sessions[String(header.dropFirst("Bearer ".count))] else {
            return json(401, ["code": "PGRST301"])
        }
        if request.url.path.hasSuffix("/rpc/push_ops") && request.method == "POST" {
            return pushOps(request.body, as: user)
        }
        if request.url.path.hasSuffix("/op") && request.method == "GET" {
            return selectOps(request.url, as: user)
        }
        return json(404, ["code": "PGRST202"])
    }

    private func pushOps(_ body: Foundation.Data?, as user: UUID) -> SupabaseResponse {
        pushCount += 1
        if pushFailures > 0 {
            pushFailures -= 1
            return json(pushFailureStatus, ["code": pushFailureCode])
        }
        if failedPushNumbers.contains(pushCount) {
            return json(503, ["code": "53300"])
        }
        guard let body else { return json(400, ["code": "22023"]) }
        lastPushBody = String(decoding: body, as: UTF8.self)
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let elements = object["p_ops"] as? [[String: Any]] else {
            return json(400, ["code": "22023"])
        }
        var parsed: [(id: String, kitchenID: UUID, body: String)] = []
        for element in elements {
            guard let id = element["id"] as? String,
                  let kitchen = element["kitchen_id"] as? String,
                  let kitchenID = UUID(uuidString: kitchen),
                  let data = try? JSONSerialization.data(withJSONObject: element,
                                                         options: [.sortedKeys]) else {
                return json(400, ["code": "22023"])
            }
            // WITH CHECK on the NEW row: addressing another kitchen aborts the transaction,
            // so not one op in this batch is written.
            guard memberships[user]?.contains(kitchenID) == true else {
                return json(403, ["code": "42501"])
            }
            parsed.append((id.lowercased(), kitchenID, String(decoding: data, as: UTF8.self)))
        }
        var inserted = 0
        for row in parsed where !knownOpIDs.contains(row.id) {
            insert(id: row.id, kitchenID: row.kitchenID, body: row.body)
            inserted += 1
        }
        return SupabaseResponse(status: 200, body: Foundation.Data("\(inserted)".utf8))
    }

    private func insert(id: String, kitchenID: UUID, body: String) {
        guard knownOpIDs.insert(id).inserted else { return }
        nextSeq += 1
        rows.append(StoredRow(seq: nextSeq, id: id, kitchenID: kitchenID, body: body))
    }

    private func selectOps(_ url: URL, as user: UUID) -> SupabaseResponse {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return json(400, ["code": "22023"])
        }
        let query = components.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        guard let filter = value("kitchen_id"), filter.hasPrefix("eq."),
              let kitchenID = UUID(uuidString: String(filter.dropFirst(3))) else {
            return json(400, ["code": "22023"])
        }
        let cursor = Int64((value("seq") ?? "gt.0").dropFirst(3)) ?? 0
        let limit = Int(value("limit") ?? "1000") ?? 1000
        // The policy filters rows; a stranger's query succeeds and returns nothing.
        guard memberships[user]?.contains(kitchenID) == true else { return ok("[]") }
        var page = rows.filter { $0.kitchenID == kitchenID && $0.seq > cursor }
            .sorted { $0.seq < $1.seq }
            .prefix(limit)
            .map { $0 }
        if shufflesPages { page.reverse() }
        let text = page.map { "{\"seq\":\($0.seq),\($0.body.dropFirst())" }.joined(separator: ",")
        return ok("[\(text)]")
    }

    private func ok(_ text: String) -> SupabaseResponse {
        SupabaseResponse(status: 200, body: Foundation.Data(text.utf8))
    }

    private func json(_ status: Int, _ body: [String: String]) -> SupabaseResponse {
        let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Foundation.Data("{}".utf8)
        return SupabaseResponse(status: status, body: data)
    }
}
