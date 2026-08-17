# TERMINAL_TICKET_WAVE10_GATE — three debts, two of them never compiled

> STATUS: in-progress — terminal 2026-08-17 (34ee018)
> STATUS: open — written by cloud 2026-08-17.
> Same operating mode and honesty laws as `TERMINAL_TICKET_GATE_AUTOPILOT.md`. Founder is away.
> Do not ask questions. Do not stop.

Wave 10 is not features. Every packet in it is a bug this project found by arguing with itself and
then wrote down instead of fixing. Two of the three could not be run here at all, so **your run is
the first time this code executes**, and the gate is mostly about that.

## Read this before you start: what is and is not proven

| Packet | What it did | State |
|---|---|---|
| **W10-P1** `aae3aaf` | Quarantine a refused push so one 403 stops wedging the queue. Schema **v8**. | **Reported `blocked`.** Not compiled, not run. 7 tests written, 0 executed. |
| **W10-P2** `5f89117` + `c9753ab` | Entitlement read that does not need a scan; purchase grace; sign-out clears. | Not compiled, not run. 16 tests written, 0 executed. |
| **W10-P3** `+ 0003_delete_account.sql` | Server half of account deletion. | **Fully executed.** 20 sections, 117 asserts, 3 mutation tests, on a real Postgres. Only the Deno function is unrun. |

Plus three commits from cloud on top: the 4xx mapping fix (`30c2aba`), the sync sentence
(`140225c`), and docs. Those are unrun too.

**There is no Swift toolchain in the cloud container and installing one is blocked by the proxy** —
`download.swift.org` and `api.github.com` both answer 403 CONNECT, recorded in the proxy status
endpoint. That is not a thing to work around; it is why this ticket exists.

## V1 — Compile it, then run it, then say the numbers

- [x] `xcodegen generate` first. Nothing new landed in the app target this wave, but `ScreensPanel`
      from V9 may still be missing — `git grep -c ScreensPanel Bagged.xcodeproj/project.pbxproj`
      must be non-zero.
- [x] `swift build && swift test` in `Packages/Data`. **Expect mechanical errors** — GRDB
      `StatementArguments` coercion, `Row` subscript casts and actor isolation on the new fake
      state are the three W10-P1 itself named as the places it could not check. Fix them and say
      what they were.
- [x] The full ladder with real counts, against V8's last numbers (DesignKit 89 · BaggedTests 252 ·
      WidgetTests 23 · UI 10). BaggedTests should rise by roughly 19 (16 from W10-P2, 3 from the
      sync sentence) **plus** the 9 from V9's panel if those are still not in the bundle.
- [x] The RLS suite: `sections 1-20 pass`, final notice exactly
      `ALL RLS TESTS PASSED (including seq commit-ordering, invites and account deletion)`.
      It now runs on any cluster, not just one on libpq's default socket — see the note at the end.

## V2 — The one thing W10-P1 could not do, and it is the important one

Its acceptance said: **revert the production change and prove each new test fails.** It could not,
having no compiler. Do it. By its own trace, on revert:

- `testARefusedOpDoesNotBlockAnOpMadeAfterIt` fails — the 403 throws, backoff engages, the frozen
  clock keeps the second kick inside the window, and nothing reaches the transport.
- `testStatusIsNeverSyncedWhileAnythingIsQuarantined` fails — status is `.offline`, not `.stuck`.
- the v8 migration test fails — schema version 7, columns absent.
- four others fail to compile, because revert deletes the API they call.
- `testRetryableFailuresQuarantineNothing` is a **guard** test: it is supposed to pass before and
  after. It fails only if a retryable error is ever quarantined.

**If any of those passes on revert, the test is not testing what it says.** Report which.

Same for the three sentence tests in `KitchenStoreTests` — revert `SyncCoordinator` and
`testAScreenNeverSaysItIsStillTryingOverAChangeNothingWillRetry` must fail.

## V3 — The design questions W10-P1 left open, with my rulings so you do not re-derive them

Two are real and neither is yours to invent. **Do not implement these; confirm the behaviour and
log it.** They are wave-11 packets.

1. **Batch granularity.** `SupabaseTransport.push` chunks at 200 ops; the engine quarantines
   everything it handed to `push`. A phone with 500 queued ops that is refused quarantines all 500,
   including 300 the server never saw. **Ruling for wave 11:** make the two granularities equal by
   letting the transport declare its batch size through `SyncTransport` and having the engine drain
   one batch at a time. Not by bisecting, and not by the engine hard-coding a Supabase constant.
2. **After the bound is spent, an op is held forever.** Three refusals, an hour apart, and there is
   no user-reachable way back — a person re-invited the next day never gets their held edits to the
   household. **Ruling for wave 11:** a deliberate, user-initiated "try these again" —
   `Repository.releaseQuarantined(kitchenID:)` resetting the count, called from the kitchen screen.
   Not automatic: automatic is how the infinite retry loop comes back.

Log whether the behaviour matches those descriptions once it compiles.

## V4 — Account deletion is built but not deployable, and one way it fails is silent

W10-P3 proved the SQL. Two things are yours:

- [ ] `deno check supabase/functions/delete-account/index.ts` — the only half never executed.
- [ ] **Read this and put it in the log so it cannot be lost:** deploying `0003` without the edge
      function leaves deletion *silently* incomplete. `auth.users` is owned by `supabase_auth_admin`
      and a delete that matches zero rows raises nothing, so the person's data goes while their
      login survives. They can sign back in to an empty account and App Review 5.1.1(v) is not
      satisfied. Both halves ship together or neither does.
- [ ] Neither can actually be deployed: still `TERMINAL_TICKET_FOUNDER_BLOCKERS` item 1.

## V4b — What the refuter found and what is still open behind it

`W10-P2-REFUTE` returned **holed**. Four findings were fixed on the spot (`b4db985`): an absent row
revoking Plus from a paying subscriber, a per-instance guard over shared state, a foreground read
swallowed by its own in-flight flag, and a compile error that would have taken the whole test
target down. Two it found are recorded rather than fixed, and both are wave-11 packets:

1. **A signed-in joiner can be sold to.** `SubscriptionStore.storedRole` defaults an unknown role to
   `.owner`, and `KitchenStore.refreshMembers` swallows a failed roster read — so a person who joins
   someone else's kitchen over a bad connection is classified an owner, the wrong role is persisted
   to the App Group, and they meet the paywall they were invited past. `KitchenStore` is careful
   that "unknown is never a promotion to owner"; `SubscriptionStore` is not. **Ruling for wave 11:**
   persist role **per kitchen id**, and when there is no answer for the current kitchen, offer
   nothing until the roster answers. Do not simply flip the default to `.guest` — that tells a real
   owner they joined, which is its own lie.
2. **The purchase grace window is wall-clock with no lower bound.** Setting the device clock back a
   few days makes `age` negative, which is always inside the window, so a lapsed subscriber keeps
   Plus indefinitely *while fully online*. Left permissive deliberately: clamping would revoke Plus
   from a genuine buyer during an NTP correction, and the harm here is to revenue, not to a person.
   It disappears entirely when RevenueCat's customer info becomes the source for `isPlus`.

Both are in the log so a verifier does not rediscover them as new.

## V5 — What none of this proves

Say so plainly in the log rather than letting a green suite imply otherwise:

- **The entitlement wiring is unproven and unprovable here.** Every build in this repo has no
  `SupabaseURL`, so the reader closure is nil and the refresh is a no-op — every unit test would
  still pass if it were wired to the wrong thing. The check is three steps on TestFlight: buy on
  device one, foreground device two signed in as the same account, watch the sales card go. **And
  foreground device two twice** — the first read can still land before the RevenueCat webhook has
  written, in which case nothing is wrong and the second foreground clears it.
- **`KitchenStore.signOut()` has no call site in any screen.** Sign-out clearing entitlement is
  correct, unit-tested and currently unreachable by a person, because there is no way to sign out
  of this app at all. Wave 11.
- **A 403 on *pull* is untouched.** A device whose reads are refused retries a doomed pull every 20
  seconds forever and never releases anything, while nothing tells the person they are no longer in
  the kitchen. Pre-existing, unchanged, now named.

## Note for anyone running the RLS suite anywhere

It used to die at section 13 on every cluster that was not on libpq's default socket, because
`dblink` was handed `dbname=` alone. It now builds the connection string from the running server's
own `unix_socket_directories` and `port`. Section 14 additionally had never executed in its life —
an invalid uuid literal and a helper that does not exist — which is worth remembering the next time
a suite prints ALL TESTS PASSED.

## Log

<!-- Append dated entries. Never rewrite above this line. -->

## Log

**2026-08-17 · terminal · V1 done, V2 done — the revert proof W10-P1 could not run.**

**V1 — wave 10 compiled and executed for the first time.**
- `ScreensPanel` is in the project (8 references in the pbxproj after regenerate).
- **One mechanical error, twice**: `SyncEngineTests:245` and `:388` read the GRDB pool inside an
  async test without `await` (`try database.pool.read` → `try await database.pool.read`). None of
  the three things W10-P1 predicted (StatementArguments coercion, Row subscript casts, actor
  isolation on the fake) actually bit — those all compiled as written.
- Counts, against V8's last numbers: Core **59/59** · Catalog **57/57** · Data **69/69** (was 59;
  +10 from W10-P1's quarantine tests) · DesignKit **89/89** · **BaggedTests 284/284** (was 252;
  +32 = W10-P2's 16, the sync sentence's 3, V9's panel 9, and 4 more) · WidgetTests **23/23** ·
  UI **11/11** (ExportUITests is new since V8). Everything green.

**V2 — the acceptance W10-P1 reported `blocked`. Done, and it holds.**
A plain revert only proves "does not compile", so I ran a **surgical behavioural revert** in a
throwaway worktree: every API kept (`quarantinedOps`, `refused`, `markQuarantined`), and only the
one decision removed — `pushOrQuarantine` re-throws a `.rejected` instead of quarantining it, i.e.
exactly the pre-W10-P1 behaviour. Then ran the suite. Result, per the ticket's list:

| test | on revert |
|---|---|
| `testARefusedOpDoesNotBlockAnOpMadeAfterIt` | **failed** |
| `testStatusIsNeverSyncedWhileAnythingIsQuarantined` | **failed** — `offline`, not `stuck`, exactly as predicted |
| `testAQuarantinedOpIsStillInTheDatabaseWithItsPayload` | **failed** |
| `testPendingExcludesQuarantinedOpsAndRefusedCountsThem` | **failed** — refused counted 0, not 2 |
| `testASuccessfulPullReleasesQuarantinedOps` | **failed** |
| `testTheReleaseIsBoundedSoARefusalCannotRetryForever` | **failed** — 8 push attempts instead of 3, and the bound never persisted |
| `testRetryableFailuresQuarantineNothing` (guard) | **passed**, before and after — correct, it must |

**Every new test fails without the fix and the guard test does not. Nothing is testing nothing.**
- Same for the schema: reverting `Migrations.swift` + `AppDatabase.swift` alone makes
  `testTheQuarantineColumnsArriveInV8AndQuarantineNoExistingOp` fail (no v8 row at all) and
  `testMigrateIsIdempotent` fail on the column set — the two the ticket named.
- The three sentence tests: reverting `SyncCoordinator` to `140225c~1` does not compile
  `KitchenStoreTests` (`SyncCoordinator.sentence` did not exist as a static then), so those three
  are compile-blocked rather than behaviourally provable. Recorded as such rather than claimed.

**2026-08-17 · terminal · V1 closed — the RLS suite including account deletion, on real Postgres.**
- Fresh database, shim, 0001, 0002, **0003_delete_account**, then the suite, on Postgres 17.11:
  **all 20 sections pass**, final notice exactly
  `ALL RLS TESTS PASSED (including seq commit-ordering, invites and account deletion)`.
  The deletion sections are the interesting ones and they all hold: a solo kitchen and everything
  attached to it goes while a bystander is untouched (15); a shared kitchen SURVIVES and the
  longest-standing member inherits usable ownership (16); no id to spoof, anon refused (17); one
  call across three kitchens gives three different correct outcomes (18); identical `joined_at`
  promotes exactly one, deterministically (19); replay is an all-zero no-op and the last-owner
  guard is still armed (20).
- `deno check delete-account/index.ts` passes — the function W10-P3 left unrun now at least
  type-checks; join-kitchen, revenuecat-webhook and scan-receipt still check, and
  `deno test scan-receipt/` is **27/27**.
- Not claimed: the function has still never served a request. That needs a deployed project
  (FOUNDER_BLOCKERS item 1).
