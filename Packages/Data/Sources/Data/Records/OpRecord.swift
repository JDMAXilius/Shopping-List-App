import Core
import Foundation
import GRDB

public enum DataError: Error {
    case malformedOp
    case malformedRow
    case unknownScan
}

func requireUUID(_ string: String) throws -> UUID {
    guard let uuid = UUID(uuidString: string) else { throw DataError.malformedRow }
    return uuid
}

extension Date {
    // Integer milliseconds everywhere: dates round-trip exactly through storage.
    var msSince1970: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }
    init(msSince1970 milliseconds: Int64) {
        self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}

struct OpRecord: Codable, FetchableRecord, PersistableRecord {
    enum Origin: String { case local, remote }

    static let databaseTableName = "op"

    var opID: String
    var kitchenID: String
    var deviceID: String
    var clock: Int64
    var wallClock: Int64
    var type: String
    var payload: String
    var origin: String
    var pushedAt: Int64?

    enum CodingKeys: String, CodingKey {
        case opID = "op_id"
        case kitchenID = "kitchen_id"
        case deviceID = "device_id"
        case clock
        case wallClock = "wall_clock"
        case type
        case payload
        case origin
        case pushedAt = "pushed_at"
    }
}

enum OpCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.msSince1970)
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            Date(msSince1970: try decoder.singleValueContainer().decode(Int64.self))
        }
        return decoder
    }

    static func record(for op: Op, origin: OpRecord.Origin) throws -> OpRecord {
        let full = try encoder().encode(op)
        guard let object = try JSONSerialization.jsonObject(with: full) as? [String: Any],
              let payloadObject = object["payload"],
              let payload = String(
                  data: try JSONSerialization.data(
                      withJSONObject: payloadObject, options: [.fragmentsAllowed, .sortedKeys]),
                  encoding: .utf8)
        else { throw DataError.malformedOp }
        return OpRecord(
            opID: op.opID.rawValue.uuidString,
            kitchenID: op.kitchenID.rawValue.uuidString,
            deviceID: op.deviceID.rawValue.uuidString,
            clock: Int64(clamping: op.clock),
            wallClock: op.wallClock.msSince1970,
            type: op.type,
            payload: payload,
            origin: origin.rawValue,
            pushedAt: nil)
    }

    // Splice, never re-encode: the op rebuild() decodes is byte-identical to the applied one.
    static func op(from record: OpRecord) throws -> Op {
        let json = """
        {"id":"\(record.opID)","kitchen_id":"\(record.kitchenID)",\
        "device_id":"\(record.deviceID)","clock":\(record.clock),\
        "wall_clock":\(record.wallClock),"type":"\(record.type)","payload":\(record.payload)}
        """
        return try decoder().decode(Op.self, from: Foundation.Data(json.utf8))
    }
}
