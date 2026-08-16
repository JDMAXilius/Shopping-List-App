import Core
import Foundation
import GRDB

// Anonymous, stable, stored beside the data it stamps; account linking can attach to it later.
public struct DeviceIdentity: Sendable {
    public let deviceID: DeviceID
    var clock: LogicalClock

    static func load(_ db: Database) throws -> DeviceIdentity {
        if let record = try DeviceIdentityRecord.fetchOne(db) {
            return DeviceIdentity(deviceID: DeviceID(try requireUUID(record.deviceID)),
                                  clock: LogicalClock(value: UInt64(clamping: record.clock)))
        }
        let identity = DeviceIdentity(deviceID: DeviceID(), clock: LogicalClock())
        try identity.record.insert(db)
        return identity
    }

    func save(_ db: Database) throws {
        try record.save(db)
    }

    private var record: DeviceIdentityRecord {
        DeviceIdentityRecord(id: 1, deviceID: deviceID.rawValue.uuidString,
                             clock: Int64(clamping: clock.value))
    }
}

struct DeviceIdentityRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "device"

    var id: Int64
    var deviceID: String
    var clock: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case deviceID = "device_id"
        case clock
    }
}
