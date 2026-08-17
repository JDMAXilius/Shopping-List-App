import Core
import Data
import Foundation
import XCTest

@testable import Bagged

/// A backend that answers like the SQL does: `join_kitchen` is keyed on the exact token and
/// gives ONE answer for missing and revoked, and a new invite revokes every earlier one.
actor FakeKitchenBackend: KitchenBackend {
    private(set) var calls: [String] = []
    /// The id the phone asked to keep. The real function honours it, so this fake must too —
    /// a fake that mints its own would hide the very bug this argument exists to fix.
    private(set) var askedToKeep: KitchenID?
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

    func createKitchen(name: String, id: KitchenID) async throws -> KitchenID {
        calls.append("createKitchen")
        askedToKeep = id
        if let failure { throw failure }
        guard let me = stored, !me.isAnonymous else { throw KitchenError.signInRequired }
        kitchens[id] = name
        roster[id] = [Member(userID: me.userID, role: .owner, joinedAt: Date())]
        return id
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

    /// Nothing in this file asks about entitlement; a fake user who has never scanned has no row,
    /// which is the answer `SubscriptionStoreTests` covers in every direction.
    func entitlement() async -> EntitlementRead {
        calls.append("entitlement")
        return .absent
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

    private func makeHarness(identity: KitchenIdentity? = nil,
                             onSignOut: @escaping @MainActor () -> Void = {}) throws -> Harness {
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
                                 defaults: defaults, onSignOut: onSignOut)
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

    // MARK: - Signing out

    /// Entitlement is per `user_id`, so leaving the account has to take it: the hook is how that
    /// reaches `SubscriptionStore` without this store knowing one exists.
    func testSigningOutTellsTheAppToForgetEntitlement() async throws {
        let forgotten = expectation(description: "entitlement forgotten")
        let harness = try makeHarness(
            identity: KitchenIdentity(userID: UserID(), isAnonymous: false, email: "a@b.c"),
            onSignOut: { forgotten.fulfill() })

        await harness.store.signOut()

        await fulfillment(of: [forgotten], timeout: 1)
        XCTAssertNil(harness.store.identity)
        let calls = await harness.backend.calls
        XCTAssertTrue(calls.contains("signOut"), "and the session itself is gone")
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

    /// W10-P1 gave the engine a state nothing was being attempted for. Until this, the screen
    /// answered "Still trying to reach your kitchen." over edits that would never be tried again —
    /// a sentence that is false in the one situation where a person most needs a true one.
    func testAScreenNeverSaysItIsStillTryingOverAChangeNothingWillRetry() {
        let sentence = SyncCoordinator.sentence(status: .stuck, pending: 0, refused: 3)

        XCTAssertFalse(sentence.contains("Still trying"), sentence)
        XCTAssertEqual(sentence, "3 changes your kitchen wouldn't take. They're safe on this phone.")
    }

    func testARefusedChangeIsCountedApartFromOneStillQueued() {
        XCTAssertEqual(SyncCoordinator.sentence(status: .stuck, pending: 2, refused: 1),
                       "1 change your kitchen wouldn't take. It's safe on this phone. "
                           + "2 changes still to send.")
        // Nothing refused: the old sentence is still the right one, because something IS being
        // tried — that is the whole difference between the two states.
        XCTAssertEqual(SyncCoordinator.sentence(status: .stuck, pending: 0, refused: 0),
                       "Still trying to reach your kitchen.")
    }

    /// Every sentence with a number in it, read out loud. "1 change haven't sent yet" was shipped.
    func testTheSingularReadsLikeEnglish() {
        for status in [SyncStatus.offline, .stuck] {
            for (pending, refused) in [(1, 0), (1, 1), (0, 1)] {
                let sentence = SyncCoordinator.sentence(status: status, pending: pending,
                                                        refused: refused)
                XCTAssertFalse(sentence.contains("1 changes"), sentence)
                XCTAssertFalse(sentence.contains("1 change haven't"), sentence)
                XCTAssertFalse(sentence.contains("changes hasn't"), sentence)
            }
        }
        // The offline singular is already good English and stays exactly as it was.
        XCTAssertEqual(SyncCoordinator.sentence(status: .offline, pending: 1, refused: 0),
                       "No signal — 1 change will send when it's back.")
        XCTAssertEqual(SyncCoordinator.sentence(status: .stuck, pending: 1, refused: 0),
                       "1 change hasn't sent yet. It's safe on this phone.")
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

/// Enough of GoTrue and PostgREST to drive one entitlement read: a session, so the request
/// carries a token, then one scripted answer for the read itself.
private actor FakeEntitlementHTTP: SupabaseHTTP {
    private let answer: Result<SupabaseResponse, KitchenError>
    private(set) var requests: [SupabaseRequest] = []

    init(status: Int, body: String) {
        answer = .success(SupabaseResponse(status: status, body: Foundation.Data(body.utf8)))
    }

    init(failure: KitchenError) {
        answer = .failure(failure)
    }

    func send(_ request: SupabaseRequest) async throws -> SupabaseResponse {
        requests.append(request)
        guard !request.url.path.contains("/auth/") else {
            return SupabaseResponse(status: 200, body: Foundation.Data(Self.session.utf8))
        }
        return try answer.get()
    }

    private static let session = """
        {"access_token":"jwt-abc","refresh_token":"refresh-1","expires_in":3600,
         "user":{"id":"11111111-1111-1111-1111-111111111111","email":null,
                 "is_anonymous":true}}
        """
}

/// In memory, so no test writes a session to the keychain.
private final class MemoryTokenStorage: TokenStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Foundation.Data?

    func read() -> Foundation.Data? { lock.withLock { stored } }
    func write(_ data: Foundation.Data) { lock.withLock { stored = data } }
    func clear() { lock.withLock { stored = nil } }
}

/// The read that does not need a scan (TERMINAL_TICKET_FOUNDER_BLOCKERS §9). What it must never do
/// is confuse "this user has no row" with "the request failed".
final class KitchenClientEntitlementTests: XCTestCase {
    private struct Harness {
        let client: KitchenClient
        let auth: KitchenAuth
        let http: FakeEntitlementHTTP
    }

    private func makeHarness(_ http: FakeEntitlementHTTP) -> Harness {
        let config = SupabaseConfig(projectURL: URL(string: "https://example.supabase.co")!,
                                    anonKey: "anon-key")
        let auth = KitchenAuth(config: config, http: http, storage: MemoryTokenStorage())
        return Harness(client: KitchenClient(config: config, auth: auth, http: http), auth: auth,
                       http: http)
    }

    func testAPlusRowIsReadWithoutScanningAnything() async throws {
        let harness = makeHarness(FakeEntitlementHTTP(
            status: 200, body: #"[{"is_plus":true,"scans_used":3}]"#))
        _ = try await harness.auth.signInAnonymously()

        let read = await harness.client.entitlement()

        XCTAssertEqual(read, .found(isPlus: true, scansUsed: 3))
        let request = try XCTUnwrap(await harness.http.requests.last)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url.path, "/rest/v1/entitlement")
        XCTAssertEqual(request.headers["authorization"], "Bearer jwt-abc")
        let query = try XCTUnwrap(request.url.query)
        XCTAssertTrue(query.contains("is_plus"), query)
        XCTAssertTrue(query.contains("scans_used"), query)
        // `entitlement_select_own` is `user_id = auth.uid()`: RLS scopes the row, so no user id
        // goes on the wire and none is trusted from the client.
        XCTAssertFalse(query.contains("user_id"), query)
    }

    func testNoRowIsAFreeAccountRatherThanAFailure() async throws {
        let harness = makeHarness(FakeEntitlementHTTP(status: 200, body: "[]"))
        _ = try await harness.auth.signInAnonymously()

        let read = await harness.client.entitlement()

        XCTAssertEqual(read, .absent, "consume_scan creates the row lazily, so none is normal")
    }

    func testEveryFailedReadIsUnavailableAndNeverReadsAsAnEmptyRow() async throws {
        let scripts = [FakeEntitlementHTTP(status: 401, body: "{}"),
                       FakeEntitlementHTTP(status: 500, body: ""),
                       FakeEntitlementHTTP(status: 200, body: #"{"is_plus":true}"#),
                       FakeEntitlementHTTP(failure: .unreachable)]
        for script in scripts {
            let harness = makeHarness(script)
            _ = try await harness.auth.signInAnonymously()

            let read = await harness.client.entitlement()

            XCTAssertEqual(read, .unavailable, "a failed read claims nothing")
        }
    }

    func testAPhoneWithNoSessionSaysNothingAndAsksNothing() async throws {
        let harness = makeHarness(FakeEntitlementHTTP(
            status: 200, body: #"[{"is_plus":true,"scans_used":0}]"#))

        let read = await harness.client.entitlement()

        XCTAssertEqual(read, .unavailable)
        let requests = await harness.http.requests
        XCTAssertTrue(requests.isEmpty, "no session, so nothing went on the wire")
    }
}

extension KitchenStoreTests {
    /// Sharing must not strand the list you already have. Every op this phone wrote is stamped
    /// with its local kitchen id; if the server minted a new one, the engine would correctly
    /// refuse to push those ops and the kitchen-blind projection would keep showing them to the
    /// owner — so the guest joins an empty list and neither phone can see why.
    func testSharingKeepsTheKitchenTheOpsAreAlreadyAddressedTo() async throws {
        // Signed in from the start, like the other owner tests: `makeHarness(identity:)` is
        // this file's sign-in, and `nameKitchen` is the call that mints the shared kitchen.
        let harness = try makeHarness(
            identity: KitchenIdentity(userID: UserID(), isAnonymous: false, email: "a@b.c"))
        let before = harness.store.kitchen.id

        let named = await harness.store.nameKitchen("Flat 2B")
        XCTAssertTrue(named)
        let asked = await harness.backend.askedToKeep  // the fake is an actor
        XCTAssertEqual(asked, before, "the id goes up, not down")
        XCTAssertEqual(harness.store.kitchen.id, before, "and the phone keeps it")
    }
}
