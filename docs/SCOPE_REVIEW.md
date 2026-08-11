# Is 59 screens too many? — researched against what shipped apps actually do

Three questions: **do other apps have these features · is 59 screens normal · what should v1 be.**

---

## 1. First, an honest recount — 59 is not 59

`Bagged · Screens` has 59 Figma frames. They are not 59 app screens:

| Kind | Count | Are they screens? |
|---|---|---|
| **Navigable screens** | **33** | Yes — a SwiftUI view with navigation |
| **Sheets / modals** | **9** | Yes, but cheaper — presented, not navigated |
| **Non-app surfaces** | **5** | **No.** Lock screen, widgets, Watch, CarPlay, Live Activity are *previews of other targets* |
| **States & primers** | **9** | **No.** Empty, offline, scan-failed, processing, 3 permission primers — states of screens that already exist |
| **Explainer / marketing** | **3** | **No.** Splash, value showcase, first fill |

**So: 42 real view surfaces, 33 of them navigable.** The other 17 are honest work — states and
surfaces are the stuff nobody designs and everybody needs — but they shouldn't be counted as
screens when judging scope.

**42 is still a lot.**

## 2. What the comparison actually says

### Flows in shipped grocery apps are 2–4 screens. Every one.

From Mobbin, iOS, July 2026:

| App | Flow | Screens |
|---|---|---|
| Yazio | Checking off items | **3** |
| Yazio | Adding to grocery list | **2** |
| Amazon Shopping | Manage list | **3** |
| Amazon Shopping | Shopping list | **4** |
| Centr | Checking items in shopping list | **2** |
| Instacart | Checking off an item | **2** |

**The core interaction of this entire category — put a thing on a list, tick it off — is a
two-screen flow in every shipped app that does it.** Our D-flow is 7 screens.

That isn't automatically wrong: none of those apps carry prices, aisle order per store, or a
price book. But it sets the bar for what the *core loop* should cost.

### Instacart already ships our total

> `$10.98 Est. total` · `$4.50 est. savings` — pinned to the bottom of the shopping list, with
> per-item strikethrough original prices.

**A shipped app at Instacart's scale puts an estimated total and a savings figure on a grocery
list.** That's a second data point against "nobody shows prices" — after MinimaList — and it's
worth studying as an existence proof rather than treated as competition, since Instacart's is
retailer data, not your receipts.

### App Store screenshots: 3–5, and the first 3 decide it

- **Maximum 10 per device size. Three to five is the practical sweet spot.**
- **The first 3 drive ~60% of install decisions.** The first **2** appear in search results before
  anyone taps through.
- Most users never scroll past the third.

**So the answer to "how many pictures" is: you need 5, and only the first 3 matter.** 59 designed
screens produce, at most, five that anyone will see before deciding. That reframes the whole
scope question — **the marketing surface is 3 screens wide, not 59.**

## 3. ⚠️ The pantry research — this is the important part

Two findings, and they cut in opposite directions.

### Good: the spec's core idea is the documented right answer

> **"Front-loading a full manual inventory is the main reason people abandon pantry apps in the
> first place."**

The spec's answer — *"One photo · every line · about 6 seconds"* — is precisely the fix for the
#1 documented abandonment cause. And the category agrees: *"receipt scanning and barcode scanning
have become central to modern pantry apps' retention strategies."*

**That validates the loop. It is not a novel idea — it's the current standard answer — but it is
the right one.**

### Bad: it solves the *setup* problem and not the *decay* problem

> **"Most food trackers feel like a chore because you have to log every single apple and milk
> carton."**
> **"If you are not disciplined enough to keep a manual inventory current, the inventory drifts
> out of sync within weeks."**

**Receipt scanning fills the shelf. Nothing empties it.** You scan a receipt, 14 things appear —
and then you eat them, and the app doesn't know. Within weeks the shelf says you have spinach you
ate last Tuesday, and **an inventory you can't trust is worse than no inventory**, because now
every screen built on it is lying.

`B2` shows *"About 72% left · runs out in ~5 days."* **Nothing in 59 screens explains how the app
knows**, and the research says this exact gap is where these apps die.

**This is now the single biggest risk in the project** — bigger than the name, bigger than the
cost wedge — because the Shelf is the first tab and four other screens depend on it.

### Three ways out, and only one is good

| Approach | Verdict |
|---|---|
| **User logs consumption** | ❌ The documented chore. This is the thing that kills these apps |
| **Infer from purchase cadence** | 🟡 *"You buy milk every 5 days, it's been 6"* — needs history, works from ~trip 3, and never needs the user to log anything. **Our recurring-staples idea already did this** |
| **Don't model depletion at all** | ✅ **The shelf is a record of what you bought and when, not a claim about what's left.** No percentages, no "5 days". "Bought 26 Jul" and an expiry guess is honest and needs no tracking |

**Recommendation: drop "About 72% left" and every "runs out in ~N days".** They are the only parts
of the Shelf that require data we can't get. Everything else — what you bought, when, where,
what it cost, roughly when it expires — comes free from the receipt.

## 4. Are all these features necessary?

| Feature | Do competitors ship it? | Necessary for v1? |
|---|---|---|
| List, aisles, check off | Everyone | **Yes** |
| Shared household | AnyList, OurGroceries, Bring | **Yes** — it's the growth loop |
| Offline | Everyone | **Yes** |
| Prices on items | **Nobody in grocery.** Instacart and MinimaList do | **Yes — it's the whole bet** |
| Receipt scan | Flipp (rebates), pantry apps | **Yes** — it's the engine |
| Price history per item | Nobody | **Yes** — cheap once receipts exist |
| Store comparison | Basket, Flipp, GroceryChop | **No** — needs 2 stores × receipts. v1.1 |
| Shelf / pantry | NoWaste, Pantry Check, Kitchentory | **No** — see §3 |
| Expiry tracking | Pantry apps | **No** — needs shelf-life data we don't have |
| Budgets | Some | **No** — unspecified, and risks scolding |
| Widgets | Komorebi | **Yes, one** — lock screen. It's table stakes |
| Watch · CarPlay · Live Activity | Rare | **No.** Three targets for a tiny audience |
| Siri | AnyList, Listonic | **Yes** — free to run, and gating it saves nothing |
| Per-member permissions | Nobody | **No** — v2. Elegant, but nobody is asking |
| Categories, trips, month, category detail | Some | **One of them, not four** |

## 5. What v1 should be

**14 navigable screens, 5 sheets, 6 states. Roughly a third of the spec.**

| # | Screen | Why |
|---|---|---|
| 1 | **List** | The product |
| 2 | Item detail + price history | Where a price gets set |
| 3 | Aisle order | Differentiator #2 |
| 4 | **Receipt camera** | The engine |
| 5 | **Receipt review** | Trust. Never commit unreviewed |
| 6 | **Unmatched line resolver** | Where the catalog learns |
| 7 | Capture result | Closes the loop |
| 8 | Spend — *one* screen | Month + by store. Not four |
| 9 | Kitchen home | Members |
| 10 | Invite | The growth loop |
| 11 | Setup | — |
| 12 | Data & privacy | The positioning pillar, and it's cheap |
| 13 | Onboarding — name + first shop | Two steps, not six |
| 14 | Paywall | — |

**Sheets:** add item · edit item · capture chooser · shop switcher · barcode
**States:** empty list · all done · offline · scan failed · processing · camera primer

**Cut from v1:** the entire Shelf flow (7) · Watch, CarPlay, Live Activity, home widgets (4) ·
store comparison · trips, trip detail, category detail (3) · member detail · guest view · places ·
add/edit shop · voice settings · notifications · about · value showcase · two permission primers.

**Keep the cut work.** It's designed, it's good, and it becomes v1.1 and v1.2 without redesign.

## 6. Three screens from other apps worth stealing

1. **Instacart · shopping list** — the bottom bar carrying `Est. total` *and* `est. savings`
   together, with strikethrough original prices per item. That is our total bar and our
   cheaper-elsewhere nudge combined into one component, shipped and proven at scale.
2. **Amazon Fresh · manage list** — `COMPLETED (3)` as a collapsed section, plus a
   **`SUGGESTED FOR YOU` grid** of tappable common items. The grid is recognition-over-recall,
   which is the ADHD argument in `INTERACTION.md`, executed by Amazon.
3. **Yazio · grocery list sheet** — five rows, checkboxes, three actions, a Close button. It is
   the whole feature as a **sheet, not a tab**, and it's a useful reminder of what the floor
   looks like.

## 7. The answer, in three lines

- **59 frames is 42 real surfaces, and 42 is about 3× a sensible v1.** Ship ~19, keep the rest.
- **Every feature in the spec exists in some app. No app has all of them** — and the ones that
  tried to do inventory *and* lists are the ones with the abandonment problem.
- **The Shelf is the risk, not the scope.** Fix it by making it a record of what you bought
  rather than a claim about what's left — or cut it from v1 and let the price book carry the app.

## Sources

- Mobbin, iOS flows, July 2026 — Yazio, Amazon Shopping, Centr, Instacart grocery-list flows
- [App Store screenshots: the first three drive ~60% of installs](https://screenhance.com/blog/state-of-app-store-screenshots-2026)
- [App Store screenshot guidelines 2026](https://theapplaunchpad.com/blog/app-store-screenshot-guidelines/)
- [Best pantry inventory apps, tested](https://fango.fi/en/blog/best-pantry-inventory-app/)
- [Pantry tracking apps compared](https://recipyapp.com/blog/best-pantry-tracking-apps-2026)
