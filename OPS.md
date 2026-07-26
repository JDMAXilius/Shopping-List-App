# Platform recommendation, services, accounts and the release path

---

## 1. The platform answer: yes, native — but not "native both"

> ✅ **Decided, July 2026: iOS native. No Android app.** This section is the argument that
> produced the decision, kept for the record.

**Recommendation: build iOS native in Swift/SwiftUI. Do not plan an Android app yet.**

Not "SwiftUI *and* Android Studio." Those are two products. The recommendation is one product, on
iOS, with Android as a decision deferred until there's revenue to justify it.

### Why native wins *for this app specifically*

React Native's advantage scales with **UI surface**. Its cost scales with **platform
integration**. This app has an unusual ratio of the two:

| | This app |
|---|---|
| Screens | ~6 |
| Tier-1 features requiring Swift with no JS equivalent | **5** — widget, App Intents + `reminders` schema, on-device speech, Vision, Foundation Models |

**That ratio is backwards for React Native.** RN pays off on a twenty-screen app with a REST API.
On a six-screen app that is mostly platform integration, you write all the Swift anyway and add a
seam on top.

Four costs, concretely:

1. **The five Swift modules exist either way.** The widget and Siri aren't nice-to-haves — the
   widget is Tier-1 and Siri is how voice add stays free.
2. **The seam is permanent, not one-time.** A widget can't boot the JS runtime, so the database
   schema and op-log format become cross-language contracts. Every migration is a two-language
   event, forever.
3. **Two runtimes to debug, alone.** When a lock-screen check-off doesn't sync, the bug is in JS,
   in Swift, or in the contract between them.
4. **Feel.** `INTERACTION.md` sets a high bar on motion, haptics and the completion moment.
   Reanimated 4 can hit it. SwiftUI + Core Haptics hits it by default, and the gap shows up
   exactly in the 150 ms interactions this app is made of.

### And the Android argument has already weakened

React Native's real payoff is a cheap second platform. But `FEATURES.md` §10 found that Android
can't run this architecture: Gemini Nano 4 needs 12 GB RAM and a flagship SoC, on-device speech
isn't guaranteed across OEMs, and AppFunctions is still a private preview. On top of that, the
Android market leader in this category is ~90% ad-funded — a model we've ruled out.

**So React Native is buying insurance on a trip we probably won't take.**

### The honest counter-argument, and what would flip this

**Developer velocity beats architectural fit.** If you build substantially faster in
TypeScript/React than in Swift, that advantage is real and it may outweigh everything above —
shipping in four months beats shipping perfectly in seven.

Two things narrow that gap, though:

- Most of this code will be written with Claude Code, which weakens "the language I know" as a
  factor considerably. The architecture fit doesn't change.
- You'd be writing Swift regardless for the five native modules — so RN doesn't let you avoid
  Swift, it just means you write *less* of it, in a harder-to-debug arrangement.

**Rough effort, v1.0 [estimate]:**

| Approach | Relative effort |
|---|---|
| **iOS native only** | **1.0×** — baseline |
| React Native (iOS) | ~1.0–1.15× — UI is faster, the five modules and the seam give it back |
| iOS native + Android native | ~1.8× |
| React Native, both platforms | ~1.3× — **only reachable if Android is actually certain** |

### The decision rule

> **Build iOS native. Revisit Android only when iOS clears a retention bar (`PLAN.md` §7). If it
> ever happens, write it native then** — the op-log is transport-agnostic and the catalog compiles
> to a SQLite file both platforms read unchanged, so the port is the UI and the platform
> integration, which was never shareable anyway.

**Outcome: accepted.** `PLAN.md` §3.0 and `STACK.md` were rewritten for native. `SOURCING.md` and
`INTERACTION.md` were platform-independent and needed only their size figures and haptic API
names updated.

**One clarification worth keeping, since it was nearly misread:** the decision is *iOS native and
no Android*, not *native on both platforms*. Two native codebases is the one option to avoid in
every scenario — if both platforms ever become genuinely required, React Native is the answer,
not Xcode alongside Android Studio.

---

## 2. Services

| Service | Role | Cost | Notes |
|---|---|---|---|
| **Supabase** | Sync backend for the op-log | Free tier → **$25/mo** Pro | Good fit. See below |
| **RevenueCat** | Subscriptions | **Free to $2,500/mo tracked revenue, then 1% of gross** | Confirmed July 2026 |
| **Google Workspace** | Support email | ~$7/user/mo | Fine. Requirements below |
| **Own website** | Marketing, privacy policy, support | — | Two hard dependencies on it, below |

### Supabase — three things to get right

1. **Row Level Security is the whole security model.** Household sharing means a policy where a
   row is visible only to members of its household. **Get this wrong and lists leak between
   families.** It is the single highest-risk piece of backend work in the project; write the
   policies first and test them with a second account before any UI exists.
2. **"No account required to join" needs a device identity.** A generated UUID with a signed
   token, upgradeable to a real account later. Supabase Auth supports anonymous sign-in — use it,
   rather than inventing a parallel identity system.
3. **Supabase is a sync *peer*, not the source of truth.** Local SQLite is authoritative
   (`RESEARCH.md` §5). Don't let Realtime subscriptions quietly become the read path — that
   breaks offline.

### RevenueCat — the cost, modelled

Against `PLAN.md` §4's revenue model: year 1 at ~$75k gross is ~$6.25k/mo MTR, so we exit the free
tier during year 1 and pay ~**$750/yr**. At the year-5 figure (~$165k gross) it's ~**$1,650/yr**.
About 1% of revenue for not hand-rolling receipt validation and not locking paying users out of
their own lists. **Worth it.**

### Google Workspace — what the support address must actually do

- **Be reachable and monitored.** Apple checks the support URL and support contact at review, and
  an unreachable one is a rejection.
- **Handle privacy requests.** Data deletion and access requests arrive here. GDPR gives 30 days;
  Brazil's LGPD gives 15 days for some requests. Have a written procedure before launch, not
  after the first request.
- **Not be a personal address.** `support@` on the app's own domain.

### The website — two hard dependencies

You said not to worry about it, and mostly that's right. But **two URLs are required before the
app can ship**, and they must be live at review time:

1. **Privacy policy URL** — required for every App Store submission, and it must match the App
   Privacy labels you declare.
2. **Support URL** — a real page, not a mailto link.

Add a third if the app is offered in the EU: **terms of service**, since subscriptions involve a
withdrawal right.

**On hosting in Brazil:** irrelevant to the app, which talks to Supabase, not to the website.
It matters for two things only — marketing-page latency for non-Brazilian visitors, and whether
the privacy policy needs to speak to **LGPD** as well as GDPR/CCPA. If the operating entity is
Brazilian, LGPD applies regardless of where the server sits, so write the policy to cover it.

---

## 3. Accounts and the release path

### Apple — set up already, so here's what's left

TestFlight internal-first is the right call. The sequence:

| Stage | Limit | Review needed | Notes |
|---|---|---|---|
| **Internal testing** | 100 members of your App Store Connect team | **No** | Builds available in minutes. Start here |
| **External testing** | 10,000 testers | **Yes** — Beta App Review | Usually ~24h, but first submission takes longer. Budget for it |
| **App Review** | — | Yes | 24–48h typical; plan for a rejection round |

**The blockers that actually delay launches** — none are technical, all take real time:

- **Paid Applications Agreement must be accepted, with banking and tax forms complete.** Without
  it, in-app purchases don't work *even in the sandbox*. This is the most common surprise. Do it
  now, before writing code — the tax forms can take days to clear.
- **Subscription products must be created and submitted with the app**, each needing a display
  name, description, a **review screenshot**, and a completed localisation.
- **App Privacy labels** must match what the app actually does. Ours is a good story — no
  analytics, no ads, no tracking — but the labels still have to be filled in accurately.
- **Subscription review notes**: reviewers routinely reject subscription apps for unclear pricing
  presentation. Show price, period, and trial terms on the paywall itself, not behind a link.
- **Sign in with Apple** is required *only if* you offer third-party social login. We don't, so
  this doesn't apply — worth knowing so you don't build it defensively.

### Google Play — one gotcha worth $25 and a month

Not urgent given iOS-first, but decide it now because it's irreversible:

> ⚠️ **Register the Play account as an *organization*, not a *personal* account.**
>
> Personal accounts created after 13 Nov 2023 must run a closed test with **12 opted-in testers
> for 14 consecutive days** before they can even apply for production access — and "opted in"
> means installed, not invited. **Organization accounts are exempt.**

An organization account requires a D-U-N-S number, which takes time to obtain. Registration is
$25 one-time either way. Getting this wrong costs a month at exactly the moment you want to ship.

---

## 4. Do these now, in this order

Independent of the platform decision, and all of them have lead times:

1. **Accept the Paid Applications Agreement; complete banking and tax.** Nothing about purchases
   works until this clears.
2. **Buy the domain and handles** (`NAMING.md` §9) — still the only thing someone else can take.
3. **Run the paid trademark search** on BAGGED, Class 9 + 42.
4. **Register the Play developer account as an organization**, and start the D-U-N-S process.
5. **Stand up `support@` on the domain** and point Workspace at it.
6. **Draft the privacy policy** to cover GDPR, CCPA and LGPD, and publish it — it's needed before
   the first submission, not at it.
