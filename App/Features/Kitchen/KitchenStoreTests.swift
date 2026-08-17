import Core
import Data
import Foundation
import XCTest

@testable import Bagged

/// A backend that answers like the SQL does: `join_kitchen` is keyed on the exact token and
/// gives ONE answer for missing and revoked, and a new invite revokes every earlier one.
actor FakeKitchenBackend: KitchenBackend {
    private(set) var calls: [String] = []
    private(set) var liveToken: String?
    private(set) var mintedTokens: [String] = []
    private var stored: KitchenIdentity?
    private var kitchens: [KitchenID: String] = [:]
    private var roster: [KitchenID: [Member]] = [:]
    private var tokenKitchen: KitchenID?
    private var failure: KitchenError?

    init(identity: KitchenIdentity? = nil) {
        stored = identity
    }

    func publish(token: String, kitchenID: KitchenID, name: String, owner: UserID) {
        liveToken = token
        mintedTokens.append(token)
        tokenKitchen = kitchenID
        kitchens[kitchenID] = name
        roster[kitchenID] = [Member(userID: owner, role: .owner, joinedAt: Date())]
    }

    func fail(with error: KitchenError?) { failure = error }

    func identity() async -> KitchenIdentity? {
        calls.append("identity")
        return stored
    }

    func signInAnonymously() async throws -> KitchenIdentity {
        calls.append("signInAnonymously")
        if let failure { throw failure }
        if let stored { return stored }
        let identity = KitchenIdentity(userID: UserID(), isAnonymous: true, email: nil)
        stored = identity
        return identity
    }

    func join(token: String) async throws -> KitchenID {
        calls.append("join")
        if let failure { throw failure }
        // The exact token or nothing: a revoked one is as unknown as one that never existed.
        guard token == liveToken, let kitchenID = tokenKitchen else {
            throw KitchenError.inviteNotFound
        }
        let me = stored ?? KitchenIdentity(userID: UserID(), isAnonymous: true, email: nil)
        stored = me
        roster[kitchenID, default: []].append(
            Member(userID: me.userID, role: .guest, joinedAt: Date()))
        return kitchenID
    }

    func createKitchen(name: String) async throws -> KitchenID {
        calls.append("createKitchen")
        if let failure { throw failure }
        guard let me = stored, !me.isAnonymous else { throw KitchenError.signInRequired }
        let kitchenID = KitchenID()
        kitchens[kitchenID] = name
        roster[kitchenID] = [Member(userID: me.userID, role: .owner, joinedAt: Date())]
        return kitchenID
    }

    func renameKitchen(_ kitchenID: KitchenID, to name: String) async throws {
        calls.append("renameKitchen")
        if let failure { throw failure }
        kitchens[kitchenID] = name
    }

    func createInvite(kitchenID: KitchenID) async throws -> String {
        calls.append("createInvite")
        if let failure { throw failure }
        let token = "tok-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        liveToken = token          // the trigger revokes every earlier token
        mintedTokens.append(token)
        tokenKitchen = kitchenID
        return token
    }

    func members(kitchenID: KitchenID) async throws -> [Member] {
        calls.append("members")
        if let failure { throw failure }
        return roster[kitchenID] ?? []
    }

    func kitchenName(kitchenID: KitchenID) async throws -> String? {
        calls.append("kitchenName")
        if let failure { throw failure }
        return kitchens[kitchenID]
    }

    func requestEmailCode(_ email: String) async throws {
        calls.append("requestEmailCode")
        if let failure { throw failure }
    }

    func verifyEmailCode(_ code: String) async throws -> KitchenIdentity {
        calls.append("verifyEmailCode")
        if let failure { throw failure }
        let identity = KitchenIdentity(userID: stored?.userID ?? UserID(), isAnonymous: false,
                                       email: "owner@example.com")
        stored = identity
        return identity
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> KitchenIdentity {
        calls.append("signInWithApple")
        if let failure { throw failure }
        let identity = KitchenIdentity(userID: UserID(), isAnonymous: false, email: nil)
        stored = identity
        return identity
    }

    func signOut() async {
        calls.append("signOut")
        stored = nil
    }
}

@MainActor
final class KitchenStoreTests: XCTestCase {
    private struct Harness {
        let store: KitchenStore
        let repository: Repository
        let backend: FakeKitchenBackend
        let defaults: UserDefaults
        let local: Kitchen
    }

    private func makeHarness(identity: KitchenIdentity? = nil) throws -> Harness {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kitchen-\(UUID().uuidString).sqlite")
        let database = try AppDatabase(url: url)
        try database.migrate()
        let repository = try Repository(database: database)
        let local = Kitchen(name: "your kitchen")
        try repository.saveKitchen(local)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "bagged.kitchen.\(UUID().uuidString)"))
        let backend = FakeKitchenBackend(identity: identity)
        let store = KitchenStore(repository: repository, kitchen: local, backend: backend,
                                 defaults: defaults)
        return Harness(store: store, repository: repository, backend: backend,
                       defaults: defaults, local: local)
    }

    // MARK: - The gate: a guest joins with no account

    func testGuestWithNoAccountReachesTheSharedKitchen() async throws {
        let harness = try makeHarness()
        let shared = KitchenID()
        await harness.backend.publish(token: "abcdefghijklmnopqrst", kitchenID: shared,
                                      name: "Flat 2B", owner: UserID())

        let joined = await harness.store.join("https://bagged.app/j/abcdefghijklmnopqrst")

        XCTAssertTrue(joined)
        XCTAssertEqual(harness.store.kitchen.id, shared)
        XCTAssertEqual(harness.store.kitchen.name, "Flat 2B")
        XCTAssertEqual(harness.store.identity?.isAnonymous, true, "no account was ever created")
        XCTAssertEqual(ActiveKitchen.id(harness.defaults), shared,
                       "the app opens the kitchen that was joined, not the alphabetical first")
        XCTAssertTrue(harness.store.isShared)

        // And the shared kitchen's ops land in the list this phone shows.
        let remote = Op(kitchenID: shared, deviceID: DeviceID(), clock: 1, wallClock: Date(),
                        kind: .add(ListItem(name: "Milk")))
        try harness.repository.applyRemote([remote], cursor: 1, kitchenID: shared)
        XCTAssertEqual(try harness.repository.items().map(\.name), ["Milk"])
    }

    func testJoiningNeverAsksForAnAccountOrAPurchase() async throws {
        let harness = try makeHarness()
        await harness.backend.publish(token: "abcdefghijklmnopqrst", kitchenID: KitchenID(),
                                      name: "Flat 2B", owner: UserID())

        _ = await harness.store.join("bagged.app/j/abcdefghijklmnopqrst")

        let calls = await harness.backend.calls
        XCTAssertFalse(calls.contains("requestEmailCode"))
        XCTAssertFalse(calls.contains("verifyEmailCode"))
        XCTAssertFalse(calls.contains("signInWithApple"))
        XCTAssertFalse(calls.contains("createKitchen"))
        XCTAssertEqual(calls.first, "signInAnonymously", "the session IS the membership")
    }

    /// Missing and revoked are one answer, in the UI as on the server.
    func testARevokedLinkAndAnUnknownLinkReadTheSame() async throws {
        let harness = try makeHarness()
        await harness.backend.publish(token: "abcdefghijklmnopqrst", kitchenID: KitchenID(),
                                      name: "Flat 2B", owner: UserID())

        let unknown = await harness.store.join("https://bagged.app/j/zzzzzzzzzzzzzzzzzzzz")
        XCTAssertFalse(unknown)
        let first = harness.store.message

        await harness.backend.fail(with: .inviteNotFound)
        let revoked = await harness.store.join("https://bagged.app/j/abcdefghijklmnopqrst")
        XCTAssertFalse(revoked)
        XCTAssertEqual(first, harness.store.message)
        XCTAssertEqual(harness.store.kitchen.id, harness.local.id, "nothing changed hands")
        XCTAssertNil(ActiveKitchen.id(harness.defaults))
    }

    func testJunkNeverReachesTheServer() async throws {
        let harness = try makeHarness()
        let joined = await harness.store.join("what is this")
        XCTAssertFalse(joined)
        let calls = await harness.backend.calls
        XCTAssertTrue(calls.isEmpty, "a token-shaped string is the only thing worth spending")
    }

    // MARK: - Paywall the owner, never the joiner

    func testOnlyTheOwnerMeetsSignIn() async throws {
        let solo = try makeHarness()
        let step = await solo.store.beginInvite()
        XCTAssertEqual(step, .signIn, "the kitchen must outlive this phone before it is shared")

        let guest = try makeHarness()
        await guest.backend.publish(token: "abcdefghijklmnopqrst", kitchenID: KitchenID(),
                                    name: "Flat 2B", owner: UserID())
        _ = await guest.store.join("https://bagged.app/j/abcdefghijklmnopqrst")
        let guestStep = await guest.store.beginInvite()
        XCTAssertEqual(guestStep, .invite, "a guest invites without ever meeting sign-in")
    }

    func testASignedInOwnerIsAskedForANameNotAWizard() async throws {
        let harness = try makeHarness(
            identity: KitchenIdentity(userID: UserID(), isAnonymous: false, email: "a@b.c"))
        let step = await harness.store.beginInvite()
        XCTAssertEqual(step, .name)

        let named = await harness.store.nameKitchen("Flat 2B")
        XCTAssertTrue(named)
        XCTAssertEqual(harness.store.kitchen.name, "Flat 2B")
        XCTAssertTrue(harness.store.isShared, "create_kitchen wrote the owner's member row too")
        XCTAssertEqual(ActiveKitchen.id(harness.defaults), harness.store.kitchen.id)
    }

    func testANewLinkReplacesTheOldOne() async throws {
        let harness = try makeHarness(
            identity: KitchenIdentity(userID: UserID(), isAnonymous: false, email: "a@b.c"))
        _ = await harness.store.nameKitchen("Flat 2B")

        await harness.store.refreshInvite()
        let first = try XCTUnwrap(harness.store.invite)
        await harness.store.refreshInvite()
        let second = try XCTUnwrap(harness.store.invite)

        XCTAssertNotEqual(first, second)
        let live = await harness.backend.liveToken
        XCTAssertEqual(live, second, "the older link is not live any more")
        XCTAssertEqual(harness.store.inviteURL?.absoluteString, "https://bagged.app/j/\(second)")
    }

    func testTheLinkIsForgottenWhenTheSheetCloses() async throws {
        let harness = try makeHarness(
            identity: KitchenIdentity(userID: UserID(), isAnonymous: false, email: "a@b.c"))
        _ = await harness.store.nameKitchen("Flat 2B")
        await harness.store.refreshInvite()
        XCTAssertNotNil(harness.store.invite)
        harness.store.forgetInvite()
        XCTAssertNil(harness.store.invite, "a bearer token does not outlive the sheet")
    }

    // MARK: - Which kitchen the app opens

    func testActiveKitchenPrefersTheJoinedOneOverAlphabeticalOrder() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "bagged.active.\(UUID().uuidString)"))
        let alphabeticallyFirst = Kitchen(name: "Aunt's house")
        let joined = Kitchen(name: "Flat 2B")
        XCTAssertEqual(ActiveKitchen.resolve([alphabeticallyFirst, joined], defaults: defaults)?.id,
                       alphabeticallyFirst.id, "no choice stored: the old answer stands")
        ActiveKitchen.set(joined.id, defaults)
        XCTAssertEqual(ActiveKitchen.resolve([alphabeticallyFirst, joined], defaults: defaults)?.id,
                       joined.id)
    }

    // MARK: - Status

    func testAPhoneWithNoKitchenToShareIsLocalNotOffline() {
        let coordinator = SyncCoordinator(repository: nil, kitchenID: nil, transport: nil)
        XCTAssertEqual(coordinator.status, .local)
        XCTAssertFalse(coordinator.isSharing)
        XCTAssertEqual(coordinator.sentence, "On this phone only.")
    }
}

final class KitchenLinkTests: XCTestCase {
    func testReadsTheTokenFromEveryShapeAPersonCanHandUs() {
        XCTAssertEqual(KitchenLink.token(from: "https://bagged.app/j/abcdefghijklmnopqrst"),
                       "abcdefghijklmnopqrst")
        XCTAssertEqual(KitchenLink.token(from: " bagged.app/j/abcdefghijklmnopqrst "),
                       "abcdefghijklmnopqrst")
        XCTAssertEqual(KitchenLink.token(from: "abcdefghijklmnopqrst"), "abcdefghijklmnopqrst")
    }

    func testRefusesWhatIsNotAToken() {
        XCTAssertNil(KitchenLink.token(from: ""))
        XCTAssertNil(KitchenLink.token(from: "hello there"))
        XCTAssertNil(KitchenLink.token(from: "https://evil.example.com/j/abcdefghijklmnopqrst"))
        XCTAssertNil(KitchenLink.token(from: "https://bagged.app/j/short"))
        XCTAssertNil(KitchenLink.token(from: "https://bagged.app/other/abcdefghijklmnopqrst"))
    }

    func testTheLinkRoundTrips() throws {
        let token = "Ab3-_ZzYyXxWwVvUuTt09"
        let url = try XCTUnwrap(KitchenLink.url(token: token))
        XCTAssertEqual(url.absoluteString, "https://bagged.app/j/\(token)")
        XCTAssertEqual(KitchenLink.token(from: url), token)
        XCTAssertTrue(KitchenLink.isInvite(url))
    }
}
