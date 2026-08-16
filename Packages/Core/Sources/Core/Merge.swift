import Foundation

// State internals are commutative maps (min/max per key), so any permutation
// of the same op set produces an identical — and Equatable-identical — state.
public struct ListState: Equatable, Sendable {
    var addRecords: [ListItemID: AddRecord] = [:]
    var fieldWrites: [ListItemID: [ListItemField: FieldSlot]] = [:]
    var deletes: [ListItemID: OpStamp] = [:]
    var priceSet: Set<PriceObservation> = []
    var shopRecords: [ShopID: Stamped<Shop>] = [:]
    var aisleRecords: [ShopID: Stamped<AisleOrder>] = [:]

    public init() {}

    // Adds collapse by normalized seed name; a tombstone on any member deletes the row.
    public var items: [ListItem] {
        var groups: [String: [(id: ListItemID, record: AddRecord)]] = [:]
        for (id, record) in addRecords {
            groups[Merge.normalized(record.seed.name), default: []].append((id, record))
        }
        var result: [ListItem] = []
        for members in groups.values {
            if members.contains(where: { deletes[$0.id] != nil }) { continue }
            let canonical = members.min { lhs, rhs in
                if lhs.record.seed.createdAt != rhs.record.seed.createdAt {
                    return lhs.record.seed.createdAt < rhs.record.seed.createdAt
                }
                if lhs.record.stamp != rhs.record.stamp { return lhs.record.stamp < rhs.record.stamp }
                return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
            }
            guard let canonical else { continue }
            var slots: [ListItemField: FieldSlot] = [:]
            for member in members {
                for write in Merge.seedWrites(member.record.seed) {
                    ListState.keep(FieldSlot(write: write, stamp: member.record.stamp), in: &slots)
                }
                for slot in fieldWrites[member.id, default: [:]].values {
                    ListState.keep(slot, in: &slots)
                }
            }
            let createdAt = members.map { $0.record.seed.createdAt }.min() ?? canonical.record.seed.createdAt
            var item = ListItem(listItemID: canonical.id, name: "", createdAt: createdAt)
            for (field, slot) in slots {
                item.apply(slot.write)
                item.updatedFields[field] = slot.stamp
            }
            result.append(item)
        }
        return result.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.listItemID.rawValue.uuidString < rhs.listItemID.rawValue.uuidString
        }
    }

    public var priceObservations: [PriceObservation] {
        priceSet.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            if lhs.itemID != rhs.itemID {
                return lhs.itemID.rawValue.uuidString < rhs.itemID.rawValue.uuidString
            }
            if lhs.shopID != rhs.shopID {
                return lhs.shopID.rawValue.uuidString < rhs.shopID.rawValue.uuidString
            }
            if lhs.amount.minorUnits != rhs.amount.minorUnits {
                return lhs.amount.minorUnits < rhs.amount.minorUnits
            }
            return lhs.source.rawValue < rhs.source.rawValue
        }
    }

    public var shops: [Shop] {
        shopRecords.values.map { $0.value }.sorted { lhs, rhs in
            if lhs.name != rhs.name { return lhs.name < rhs.name }
            return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
        }
    }

    public func aisleOrder(for shopID: ShopID) -> AisleOrder? {
        aisleRecords[shopID]?.value
    }

    private static func keep(_ slot: FieldSlot, in slots: inout [ListItemField: FieldSlot]) {
        if let existing = slots[slot.write.field], slot.stamp <= existing.stamp { return }
        slots[slot.write.field] = slot
    }
}

struct AddRecord: Equatable, Sendable {
    var seed: ListItem
    var stamp: OpStamp
}

struct FieldSlot: Equatable, Sendable {
    var write: FieldWrite
    var stamp: OpStamp
}

struct Stamped<Value: Equatable & Sendable>: Equatable, Sendable {
    var value: Value
    var stamp: OpStamp
}

public enum Merge {
    public static func apply(_ ops: [Op], to state: ListState) -> ListState {
        var next = state
        for op in ops { applyOne(op, to: &next) }
        return next
    }

    public static func apply(_ op: Op, to state: ListState) -> ListState {
        var next = state
        applyOne(op, to: &next)
        return next
    }

    // Dedup key for idempotent adds: lowercase, trimmed, whitespace collapsed.
    public static func normalized(_ name: String) -> String {
        cleaned(name).lowercased()
    }

    static func cleaned(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func seedWrites(_ seed: ListItem) -> [FieldWrite] {
        [.itemID(seed.itemID), .name(seed.name), .quantity(seed.quantity), .unit(seed.unit),
         .note(seed.note), .checked(seed.checked), .shopID(seed.shopID)]
    }

    private static func applyOne(_ op: Op, to state: inout ListState) {
        let stamp = op.stamp
        switch op.kind {
        case .add(var seed):
            seed.name = cleaned(seed.name)
            seed.updatedFields = [:]
            if let existing = state.addRecords[seed.listItemID], existing.stamp <= stamp { return }
            state.addRecords[seed.listItemID] = AddRecord(seed: seed, stamp: stamp)
        case .check(let id):
            applyWrite(.checked(true), to: id, stamp: stamp, in: &state)
        case .uncheck(let id):
            applyWrite(.checked(false), to: id, stamp: stamp, in: &state)
        case .edit(let id, let fields):
            for write in fields {
                if case .name(let name) = write {
                    applyWrite(.name(cleaned(name)), to: id, stamp: stamp, in: &state)
                } else {
                    applyWrite(write, to: id, stamp: stamp, in: &state)
                }
            }
        case .delete(let id):
            if let existing = state.deletes[id], existing <= stamp { return }
            state.deletes[id] = stamp
        case .price(let observation):
            state.priceSet.insert(observation)
        case .shop(.upsert(let shop)):
            if let existing = state.shopRecords[shop.id], stamp <= existing.stamp { return }
            state.shopRecords[shop.id] = Stamped(value: shop, stamp: stamp)
        case .shop(.aisleOrder(let order)):
            if let existing = state.aisleRecords[order.shopID], stamp <= existing.stamp { return }
            state.aisleRecords[order.shopID] = Stamped(value: order, stamp: stamp)
        }
    }

    // Writes for a not-yet-seen row are held in fieldWrites and land when its add arrives.
    private static func applyWrite(_ write: FieldWrite, to id: ListItemID, stamp: OpStamp,
                                   in state: inout ListState) {
        var slots = state.fieldWrites[id, default: [:]]
        if let existing = slots[write.field], stamp <= existing.stamp { return }
        slots[write.field] = FieldSlot(write: write, stamp: stamp)
        state.fieldWrites[id] = slots
    }
}
