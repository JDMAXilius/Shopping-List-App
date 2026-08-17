import Core
import Data
import Foundation

/// Which kitchen this phone is standing in. A guest's phone has two — the one it made for
/// itself before the invite arrived and the one it joined — and only a stored choice can tell
/// them apart. `kitchens().first` is alphabetical, which after a join is a coin flip.
enum ActiveKitchen {
    static let key = "bagged.activeKitchenID"

    static func id(_ defaults: UserDefaults) -> KitchenID? {
        guard let text = defaults.string(forKey: key), let uuid = UUID(uuidString: text) else {
            return nil
        }
        return KitchenID(uuid)
    }

    static func set(_ kitchenID: KitchenID, _ defaults: UserDefaults) {
        defaults.set(kitchenID.rawValue.uuidString, forKey: key)
    }

    /// What the app should open. The stored choice when it still exists locally, otherwise the
    /// first kitchen — the same answer as before there was a choice.
    static func resolve(_ kitchens: [Kitchen], defaults: UserDefaults) -> Kitchen? {
        if let chosen = id(defaults), let match = kitchens.first(where: { $0.id == chosen }) {
            return match
        }
        return kitchens.first
    }
}

@Observable @MainActor
final class KitchenStore {
    /// What the invite button has to do first. Each case is a screen, none of them is a wizard.
    enum InviteStep: Equatable {
        case signIn      // an owner needs an account so the kitchen survives a lost phone
        case name        // "Name your kitchen" — contextual, at the first invite
        case invite      // there is a live link
        case unavailable // this build has no Supabase config: say so, don't pretend
    }

    private let repository: Repository
    private let backend: (any KitchenBackend)?
    private let defaults: UserDefaults
    private let onKitchenChange: @MainActor (KitchenID) -> Void

    private(set) var kitchen: Kitchen
    private(set) var members: [Member] = []
    private(set) var identity: KitchenIdentity?
    /// The live invite token. Held only as long as the sheet needs it — it is a bearer
    /// credential, not a piece of kitchen state, and it is never written to defaults.
    private(set) var invite: String?
    private(set) var isWorking = false
    /// One plain sentence for the person, never an error dump.
    private(set) var message: String?

    init(repository: Repository, kitchen: Kitchen, backend: (any KitchenBackend)?,
         defaults: UserDefaults = .appGroup(),
         onKitchenChange: @escaping @MainActor (KitchenID) -> Void = { _ in }) {
        self.repository = repository
        self.kitchen = kitchen
        self.backend = backend
        self.defaults = defaults
        self.onKitchenChange = onKitchenChange
        members = (try? repository.members(kitchenID: kitchen.id)) ?? []
    }

    // MARK: - Derived

    /// The kitchen has a server counterpart: someone signed in and created it, or this phone
    /// joined it. Until then it is one phone's kitchen and nothing has left the device.
    var isShared: Bool { !members.isEmpty }

    var inviteURL: URL? { invite.flatMap { KitchenLink.url(token: $0) } }

    var isGuest: Bool { identity?.isAnonymous ?? false }

    /// "3 people · 1 list". One list is a fact of v1, not a count.
    var headline: String {
        let count = max(members.count, 1)
        return "\(count) \(count == 1 ? "person" : "people") · 1 list"
    }

    // MARK: - Loading

    func load() async {
        members = (try? repository.members(kitchenID: kitchen.id)) ?? []
        guard let backend else { return }
        identity = await backend.identity()
        // Asked even when the local roster is empty: a reinstalled phone still belongs to the
        // kitchen, and treating it as unshared would create a SECOND kitchen at the next invite.
        guard identity != nil else { return }
        await refreshMembers()
        if let name = try? await backend.kitchenName(kitchenID: kitchen.id) { adopt(name) }
    }

    private func refreshMembers() async {
        guard let backend else { return }
        guard let fetched = try? await backend.members(kitchenID: kitchen.id) else { return }
        members = fetched.sorted { $0.joinedAt < $1.joinedAt }
        for member in fetched {
            try? repository.saveMember(member, kitchenID: kitchen.id)
        }
    }

    // MARK: - The owner's path

    func beginInvite() async -> InviteStep {
        message = nil
        guard let backend else { return .unavailable }
        identity = await backend.identity()
        // A member of a shared kitchen already has everything an invite needs — including a
        // guest, who may invite without ever meeting a sign-in screen.
        if isShared { return .invite }
        // Creating the kitchen is what needs an account: the kitchen has to outlive this phone.
        guard let identity, !identity.isAnonymous else { return .signIn }
        return .name
    }

    /// The contextual name step, and the moment the kitchen becomes a real thing on the server.
    @discardableResult
    func nameKitchen(_ name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let backend else {
            adopt(trimmed)
            return true
        }
        isWorking = true
        defer { isWorking = false }
        do {
            if isShared {
                try await backend.renameKitchen(kitchen.id, to: trimmed)
                adopt(trimmed)
                return true
            }
            // create_kitchen writes the kitchen AND its owner member row in one transaction:
            // there is no moment where a kitchen exists without an owner.
            let created = try await backend.createKitchen(name: trimmed)
            let shared = Kitchen(id: created, name: trimmed, currencyCode: kitchen.currencyCode)
            try repository.saveKitchen(shared)
            kitchen = shared
            ActiveKitchen.set(created, defaults)
            await refreshMembers()
            onKitchenChange(created)
            return true
        } catch {
            message = KitchenStore.sentence(for: error)
            return false
        }
    }

    /// Mints a link. Every earlier link stops working the moment this one exists — the server's
    /// trigger does it, and the sheet says so in words.
    func refreshInvite() async {
        guard let backend else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            invite = try await backend.createInvite(kitchenID: kitchen.id)
            message = nil
        } catch {
            invite = nil
            message = KitchenStore.sentence(for: error)
        }
    }

    /// The link is a bearer token: it does not stay in memory after the sheet closes.
    func forgetInvite() {
        invite = nil
    }

    // MARK: - The guest's path

    /// No account, no paywall, no entitlement check — not here and not anywhere downstream.
    /// An anonymous session IS the membership (ARCHITECTURE §7).
    @discardableResult
    func join(_ text: String) async -> Bool {
        guard let backend else {
            message = "This copy of Bagged can't open shared kitchens."
            return false
        }
        guard let token = KitchenLink.token(from: text) else {
            message = "That doesn't look like an invite link. Paste the whole link you were sent."
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            identity = try await backend.signInAnonymously()
            let joined = try await backend.join(token: token)
            let name = try? await backend.kitchenName(kitchenID: joined)
            let shared = Kitchen(id: joined, name: name ?? "Shared kitchen")
            try repository.saveKitchen(shared)
            kitchen = shared
            ActiveKitchen.set(joined, defaults)
            await refreshMembers()
            message = nil
            onKitchenChange(joined)
            return true
        } catch {
            message = KitchenStore.sentence(for: error)
            return false
        }
    }

    // MARK: - The owner's account

    func requestEmailCode(_ email: String) async -> Bool {
        guard let backend else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await backend.requestEmailCode(email.trimmingCharacters(in: .whitespaces))
            message = nil
            return true
        } catch {
            message = KitchenStore.sentence(for: error)
            return false
        }
    }

    func verifyEmailCode(_ code: String) async -> Bool {
        guard let backend else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            identity = try await backend.verifyEmailCode(
                code.trimmingCharacters(in: .whitespaces))
            message = nil
            return true
        } catch {
            message = KitchenStore.sentence(for: error)
            return false
        }
    }

    func signInWithApple(idToken: String, nonce: String) async -> Bool {
        guard let backend else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            identity = try await backend.signInWithApple(idToken: idToken, nonce: nonce)
            message = nil
            return true
        } catch {
            message = KitchenStore.sentence(for: error)
            return false
        }
    }

    func signOut() async {
        await backend?.signOut()
        identity = nil
        invite = nil
    }

    private func adopt(_ name: String) {
        guard name != kitchen.name else { return }
        let renamed = Kitchen(id: kitchen.id, name: name, currencyCode: kitchen.currencyCode)
        try? repository.saveKitchen(renamed)
        kitchen = renamed
    }

    /// Failures the user can act on, in the user's words. An invalid link and a revoked one
    /// get ONE sentence, because the server deliberately tells us the same thing about both.
    static func sentence(for error: Error) -> String {
        switch error as? KitchenError {
        case .inviteNotFound:
            return "This link has expired. A newer link replaces the old one — ask for that one."
        case .notPermitted:
            return "You're not in this kitchen any more."
        case .badCode:
            return "That code didn't match. Check it and try again."
        case .signInRequired:
            return "Sign in again to keep this kitchen on more than one phone."
        case .appleUpgradeUnsupported:
            return "This phone is already in a kitchen. Use email so it keeps its place."
        case .unreachable, .none:
            return "Couldn't reach your kitchen just now. Everything still works on this phone."
        case .malformed:
            return "Something came back wrong. Try again in a moment."
        }
    }
}
