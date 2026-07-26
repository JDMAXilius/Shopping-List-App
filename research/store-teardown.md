# App Store listing teardown

Analysis of competitor App Store pages from screenshots. **Batch 1 — more expected.**

Source images live in the session upload folder, not committed: they're Apple App Store
marketing assets owned by the respective developers, and this repo may go public.

---

## Batch 1 — what was captured

| # | App | What the screen showed |
|---|---|---|
| 1 | Unnamed minimalist checklist | "Lock Screen — lock-screen widgets and wallpaper lists" |
| 2 | **Listonic** | Full store page: metrics, icon, first two screenshots |
| 3 | Listonic (or sibling) | "Turn any photo into a list" — camera over a handwritten recipe |
| 4 | Teal list app (unidentified) | "Simplify your shopping experience" |
| 5 | **Bring!** | "The simplest shopping list for sharing" |

---

## 1. Listonic — hard numbers off the store page

| Field | Value |
|---|---|
| Title | `Grocery List - Listonic` |
| Subtitle | `Shared Shopping for the Family` |
| Ratings | **10K ratings, 4.7 ★** |
| Category | **Productivity** (not Food & Drink) |
| Price | Free + In-App Purchases |
| Age | 4+ |
| Badge | **"Apple — This Week's Favourites, Apps We Love 2026"** |

Four things worth acting on:

**Apple is actively featuring this category in 2026.** That editorial badge is not a
self-awarded claim — it means the App Store team promoted a grocery list app this year.
Editorial featuring is a real, free acquisition channel in a category where paid acquisition
doesn't clear (`MARKET.md` §4), and it means the design bar for a feature is worth hitting.

**They sit in Productivity, not Food & Drink.** Worth a deliberate decision rather than
inheriting. Productivity is more competitive but is where the incumbents' ranking history lives;
Food & Drink is thinner and might be easier to chart in. Test, don't assume.

**Their subtitle is `Shared Shopping for the Family`** — pure keyword real estate: *shared*,
*shopping*, *family*. It confirms the §6 approach in `BRAND.md` of spending the subtitle on
fresh keywords, and it means "shared" and "family" are contested by the volume leader.

**Their own screenshot contains a typo** — "Wasihing liquid" — shipped into store assets on the
#1 app with 10K ratings. The craft bar in this category is lower than the download numbers
suggest. That's an opening, not a licence to be sloppy.

## 2. "With AI" is now table stakes, not a differentiator

Listonic's first screenshot puts a gradient **"With AI"** badge directly under "#1 Grocery
List App." The category leader is leading with AI in its primary screenshot.

Consequence: shipping "AI" as a headline claim buys nothing now — it's expected furniture. The
`RESEARCH.md` §4 Tier 2 framing of AI features as differentiators needs downgrading. What still
differentiates is a *specific outcome* ("know what the trip costs"), not the technique.

## 3. "Turn any photo into a list" — the timeline problem

Screenshot 3 shows a camera pointed at a **handwritten recipe card**, with corner brackets
detecting the text and a highlighted line being pulled out as an item. Handwriting → structured
list, shipped.

This matters more than it looks:

- It's a genuinely strong feature I had not scoped anywhere.
- It is the **same camera + OCR + parse pipeline as receipt scanning.** A competitor who ships
  photo→list is a short step from receipt→prices.

`RESEARCH.md` treats receipt scanning as our moat-builder and `MARKET.md` treats the price book
as unclonable. Both still hold for the *accumulated data*, but **the capability lead is thinner
than I implied** — this is weeks of work for Listonic, not years. The defensibility is the
history, not the feature.

## 4. Still nobody shows a price or a total

> ### ⚠️ WRONG — overturned by batch 2. See §10.
> **MinimaList** (46K ratings, 4.8 ★) leads its shopping-list screenshot with per-item prices,
> **per-category subtotals**, and a **`Total $65.97`** trip total. I called this the
> strongest-supported finding in the research set; it was the weakest-checked. The refined
> version of the claim is in §10 — it survives, but much narrower.

Across all five listings — Listonic, Bring!, the teal app, the minimalist app — **not one
screenshot shows a price, a running total, or a spend figure.** The territory identified in
`BRAND.md` §2 as unclaimed is, on this evidence, genuinely unclaimed in store marketing.

## 5. Bring! — the sharing screenshot

"**The simplest shopping list for sharing**" / footer: "*Save time, money & nerves*".

- Mint background, **coral/salmon tiles for items on the list**, muted green tiles for
  "Recently Used" — so colour carries state, same principle as our confirmed/estimated rule.
- Hand-drawn line illustrations on every tile, on a 3-across grid.
- Search field reads "**I need …**" — first person, and better than our "Add an item…".
- Real **photo avatars** for household members, stacked.
- Tabs: Shopping · Inspiration · Profile.
- **Light and dark mode shown in the same screenshot**, overlapping. Confirms dark mode is
  table stakes, and doubles as a craft signal.

## 6. Colour — a correction to `BRAND.md` §2

I wrote that the category is "overwhelmingly green" and that a warm non-green palette
differentiates. More precisely, from these five:

| App | Base | Accent |
|---|---|---|
| Listonic | Green | Blue |
| Bring! | Mint | **Coral / salmon** |
| Teal app | Teal | **Coral** |
| Minimalist app | Lavender | Purple |

The pattern is a **cool base with a warm coral accent** — and our persimmon `#C9502C` is in the
same family as those corals, just earthier. So the accent does *less* differentiating work than
I claimed. **The differentiation is carried by the warm paper base** (`#F6F4F1`), which nothing
here uses — every one of these sits on a saturated colour field.

Worth keeping persimmon; worth not believing it's the distinctive part.

## 7. Mascots work here, which is inconvenient

Listonic's lead screenshot is a **3D caped broccoli pushing a shopping cart**. That is precisely
the "cartoon vegetable" banned in `BRAND.md` §1. It is also the #1 app in the category, 4.7 ★
over 10K ratings, with an Apple editorial feature this year.

Honest framing: **the no-mascot rule is a positioning bet, not a best practice.** Character-led
branding demonstrably works in this category. The argument for holding the line is that the
brand is built on credibility about money — grey is a guess, green is a fact — and a mascot
undercuts the register that makes the spend claim believable. That's a real argument, but it is
a *choice with a cost*, and it should be made knowingly rather than inherited from a document.

## 8. New feature vector — lock-screen and glanceable list

Screenshot 1's app leads with **lock-screen widgets and wallpaper lists**. The app itself looks
low-quality — the copy is machine-translated ("Minimalist agency is a tomato clock" is a
Pomodoro timer) — but the idea is strong for our use case specifically:

**A lock-screen widget showing the current list is the correct answer to a supermarket.** No
unlock, no app launch, one glance while pushing a cart with both hands. It pairs with the
offline requirement — both are about the app working in the aisle rather than on the sofa.

Add to `RESEARCH.md` §4 Tier 1: lock-screen widget, plus Home Screen widget and a Watch
complication as the same family of work.

---

## Actions this batch generates

1. **Downgrade AI** from differentiator to table stakes in `RESEARCH.md` §4.
2. **Add lock-screen / glanceable widget** to Tier 1 features.
3. **Re-frame receipt scanning** — the moat is accumulated price history, not the capability.
4. **Correct `BRAND.md` §2 colour claim** — warm paper base differentiates, coral accent doesn't.
5. **Flag the mascot decision** as an explicit bet with a cost.
6. **Decide store category** — Productivity vs Food & Drink — deliberately.
7. **Steal "I need …"** as the add-field placeholder; it beats "Add an item…".
8. Editorial featuring is a live channel — design to be featurable.

## Still to capture

- Listonic's remaining screenshots and full description text
- AnyList and OurGroceries full store pages
- Any listing that *does* show prices or totals, to test the §4 finding
- Paywall / upgrade screens, to verify the pricing in `MARKET.md`
- Onboarding flows — especially how any of them handle joining a shared list


---

# Batch 2

| # | App | Developer | Ratings | Score | Category |
|---|---|---|---|---|---|
| 6 | **Shopping List — Simple & Easy** | Opulogic Inc. | 1.4K | 4.6 | Shopping |
| 7 | **AnyList: Grocery Shopping List** | Purple Cover, Inc. | **79K** | **4.9** | Productivity, **#197** |
| 8 | **Shopping List — Grocery & ToDo** | Komorebi Inc. | 29K | 4.8 | Shopping |
| 9 | **Our Groceries Shopping List** | OurGroceries, Inc. | **84K** | 4.8 | Shopping |
| 10 | **To Do List MinimaList & Widget** | InnerGrow | 46K | 4.8 | Productivity, **#198** |

---

## 10. Correction: cost is *not* unclaimed

MinimaList's **first screenshot is a shopping list**, captioned "Shopping List — Your grocery
list, simplified," and it shows exactly the feature set I said nobody markets:

```
Grocery List ˅                    6/12        Total $65.97
🥬 Fresh Produce                            total $18
   ☐ Tomatoes                                     $7
   ☐ Bananas                                      $5
   ☐ Apples                                       $6
🥩 Meat & Seafood                          total $17.99
   ☐ Ground beef                                $9.99
   ☐ Chicken wings                             $8.00
🧈 Dairy & Eggs                            total $12.99
   ☐ Cheese                                    $3.00
   ☑ Yogurt                                    $4.00
   ☑ Milk                                      $5.99
```

Per-item prices, **per-category subtotals**, and a running trip total — from a general-purpose
list app with 46K ratings at 4.8 ★, charting at #198 in Productivity.

### What survives

The claim has to narrow to something defensible:

- **No dedicated grocery-list incumbent leads with cost.** AnyList (79K/4.9), OurGroceries
  (84K/4.8), Listonic (10K/4.7) and Bring! all lead with *sharing*. That's still true and still
  the positioning gap.
- **MinimaList is a to-do app with a grocery mode**, not a grocery app. It owns the *feature*,
  not the *category position*.
- Its prices look **manually entered** — the mix of round ($7, $5, $6) and precise ($9.99,
  $5.99) values reads as hand-typed, not seeded or scanned. No estimated-versus-observed
  distinction is visible, which is the part our design actually turns on.
- No per-store aisle ordering; category grouping only.

### What it costs us

The per-category subtotal is a genuinely good idea I hadn't considered, and it's better than
what I mocked up — "Produce $18, Meat $17.99" tells you *where* the money went, not just the
total. Worth adopting.

And a competitor shipping this proves demand rather than only threatening us — but "nobody does
this" can no longer appear in positioning copy. The honest line is *no grocery app does this*,
and the differentiator has to rest on the parts MinimaList doesn't have: seeded estimates so the
total works on trip one, observed-vs-estimated honesty, and per-store aisle order.

## 11. Scale — Listonic is not the volume leader in the US

`MARKET.md` treats Listonic as the category volume leader on its own claims (13M downloads,
20M+ users). US App Store ratings tell a different story:

| App | US ratings |
|---|---|
| OurGroceries | **84K** |
| AnyList | **79K** |
| MinimaList | 46K |
| Komorebi Shopping List | 29K |
| **Listonic** | **10K** |

Listonic's numbers are global and evidently Android-weighted. **On iOS in the US, AnyList and
OurGroceries are roughly 8× larger.** If iOS-first is the plan, they are the competitors that
matter, and both lead on *sharing* and *reliability* rather than ads — so the "ad-free" wedge is
aimed at a player who isn't dominant on the platform you'd launch on.

That weakens "ad-free" as the primary wedge on iOS and strengthens cost + aisle intelligence.

## 12. The quality bar is 4.6–4.9

Every app in both batches sits between **4.6 and 4.9**, with AnyList at 4.9 over 79K ratings.
There is no mediocre-but-successful app here. Shipping at 4.3 would place you visibly last.

## 13. Store category is genuinely split

- **Productivity:** AnyList (#197), MinimaList (#198), Listonic
- **Shopping:** OurGroceries, Komorebi, Opulogic

No convention to inherit — it's a real test. Note that #197 and #198 in Productivity are both
list apps, so that neighbourhood of the chart is winnable and visible.

## 14. AnyList — correction to `RESEARCH.md` §3

`RESEARCH.md` gap #2 claims "AnyList can't filter a list by store," sourced from a review
roundup. The screenshot contradicts it: an item reads **`Salmon — Trader Joe's`**, so per-item
store tagging exists. Whether the *list* can be filtered by store is still unverified, but the
gap as written is unsafe and needs testing in the app before it appears in any positioning.

Also visible in AnyList, and worth noting:

- **Real product photos** per item, not emoji — eggs, light bulb, broccoli, sweet potatoes.
  A commissioned or licensed image set is table stakes at the top of this category, which raises
  the bar on our emoji-tile decision.
- **Recipe provenance on the item:** `Sweet Potatoes (1 lb) — for Roasted Sweet Potatoes`.
- **`Order Pickup or Delivery`** button — the retailer/affiliate handoff `RESEARCH.md` §6 lists
  as a secondary revenue idea is already shipped by the category leader.
- Header shows `5 of 6 items remaining` — progress as text, not a chip.
- Icon row: star (favourites), clock (recents), eye, filter.

## 15. Interactive widgets are shipped, not novel

Komorebi's Shopping List (29K, 4.8) leads with **"Widgets"** and shows a lock-screen widget
whose checkboxes are **tappable without opening the app** — the caption inside the screenshot
literally reads "←You can tap this checkbox."

The Tier 1 widget item added after batch 1 is therefore *catching up*, not differentiating.
It's still required — a glanceable, tappable list is right for a supermarket — but price it as
table stakes.

Their second screenshot also shows inline autocomplete: typing `chocola` surfaces `chocolate`.
Confirms the catalog/resolver work is the correct baseline investment.

## 16. OurGroceries — marketing palette is magenta

Their screenshots run on **magenta/purple** while the app UI is green, and they show light and
dark mode side by side, same as Bring!.

Second correction to the colour thesis: the *marketing* palettes in this category are more
varied than the app palettes (magenta, blue, mint, teal, lavender, crimson-yellow). Our
differentiation genuinely rests on the **warm paper base in the product**, not on owning a hue
in store assets.

Their subtitle — `Share lists easily with family` — is the third of five to build the subtitle
around *share* + *family*. Those two words are thoroughly contested; our subtitle should not
compete for them.

## 17. Low end of the market

Opulogic's Shopping List — Simple & Easy (1.4K, 4.6) still ships screenshots with a
**"Carrier" status bar**, meaning assets predating iOS 11 or so. Crimson-and-yellow, emoji
appended to item text, "Type here then press the + button."

Useful as a floor: apps this dated still hold 4.6 and paying users, so the category tolerates
weak craft in the tail. It's not a strategy, but it means the bar to be *credible* is lower than
the bar to be *featured*.

---

## Revised actions

1. **Remove "nobody shows cost" from all positioning copy.** Replace with "no grocery app does."
2. **Adopt per-category subtotals** — MinimaList's best idea, better than my mockup.
3. **Re-target the competitive set to AnyList and OurGroceries** for an iOS launch, not Listonic.
4. **Demote "ad-free" from primary wedge on iOS** — the ad-heavy competitor is small there.
5. **Verify the AnyList store-filtering gap in the app** before relying on it.
6. **Reprice widgets as table stakes**, not a differentiator.
7. **Revisit emoji tiles** — the two largest competitors both use real product imagery.
8. **Avoid *share* and *family* in the subtitle** — three of five competitors own them.
9. Quality gate: ship at **4.7+ or don't ship**.
