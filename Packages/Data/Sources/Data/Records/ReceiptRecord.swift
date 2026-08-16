import Core
import Foundation
import GRDB

// Device-local receipt index; the photo itself stays on disk, only its path is stored.
public struct Receipt: Hashable, Sendable {
    public let id: UUID
    public let shopID: ShopID
    public let capturedAt: Date
    public let lineCount: Int
    public let totalMinor: Int
    public let photoPath: String?

    public init(id: UUID = UUID(), shopID: ShopID, capturedAt: Date, lineCount: Int,
                totalMinor: Int, photoPath: String? = nil) {
        self.id = id
        self.shopID = shopID
        self.capturedAt = capturedAt
        self.lineCount = lineCount
        self.totalMinor = totalMinor
        self.photoPath = photoPath
    }
}

// A capture whose parse is still owed. Device state, never an op: it never syncs, and the photo
// it points at never leaves this phone.
public struct PendingScan: Hashable, Sendable {
    public enum State: String, Hashable, Sendable, CaseIterable {
        case queued, parsing, failed
    }

    public let id: UUID
    public let shopID: ShopID
    public let capturedAt: Date
    public let photoPath: String
    public var state: State

    public init(id: UUID = UUID(), shopID: ShopID, capturedAt: Date, photoPath: String,
                state: State = .queued) {
        self.id = id
        self.shopID = shopID
        self.capturedAt = capturedAt
        self.photoPath = photoPath
        self.state = state
    }
}

struct ReceiptRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "receipt"

    var id: String
    var shopID: String
    var capturedAt: Int64
    var lineCount: Int
    var totalMinor: Int
    var photoPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case shopID = "shop_id"
        case capturedAt = "captured_at"
        case lineCount = "line_count"
        case totalMinor = "total_minor"
        case photoPath = "photo_path"
    }

    init(receipt: Receipt) {
        id = receipt.id.uuidString
        shopID = receipt.shopID.rawValue.uuidString
        capturedAt = receipt.capturedAt.msSince1970
        lineCount = receipt.lineCount
        totalMinor = receipt.totalMinor
        photoPath = receipt.photoPath
    }

    func receipt() throws -> Receipt {
        Receipt(id: try requireUUID(id), shopID: ShopID(try requireUUID(shopID)),
                capturedAt: Date(msSince1970: capturedAt), lineCount: lineCount,
                totalMinor: totalMinor, photoPath: photoPath)
    }
}

struct PendingScanRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "pending_scan"

    var id: String
    var shopID: String
    var capturedAt: Int64
    var photoPath: String
    var state: String

    enum CodingKeys: String, CodingKey {
        case id, state
        case shopID = "shop_id"
        case capturedAt = "captured_at"
        case photoPath = "photo_path"
    }

    init(scan: PendingScan) {
        id = scan.id.uuidString
        shopID = scan.shopID.rawValue.uuidString
        capturedAt = scan.capturedAt.msSince1970
        photoPath = scan.photoPath
        state = scan.state.rawValue
    }

    func scan() throws -> PendingScan {
        guard let parsed = PendingScan.State(rawValue: state) else { throw DataError.malformedRow }
        return PendingScan(id: try requireUUID(id), shopID: ShopID(try requireUUID(shopID)),
                           capturedAt: Date(msSince1970: capturedAt), photoPath: photoPath,
                           state: parsed)
    }
}
