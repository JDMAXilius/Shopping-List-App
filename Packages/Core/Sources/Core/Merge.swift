import Foundation

// State internals are commutative maps (min/max per key), so any permutation
// of the same op set produces an identical — and Equatable-identical — state.
public struct ListState: Equatable, Sendable {
    var addRecords: [ListItemID: AddRecord] = [:]
    var fieldWrites: [ListItemID: [ListItemField: FieldSlot]] = [:]
    var deletes: [ListItemID: OpStamp] = [:]
    var priceRecords: [OpID: PriceObservation] = [:]
    var shopRecords: [ShopID: Stamped<Shop>] = [:]
    var aisleRecords: [ShopID: Stamped<AisleOrder>] = [:]
    var aliasRecords: [String: Stamped<ItemID?>] = [:]

    public init() {}

    // Rows resolve their own fields first (LWW), then collapse by normalized RESOLVED name.
    public var items: [ListItem] {
        var groups: [String: [(id: ListItemID, record: AddRecord, slots: [ListItemField: FieldSlot])]] = [:]
        var groupTombstones: [String: OpStamp] = [:]
        for (id, record) in addRecords {
            var slots: [ListItemField: FieldSlot] = [:]
            // An add contributes only name + unchecked; its other seed fields are unstamped fallbacks.
            ListState.keep(FieldSlot(write: .name(record.seed.name), stamp: record.stamp), in: &slots)
            ListState.keep(FieldSlot(write: .checked(false), stamp: record.stamp), in: &slots)
            for slot in fieldWrites[id, default: [:]].values {
                ListState.keep(slot, in: &slots)
            }
            guard let nameSlot = slots[.name], case .name(let resolved) = nameSlot.write else { continue }
            let key = Merge.normalized(resolved)
            groups[key, default: []].append((id, record, slots))
            // A tombstone sweeps the name its row held when the delete happened, not a later rename.
            if let tombstone = deletes[id], nameSlot.stamp <= tombstone {
                groupTombstones[key] = max(groupTombstones[key] ?? tombstone, tombstone)
            }
        }
        var result: [ListItem] = []
        for (key, candidates) in groups {
            // One delete means the name is off the list: it suppresses every row that held the
            // name at or before it — twins included — while a later add still resurrects.
            let members = candidates.filter { member in
                if let tombstone = deletes[member.id], member.record.stamp <= tombstone { return false }
                if let tombstone = groupTombstones[key], let slot = member.slots[.name],
                   slot.stamp <= tombstone { return false }
                return true
            }
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
                for slot in member.slots.values {
                    ListState.keep(slot, in: &slots)
                }
            }
            let createdAt = members.map { $0.record.seed.createdAt }.min() ?? canonical.record.seed.createdAt
            // The latest add's seed fills fields nobody has written — a fallback, never a stamped write.
            let fallback = members.max { $0.record.stamp < $1.record.stamp }?.record.seed
                ?? canonical.record.seed
            var item = ListItem(listItemID: canonical.id, itemID: fallback.itemID, name: "",
                                quantity: fallback.quantity, unit: fallback.unit, note: fallback.note,
                                shopID: fallback.shopID, createdAt: createdAt)
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
        priceRecords.sorted { lhs, rhs in
            if lhs.value.date != rhs.value.date { return lhs.value.date < rhs.value.date }
            if lhs.value.itemID != rhs.value.itemID {
                return lhs.value.itemID.rawValue.uuidString < rhs.value.itemID.rawValue.uuidString
            }
            if lhs.value.shopID != rhs.value.shopID {
                return lhs.value.shopID.rawValue.uuidString < rhs.value.shopID.rawValue.uuidString
            }
            if lhs.value.amount.minorUnits != rhs.value.amount.minorUnits {
                return lhs.value.amount.minorUnits < rhs.value.amount.minorUnits
            }
            if lhs.value.amount.currencyCode != rhs.value.amount.currencyCode {
                return lhs.value.amount.currencyCode < rhs.value.amount.currencyCode
            }
            if lhs.value.source.rawValue != rhs.value.source.rawValue {
                return lhs.value.source.rawValue < rhs.value.source.rawValue
            }
            return lhs.key.rawValue.uuidString < rhs.key.rawValue.uuidString
        }.map { $0.value }
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

    /// Keyed by `Merge.aliasKey` of the raw receipt text. A present key with a nil value is "ignore
    /// this line forever"; an absent key is "never aliased" — a resolver must not collapse those two.
    public var aliases: [String: ItemID?] {
        aliasRecords.mapValues { $0.value }
    }

    /// nil = no alias for this text · .some(nil) = ignore forever · .some(.some(id)) = matched.
    public func alias(for rawText: String) -> ItemID?? {
        aliasRecords[Merge.aliasKey(rawText)].map { $0.value }
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

    // Dedup key for idempotent adds and a delete's sweep: lowercase, trimmed, collapsed.
    public static func normalized(_ name: String) -> String {
        cleaned(name).lowercased()
    }

    // Alias keys come off a till printer, where one product prints TJ*ORG BABY SPNC this week and
    // TJ ORG BABY SPNC the next: fold everything outside [a-z0-9%] to a space so it stays one key.
    public static func aliasKey(_ rawText: String) -> String {
        let space: Character = " "
        let folded = String(rawText.lowercased().map { aliasKeyKept.contains($0) ? $0 : space })
        return folded.split(separator: space).joined(separator: " ")
    }

    // % survives: "MILK 2%" and "MILK 2" are different products on the same shelf.
    private static let aliasKeyKept = Set("abcdefghijklmnopqrstuvwxyz0123456789%")

    static func cleaned(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
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
            // MAX tombstone per row; the projection widens it to that row's whole name group.
            if let existing = state.deletes[id], stamp <= existing { return }
            state.deletes[id] = stamp
        case .price(let observation):
            // Keyed by OpID: replay is idempotent, distinct same-value observations both survive.
            state.priceRecords[op.opID] = observation
        case .shop(.upsert(let shop)):
            if let existing = state.shopRecords[shop.id], stamp <= existing.stamp { return }
            state.shopRecords[shop.id] = Stamped(value: shop, stamp: stamp)
        case .shop(.aisleOrder(let order)):
            if let existing = state.aisleRecords[order.shopID], stamp <= existing.stamp { return }
            state.aisleRecords[order.shopID] = Stamped(value: order, stamp: stamp)
        case .alias(let rawText, let itemID):
            // LWW per alias key: correcting a bad match must beat the match it corrects.
            let key = aliasKey(rawText)
            // An empty key would alias every blank OCR line for good, with no screen that could
            // show or undo it. An op that cannot mean anything is dropped, never stored.
            guard !key.isEmpty else { return }
            if let existing = state.aliasRecords[key], stamp <= existing.stamp { return }
            state.aliasRecords[key] = Stamped(value: itemID, stamp: stamp)
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
