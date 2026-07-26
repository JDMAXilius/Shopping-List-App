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

Across all five listings — Listonic, Bring!, the teal app, the minimalist app — **not one
screenshot shows a price, a running total, or a spend figure.** The territory identified in
`BRAND.md` §2 as unclaimed is, on this evidence, genuinely unclaimed in store marketing.

This is now the strongest-supported finding in the whole research set.

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
