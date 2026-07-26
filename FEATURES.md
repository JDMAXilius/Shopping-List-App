# Core Feature Definition

What the app **is**. Derived from `PLAN.md` §1 positioning: *the shared grocery list that shows
what the trip costs and knows your store.*

The test for "core": **remove it and this becomes a different product, or an indistinguishable
one.** Everything that survives that test is below. Everything else is in §7 and is not v1.

---

## The five

| # | Feature | Why it's core | If removed |
|---|---|---|---|
| 1 | **The list** | The thing people open 3× a week | No product |
| 2 | **Household sharing** | The reason families choose a list app over Notes; also the entire growth loop | A single-player app with no distribution |
| 3 | **Works offline** | Supermarkets have no signal. This is a property of all four others, not a feature beside them | Fails in the exact moment it's for |
| 4 | **Aisle order** | Differentiator #2 — the list matches the walk | A generic list |
| 5 | **Cost** | Differentiator #1 — the unclaimed territory in the grocery category | Indistinguishable from AnyList and OurGroceries, who are bigger, older and better funded |

Anything not serving one of these five does not go in v1.

---

## 1. The list

The core loop is **add → check off**. It runs hundreds of times per household per month, and it
is the only thing that must be perfect.

**Add**
- Inline field, always reachable, one thumb. Placeholder: `I need…` (borrowed from Bring! — beats
  "Add an item")
- Autocomplete ranked **personal history → household history → seeded catalog**. Max 10
  suggestions, generous touch targets
- Resolution handles qualifiers, plurals, typos, and regional synonyms before declaring a miss
  — built and tested: `data/catalog/`, 414 items, 859 lookup terms, 23 cases passing
- An unrecognised item is **still a valid item** — no `item_id`, no emoji, no price, lands in
  "Other", one tap to file forever
- Never a blocking prompt. No "which milk?" modal — the autocomplete list *is* the disambiguation

**Quantity** — first-class, on the name line, not buried in metadata. Handles both counted (`×6`)
and measured (`2 L`, `250 g`). Optional; absent renders as nothing, not `×1`.

**Check off**
- One tap, thumb-reachable, no confirmation
- Checked items sink into a "In the cart" section, struck through, still visible
- Undo available
- Check-off is the signal that teaches aisle order (§4) and pantry later — never a throwaway event

**Acceptance**
- Cold launch → item on list: **≤2 taps, ≤2 seconds**
- Autocomplete first paint: **<100ms**, from local data, no network
- If either fails, nothing else in this document matters

## 2. Household sharing

**Join by link, no account.** The invitee taps a link and sees the list — no signup wall, no
app-store detour before they understand what they've been sent. This is the single biggest
friction point in the category and the reason Google Keep still holds ground.

- Real-time sync across all members
- **Attribution as a caption**, never an assignment UI: "Maria added", "Ariel got this".
  No owners, no assignees, no due dates, no roles, no permissions matrix
- Member avatars in the header — initials at v1, photos later
- Multiple named lists per household
- **Free forever for members.** Only the list *owner* ever meets a paywall (`PLAN.md` §4).
  Taxing the invite loop kills growth

**Acceptance**
- Invited member sees list contents **≤3 seconds** from tapping the link, with no account
- Two members editing simultaneously: no lost writes, no duplicate rows

## 3. Works offline

Not a feature — a property of features 1, 2, 4 and 5. Every operation succeeds locally and
reconciles later.

- Local SQLite is the source of truth; the server is a sync peer, not an authority
- Op-log: `add` / `check` / `uncheck` / `edit` / `delete`, client-generated UUIDs, logical clock,
  last-write-wins per field
- `add` is **idempotent on normalized name per list** — "milk" added on two phones in two aisles
  collapses to one row
- Queue batches offline writes, replays on reconnect
- No CRDT library. A shopping list is a set, not a sequence (`RESEARCH.md` §5)

**Acceptance**
- Full session in airplane mode: add, check, edit, reorder — all succeed
- On reconnect: no duplicates, no lost edits, no user-visible conflict prompt
- Copy is honest and calm: "Offline — everything's saved, it'll sync"

## 4. Aisle order

**Automatic on add, correctable in one gesture, learned over time.**

- Every item lands in a category with **zero user input**, via the catalog
- Categories render as coloured pills with counts
- **Per-store profiles.** Category order is a property of *(store, household)*, not of the item —
  Dairy is aisle 3 at one store and the back wall at another
- Drag to reorder categories; persists per store
- **Learned order** from check-off sequence — the order you actually walk it (v1.1; v1 ships
  manual reorder)

**Acceptance**
- A fresh list of 10 common items is correctly grouped with no user configuration
- Reordering categories once persists for that store forever

## 5. Cost

The differentiator, and the one that must not ship half-built.

- **Per-item price**, **per-category subtotal**, **trip total** — the subtotal is borrowed from
  MinimaList and is the best idea in the category: "Produce $18, Meat $17.99" tells you *where*
  the money went
- **Seeded estimates so it works on trip one, with zero input.** Without this the feature is an
  empty promise until receipt scanning ships
- **Estimated and observed must never look alike.** Grey with `~` prefix for estimates, solid ink
  for prices actually paid, `≈` on the total while any line is estimated
- **Round estimates hard** — nearest $0.50 under $10, nearest $1 above. Enforced by the catalog
  build, not by review. `$3.47` implies a lookup; `~$3.50` reads as a guess
- Any observation **permanently overrides** the estimate for that household
- Prices live in their own table as *observations*, never as a column on the item
- **Unpriced is a valid state** — renders as `—`, not a fake zero. The total simply doesn't
  appear until at least one line has a price

**Acceptance**
- A brand-new user with a 10-item list sees a credible trip total having entered **nothing**
- No user can mistake an estimate for a price they paid
- **Falsification test:** ≥40% of households have entered or confirmed at least one real price by
  trip 3. If this fails, the strategy is wrong and no amount of polish fixes it

---

## 6. The shape of the app

**One screen matters.** The list *is* the app. Store profiles, household settings and price
history are secondary screens you visit rarely. No tab bar competing for attention at v1.

Required for launch but not core to identity:

- **Dark mode** — used in dim stores and at night. Non-negotiable, but table stakes
- **Lock-screen + Home Screen widget with tappable checkboxes** — the right answer to pushing a
  cart with both hands. Komorebi ships this at 29K ratings, so it's catching up, not
  differentiating
- **Accessibility** — Dynamic Type, VoiceOver, `prefers-reduced-motion`. Also the price of
  Apple editorial featuring, which is the only free distribution at scale here

---

## 7. Explicitly not core

Deferred, with the reason:

| Not in v1 | When | Why not now |
|---|---|---|
| Barcode scan (Open Food Facts) | v1.1 | Long-tail nicety; the catalog covers the common case |
| Price editing + history UI | v1.1 | v1 needs entry and display, not analytics |
| Learned aisle order | v1.1 | Manual reorder is enough to prove the idea |
| Recurring staples / "the usual" | v1.1 | Real value, not identity |
| **Receipt scan → price book** | v1.2 | The moat, but the moat is *accumulated history*, not the capability. Start accumulating in v1 |
| Voice / natural-language add | v1.2 | "AI" is table stakes marketing now, not a differentiator |
| Pantry inventory + expiry | v2, maybe | A second product. Would double scope and split positioning |
| Recipe import | v2, late, unambitious | **AnyList has owned this for 14 years at 4.9★.** Do not fight there |

**Never building:**

- Coupons, deals, circulars — that's Listonic's and Bring!'s business, and it makes brands the customer
- Retailer or brand dashboards, brand analytics, shopping data sold to FMCG
- Retailer price APIs — one chain, one country, terms risk (`RESEARCH.md` §5)
- Calories, macros, wellness scoring — judging a cart loses the household
- Assignees, due dates, workspaces, roles, permissions — the work-tool failure mode
- A mascot — declined knowingly; see `research/store-teardown.md` §7

---

## 8. Build order

Each phase ends in something demonstrable.

1. **List + offline** — add, check, quantity, local SQLite, op-log. One device
2. **Catalog integration** — autocomplete and auto-categorization from `data/catalog/`
3. **Sync + sharing** — two devices, join by link, no account
4. **Aisle order** — grouping, per-store profiles, manual reorder
5. **Cost** — seeded estimates, subtotals, trip total, estimated-vs-observed rendering
6. **Polish for launch** — dark mode, widget, accessibility, empty states

Phases 1–3 are a functioning shared list. **Phases 4–5 are what make it worth choosing** over
apps with a 14-year head start, so they are not optional and must not be cut under pressure.

## 9. Still open

- **Platform** — iOS-native vs Expo cross-platform. Doesn't change this definition; changes the
  build estimate and Android reach
- **Item imagery** — emoji at v1 versus commissioned art. AnyList and OurGroceries both use real
  product photography, so this is a known gap rather than a settled choice

---

## 10. Voice and AI — on-device first, and it's nearly free

**Verified: yes, the phone can do this, and for the common case you need no cloud AI at all.**

### The ladder

Each rung is tried before the next. Everything in rungs 1–3 is **free, offline, and private.**

| Rung | Tech | Cost | Covers |
|---|---|---|---|
| **1. Transcribe + resolve** | `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` → our existing catalog resolver | **$0** | ~90% of voice adds |
| **2. Siri, no app launch** | **App Intents** — "add milk to my list" handled by the system | **$0** | Hands-free while driving or cooking |
| **3. Photo of a printed list** | Vision framework on-device text recognition | **$0** | Typed/printed notes, receipts |
| **4. Messy phrasing** | **Foundation Models** — Apple's ~3B on-device LLM (iOS 26), no API key, no per-token bill, no network | **$0** | "get stuff for tacos" → items |
| **5. Genuinely hard cases** | Cloud model | **paid** | Bad handwriting, recipe URL parsing. **Gate behind the subscription so revenue covers it** |

### Why rung 1 covers most of it — we already built the hard part

Voice add is usually framed as an AI problem. It isn't. It's *transcription* + *resolution*, and
**the resolver already exists** (`data/catalog/`, §1). Apple transcribes "two pounds of chicken
breast" for free; our pipeline strips the qualifier and the quantity and lands on `chicken breast`.
No model call anywhere.

Better still, the two halves cover each other's weaknesses. `SFSpeechRecognizer` **cannot be
trained on custom vocabulary**, so it will mangle unusual grocery words — but the resolver already
does bounded edit-distance matching for typos, so a mis-transcription behaves exactly like a typo
and resolves anyway.

### Constraints to design around

- **On-device model downloads on first use.** It isn't available the instant the app installs —
  fall back to typing and never block
- **1 minute of audio per request; 1,000 requests per device per hour.** Irrelevant for adding
  groceries, fatal if you tried to stream continuously
- **Foundation Models needs an Apple Intelligence-capable device.** So rung 4 is an *enhancement*,
  never a dependency. Rungs 1–3 work on far older hardware
- **Handwriting is the weak spot.** Vision reads print well and handwriting unevenly. This is the
  one place cloud earns its cost, and the one place to put it behind the paywall

### The split: iPhone vs Claude API

**Everything on the free tier and everything high-frequency stays on-device.** Cloud is reserved
for low-frequency, paid-tier work. That rule is what makes the economics safe — see the trap below.

| Job | Where | Why | Cost |
|---|---|---|---|
| Speech → text | **iPhone** — `SFSpeechRecognizer`, on-device | Works offline, no quota | $0 |
| "Hey Siri, add milk" | **iPhone** — App Intents | System handles it; app needn't launch | $0 |
| Text → item | **iPhone** — our catalog resolver | Already built and tested | $0 |
| Barcode scan | **iPhone** — Vision / AVFoundation | Native, instant | $0 |
| **Printed** list photo → items | **iPhone** — Vision text recognition | Vision reads print reliably | $0 |
| Loose phrasing → items | **iPhone** — Foundation Models (iOS 26) | On-device LLM, no API key | $0 |
| **Receipt → line items + prices** | **Claude API** | Messy layouts, wrapped lines, abbreviations, tax/discount rows. Beyond a 3B on-device model | see below |
| **Handwriting → items** | **Claude API** | Vision reads handwriting unevenly; this is the one place it genuinely fails | see below |
| Recipe URL/text → ingredients | **Claude API** | Long, unstructured, quantity parsing | see below |

### What the cloud calls actually cost

Current API pricing (per million tokens):

| Model | Input | Output |
|---|---|---|
| Claude Opus 5 | $5.00 | $25.00 |
| Claude Sonnet 5 | $3.00 ($2.00 intro through 2026-08-31) | $15.00 ($10.00 intro) |
| Claude Haiku 4.5 | $1.00 | $5.00 |

A receipt scan is roughly **2,000 input tokens** (downsampled photo + prompt) and **500 output
tokens** (structured JSON) **[model]**:

| Model | Per receipt | 4 trips/mo | Per year |
|---|---|---|---|
| Haiku 4.5 | ~$0.0045 | ~$0.018 | **~$0.22** |
| Sonnet 5 | ~$0.0135 | ~$0.054 | ~$0.65 |
| Opus 5 | ~$0.0225 | ~$0.090 | ~$1.08 |

**Against $29.99/yr revenue, even the most expensive option is ~3.6% of the subscription.** Cloud
AI is affordable here — but only because it's gated behind the paywall and runs a handful of times
a month.

Three levers cut it further:

- **Batch API — 50% off.** Receipts aren't latency-critical. Queue them and process asynchronously;
  most batches finish within the hour.
- **Prompt caching** — the system prompt and JSON schema are identical on every call. Cache reads
  cost ~0.1× (minimum cacheable prefix is 512 tokens on Opus 5, 1024 on Sonnet 5).
- **Structured outputs** — `output_config.format` with a JSON schema guarantees parseable output,
  so no retry loop on malformed JSON.

### The trap that would actually hurt

**Never put a high-frequency or free-tier action on the cloud.** Voice add is the obvious
temptation and the clearest example: 20 adds/week × 100,000 free users ≈ 1M calls/year. Even at
a tenth of a cent each that's five figures annually, paid on users who by definition generate no
revenue.

The rule that keeps this safe:

> **Free tier → on-device only. Paid tier → cloud allowed, low-frequency only.**

Receipt scanning satisfies both halves: it's paid, and it runs ~4× a month. Voice add satisfies
neither, which is why rung 1 matters so much — and why the resolver we already built is doing
more strategic work than it looks.

### Siri, feature by feature — checked against Apple's docs, July 2026

Two things changed at **WWDC 2026** (June) that this plan predates:

1. **SiriKit is formally deprecated.** App Intents is now the only route into Siri, with a
   two-to-three-year migration window for existing apps. For us — building new — this is
   simplification, not cost: there was never a reason to touch SiriKit.
2. **App Schemas.** Siri no longer just *invokes* your intent; you adopt a **system-defined
   schema** and Siri handles the natural-language understanding, parameter extraction and
   follow-up questions. You map its parameters onto your existing code. Press reports say the
   language model behind Siri is now Google Gemini; **that doesn't change anything for us** —
   the schema is the contract regardless of what sits behind it.

**The finding that matters: the `reminders` schema domain covers most of our list.** Verified
from [Apple's App Intents domain reference](https://developer.apple.com/documentation/appintents/app-intent-domains):

| Schema | Kind | Maps onto |
|---|---|---|
| `.reminders.createReminder` | intent | **Add an item** |
| `.reminders.updateReminder` | intent | **Check off, edit quantity, add a note** |
| `.reminders.deleteReminders` | intent | Remove an item |
| `.reminders.createList` / `.updateList` | intent | Our lists |
| `.reminders.createSection` / `.updateSection` | intent | **Aisle groups** |
| `.reminders.reminder` / `.list` / `.section` / `.group` | entities | Our data model, nearly one-to-one |
| `.reminders.locationTrigger` + `locationTriggerEvent` | entity + enum | **"Show my list when I get to the store" — geofencing, free, system-run** |

> ⚠️ **Not "lists" or "shopping."** A WWDC session summary appeared to name *Lists* and *Shopping*
> domains; the actual reference has neither. The domains are Audio, Calendar, Camera, Clock,
> Files, Mail, Maps, Messages, Notes, Phone, Photos, **Reminders**, and system search.
> **Reminders is the one we adopt.** Recorded because assuming a Shopping domain existed would
> have been an expensive planning error.

#### Against the five core features

| # | Core feature | What Siri/iPhone does | What Claude adds |
|---|---|---|---|
| 1 | **The list** | **Nearly all of it.** `createReminder` / `updateReminder` / `deleteReminders`, plus on-device transcription and our resolver | **Nothing.** Adding milk is a solved, free problem |
| 2 | **Household sharing** | **Nothing.** No schema, no Siri surface — sharing is our sync layer and ours alone | **Nothing.** Pure engineering, no AI in it |
| 3 | **Works offline** | On-device speech and App Intents execution both work with no signal | **Nothing — and this is a constraint, not a gap.** Claude requires a network by definition, so no cloud feature may ever sit in the critical path |
| 4 | **Aisle order** | **Most of it.** `createSection` / `updateSection` for the groups; `locationTrigger` gives store-arrival for free — a feature we'd otherwise have built | **Nothing** |
| 5 | **Cost** | **Nothing.** The Reminders schema has no concept of a price. Voice-adding "milk, three forty" needs our own custom intent and resolver | **The one place it earns its keep** — receipt → line items + prices (§ above) |

#### The strategic read

**Apple's schemas cover exactly the commodity half of the product and none of the differentiator.**
Adopting `reminders` gets us list mechanics and aisle sections at near-zero engineering cost,
which is a genuine gift. It gets us nothing on sharing and nothing on cost — the two features the
business actually rests on.

That cuts both ways, and both are worth stating:

- **Good:** the free work is free, so the build effort concentrates where the moat is.
- **Sobering:** any competitor gets the same gift. Aisle sections via Siri are not defensible.
  Cost and household sharing are the only parts nobody hands us.

#### Two limits to design around, both untested

- **We compete with the built-in Reminders app for the same phrasings.** "Add milk to my list"
  is a sentence Apple's own app already answers. Users may have to say the app name until the
  system learns the preference. **Test this early — it decides how much weight the Siri path can
  carry in marketing**, and it is not something the documentation settles.
- **Schema adoption is all-or-nothing per cluster.** Xcode enforces completeness at build time:
  adopt one schema and you must implement its related schemas or the build fails. Budget for the
  whole `reminders` cluster, not a single intent. Custom schemas for Siri are not possible —
  you adopt Apple's shape or you get no Siri language understanding at all.

### Adding by voice without saying "Hey Siri"

**"Hey Siri" is a trigger, not the feature.** The feature is an App Intent, and the same intent
surfaces across Siri, Shortcuts, Spotlight, widgets, the Action Button and Control Center. Write
it once, reach all of them.

Ranked by how little the user has to do:

| Trigger | One-time setup | In the moment | Needs |
|---|---|---|---|
| **In-app mic button** | none | Open app, tap, speak | any iPhone |
| **Lock-screen / home-screen widget** | add the widget | Tap from the lock screen | iOS 18 |
| **Control Center control** | add the control | Swipe down, tap | iOS 18 |
| **Action Button** | assign it once | **One press, phone still in hand, no wake word** | iPhone 15 Pro+ |
| **Back Tap** | user sets it in Accessibility | Double-tap the back of the phone | any iPhone |
| **Siri, no wake word** | none | Hold the side button, speak | any iPhone |
| **"Hey Siri"** | none | Fully hands-free | any iPhone |

**The best no-wake-word answer is the Action Button.** Assign it to a Shortcut that dictates text
and passes it to our add intent: one press, say "oat milk", done — without unlocking, without
opening the app, without talking to an assistant. For someone pushing a trolley, that is the
lowest-friction add path that exists on the platform.

**The default path is still the in-app mic button**, because it needs zero setup. That matters
more here than usual: an app designed around task initiation (`INTERACTION.md` §2) cannot depend
on a feature the user has to configure first. So the button and the widget must be excellent, and
everything else is a documented power-user path we support but never rely on.

**One real constraint:** interactive widgets support buttons and toggles only — **no text input.**
A widget can check items off, but "add by typing" from a widget isn't possible; it can only open
the app into add mode. Voice via the Action Button routes around this entirely.

### Three engines: iPhone, Android, Claude API

Checked July 2026, because the Android answer decides what the eventual Android port costs to run
— and it is not the same architecture with different class names.

#### The equivalents, side by side

| Job | iPhone | Android | Claude API |
|---|---|---|---|
| Speech → text, on-device | `SFSpeechRecognizer`, `requiresOnDeviceRecognition` | `createOnDeviceSpeechRecognizer()` (API 33+) — **fails if the OEM ships no local engine** | n/a |
| Assistant runs an in-app action | **App Intents + App Schemas — shipping** | **AppFunctions — private preview, trusted testers, Android 16+** | n/a |
| Assistant does the language parsing | `reminders` schema domain, Siri parses | AppFunctions (same idea, MCP-shaped) — **not GA** | n/a |
| OCR, printed text | Vision | ML Kit Text Recognition — broad device support | n/a |
| Barcode | Vision / AVFoundation | ML Kit Barcode | n/a |
| General on-device LLM | **Foundation Models** (~3B, iOS 26, Apple Intelligence devices) | **Gemini Nano 4** via ML Kit **Prompt API** + Structured Output | n/a |
| Messy handwriting, receipts | — | — | **Claude** |

#### The difference that actually matters is the floor, not the ceiling

On raw capability the two on-device models are comparable — both are small general-purpose LLMs,
both now take structured output. The gap is **who can run them.**

- **Gemini Nano 4 requires 12 GB RAM and a flagship SoC with an AI accelerator.** The mid-2026
  supported list is the Pixel 10 line, the Galaxy S26 series, and a handful of Oppo, OnePlus and
  Xiaomi flagships. That is **low single digits of the global Android install base [estimate]** —
  and it is the *wrong* single digits for a budget-conscious grocery app, whose users skew toward
  cheaper hardware.
- **Android on-device speech is not guaranteed either.** `createOnDeviceSpeechRecognizer()`
  fails outright when the OEM's engine isn't present, and OEMs do replace it.
- **Apple's floor is higher and flatter.** On-device speech, Vision and App Intents work across
  the whole iOS 18 base. Only Foundation Models is gated, and rung 4 was already an enhancement
  rather than a dependency — so on iPhone, one feature degrades. On Android, **the bottom of the
  ladder degrades**, which is a different kind of problem.
- **ML Kit's prebuilt GenAI APIs don't do our job anyway.** They are summarization, proofreading,
  rewriting and image description. "Turn this sentence into grocery items" needs the Prompt API —
  the newest and most device-restricted piece of the stack.

#### What that costs us

**Android cannot replicate the $0 architecture today.** Ported as-is, the same features either
fall back to typing or fall through to Claude — on a platform where, per
`research/competitors.md`, the winner monetises at ~90% advertising. So the Android port carries
a **higher marginal cost per user against a market with lower willingness to pay.** Two
consequences worth deciding before writing any Android code:

1. Android should launch **paid-tier-first, or with a visibly tighter free tier** than iOS. The
   rule — *free tier → on-device only* — is not satisfiable on the median Android device.
2. **AppFunctions going GA is the signal to reassess.** When it ships, Android gets the same
   "the assistant does the parsing" leverage that the `reminders` schema domain gives us on iOS,
   and the port gets materially cheaper. Until then there is no equivalent, and building around
   a private preview would be building on sand.

#### One symmetry worth noticing

Siri is reportedly Gemini-backed now, and Android's assistant is Gemini. **The assistant layer is
converging; the integration contract is not.** App Intents/App Schemas and AppFunctions are
different shapes, so "we support Siri" buys nothing on Android and vice versa. Budget for two
integrations whenever Android happens — not one written twice.

### What this means strategically

The plan already says never to sell "AI" as a headline — Listonic put a "With AI" badge on their
lead screenshot, so it's furniture now. This architecture lets us go further: **we can ship voice
and photo capture with a marginal cost of approximately zero, and market them as speed rather than
as AI.** "Say it and it's on the list" beats "AI-powered" and costs less to run.

---

## 11. Scope: groceries only, or any list?

**Decision: market as groceries, support one deliberately plainer "simple list" type. Never
become a general list app.**

### What the evidence says

Every successful app in this category supports multiple list types:

| App | List types | Result |
|---|---|---|
| **AnyList** | Grocery, to-do, gift ideas, movies to watch, packing | 79K ratings, 4.9★, ~$900k/yr |
| **MinimaList** | To-do app *with* a grocery mode | 46K, 4.8★ |
| **Komorebi** | Titled "Shopping List — Grocery & ToDo" | 29K, 4.8★ |
| **Opulogic** | Grocery, to-do, recipe, "things to buy online" | 1.4K, 4.6★ |
| **Bring!** | Groceries only | 3.6M MAU, but retail-media model in Europe |

**The decisive detail:** AnyList is *named* AnyList and supports five list types — and its App
Store title is **`AnyList: Grocery Shopping List`**. The category leader markets groceries and
supports anything. That's the pattern, and it resolves the debate: this is not a choice between
positioning and capability. **Position narrow, support broad.**

### Why it doesn't break fidelity — if done as a subtraction

Both differentiators are grocery-only: prices and aisle order are meaningless for "movies to
watch." So the second list type isn't a parallel product to design — it's the grocery list with
features *removed*:

| | Grocery list | Simple list |
|---|---|---|
| Add + check off | ✓ | ✓ |
| Household sharing | ✓ | ✓ |
| Offline | ✓ | ✓ |
| Catalog autocomplete | ✓ | — |
| Aisle grouping | ✓ | — |
| Prices, subtotals, total | ✓ | — |

That's **less code and less UI**, not more. It ships almost free because lists are already a
first-class entity with sharing, sync and offline built in — a simple list is a flag that turns
three things off.

### The rules that protect fidelity

1. **Store positioning is 100% groceries.** Title, subtitle, keywords, all six screenshots. The
   simple list is never marketed and never appears in a screenshot
2. **Grocery is the default** on first run. Creating a grocery list takes zero decisions
3. **No mode switcher in the main UI.** Type is chosen once at list creation and never surfaces again
4. **No tab bar.** The list is still the app (§6)
5. **Zero further investment.** No movie metadata, no packing templates, no due dates, no
   reminders, no assignees, no projects, no priorities. If someone asks for those, the answer is
   permanently no — that's the work-tool failure mode already banned in §7

### What we are refusing

The failure your instinct is pointing at is real, and it has a name: **becoming a general
productivity app.** That happens by accretion — a due date here, a priority flag there — until the
grocery experience is a mode inside something generic, and the app is worse at everything than the
specialists. Todoist is better at tasks than we will ever be. AnyList is better at recipes.

So: one narrow, excellent grocery app, plus a plain list for the times a household needs one.
Less, on purpose.

---

## 12. What works and what doesn't — from competitor screens

Drawn from `research/store-teardown.md`. Adopt the left column; refuse the right.

### Works — adopt

| Pattern | Where seen |
|---|---|
| Big bold caption above a device mockup | All five listings |
| **Colour carries state**, not decoration | Bring! — coral = needed, green = recently used |
| **Light and dark mode in one screenshot** | Bring!, OurGroceries. Doubles as a craft signal |
| **Per-category subtotals + trip total** | MinimaList. The best single idea in the category |
| **"I need …"** as the add-field placeholder | Bring!. Beats "Add an item" |
| **Interactive widget checkbox** — tap without opening the app | Komorebi |
| Attribution as a small caption under the row | Amazon Alexa, Telegram |
| Per-item notes ("Honeycrisp or Envy") | OurGroceries |
| Progress as plain text ("5 of 6 items remaining") | AnyList |
| Award/editorial badge as social proof | Listonic |

### Doesn't work — refuse

| Pattern | Why |
|---|---|
| **Icon-only tiles** | Bring!'s known weakness: breaks on long or unusual items. Our text label is always primary |
| **Dense to-do UI** | Todoist/Trello density is unreadable at arm's length in a store |
| **Tab bars** competing with the list | Erodes "the list is the app" |
| **"With AI" badges** | Table stakes since Listonic used one. Now noise |
| **3D mascots** | Works commercially — Listonic is Apple-featured — but off-brand for us (§7, knowingly) |
| **Typos in store assets** | Listonic shipped "Wasihing liquid" on the #1 app. Free credibility to take |
| **Stale screenshots** | Opulogic still shows a pre-iOS 11 "Carrier" status bar |
| Assignment UI — owners, due dates, roles | The work-tool failure mode |
| A price on every row at launch | Unrealistic. Unpriced renders `—`, and the total waits |

### Known gap, stated honestly

**AnyList and OurGroceries both use real product photography** per item. We ship emoji. That is a
visible deficit against the two largest competitors, not a considered win — treat commissioned
item art as the first funded upgrade once there's revenue.
