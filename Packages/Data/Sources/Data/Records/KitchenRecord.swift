import Core
import Foundation
import GRDB

struct KitchenRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "kitchen"

    var id: String
    var name: String

    init(kitchen: Kitchen) {
        id = kitchen.id.rawValue.uuidString
        name = kitchen.name
    }

    func kitchen() throws -> Kitchen {
        Kitchen(id: KitchenID(try requireUUID(id)), name: name)
    }
}

struct MemberRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "member"

    var kitchenID: String
    var userID: String
    var role: String
    var joinedAt: Int64

    enum CodingKeys: String, CodingKey {
        case kitchenID = "kitchen_id"
        case userID = "user_id"
        case role
        case joinedAt = "joined_at"
    }

    init(member: Member, kitchenID: KitchenID) {
        self.kitchenID = kitchenID.rawValue.uuidString
        userID = member.userID.rawValue.uuidString
        role = member.role.rawValue
        joinedAt = member.joinedAt.msSince1970
    }

    func member() throws -> Member {
        guard let role = Member.Role(rawValue: role) else { throw DataError.malformedRow }
        return Member(userID: UserID(try requireUUID(userID)), role: role,
                      joinedAt: Date(msSince1970: joinedAt))
    }
}
