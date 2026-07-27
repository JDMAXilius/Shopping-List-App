# Tiimo — deep teardown

**Why this app and not another:** Tiimo won **iPhone App of the Year at Apple's 2025 App Store
Awards.** It is a neurodivergent-first planner, built by and for ADHD and autistic people, and it
is the closest existing thing to the sensibility this project is aiming at. Apple's editorial team
just declared that sensibility best-in-class.

**Method and its limits.** Screens are real, from Mobbin's Tiimo library (July 2026), plus Tiimo's
own writing and press coverage. **Static screens cannot show motion timing, easing curves, haptic
patterns or actual sound design.** Where I'm inferring, I say so. Everything unmarked is visible
in a screenshot or stated by Tiimo.

---

## 1. Atmosphere — what it feels like before you read a word

**It does not look like a productivity app. It looks like a magazine.**

- **Warm off-white paper**, not clinical white, with **lavender gradients** bleeding up from the
  bottom of the screen. The gradient is atmospheric — it isn't attached to any component
- **Loose single-weight line illustrations** of human figures tangled up with flowers, drawn in
  black on lavender. Hand-made, slightly awkward, deliberately not corporate-flat-vector and
  definitely not 3D-blob
- **Lavender/periwinkle** as the primary accent, with **black** for primary buttons — soft
  atmosphere, confident actions
- Logo: a circle containing a single smile curve. Wordmark is lowercase geometric sans

**The overall register is calm, literary and slightly handmade.** Productivity apps default to
blue, grids, and competence. Tiimo defaults to paper, curves, and warmth. That gap is the brand.

---

## 2. Typography — the single most stealable idea

**A large serif display face against a small sans body.**

- Headers are serif and *big*: `Focus`, `Tuesday`, `What's your biggest need right now?`,
  `Sign up with email`, `Bring your friends!`
- Body, labels, chips, times: small clean sans
- **The countdown numerals are in the serif** — `14:55`, `31:12`, `09:59`. Not monospace, not
  tabular tech-numerals. This is the detail that most changes the feel: a timer usually reads as
  *machine*, and theirs reads as *book*
- Date subtitle in small sans directly under the serif day name: `Tuesday` / `January 20th, 2026`

**Why it works:** serif signals *considered, unhurried, human*. In a category where everyone uses
SF or Inter, one type decision does more brand work than a colour palette. **It is also free.**

---

## 3. Colour — semantic, and tied to the time of day

Section headers are tinted pills that map to circadian feel rather than to a brand palette:

| Section | Tint |
|---|---|
| `ANYTIME` | neutral grey |
| `MORNING` | warm peach |
| `AFTERNOON` | pale blue-lilac |
| `EVENING` | deep purple |
| `DONE` | grey, collapsed |

Per-item icons sit on **pastel circular tiles** — butter yellow, mint, peach, pink, lilac — each
holding a single **emoji**, not a photograph. *(Worth noting for `SOURCING.md`: the App of the
Year winner uses emoji on coloured discs, not product photography, and it looks premium.)*

**Dark mode is true black**, cards drop to dark grey, and the section tints survive but desaturate.
The serif headline goes white and gets *more* dramatic, not less.

---

## 4. The core mechanic — making time physically visible

This is Tiimo's whole idea, and it's executed three ways:

1. **The timeline** — real clock times down the left edge, coloured vertical bars beside each task
2. **Quantified gaps** — the part most apps would leave blank:
   `11h 50m → No plans` · `2h 7m → Time left of day`, joined by dotted connectors.
   **Empty time is rendered as a measured quantity rather than as absence.** For time blindness
   that is the entire product in one row
3. **The focus ring** — a thick coloured arc that depletes around a pastel disc with the task's
   emoji at its centre. Setting a duration uses a circular dial with tick marks and `15 MINS` in
   the middle

**The transferable idea isn't the timeline — it's that the thing users can't perceive gets a
visual body.** Ours is *money*, and the equivalent is the running total: not a number in a corner,
but the thing the screen is organised around.

---

## 5. Interaction details worth stealing

| Detail | What it does | Why it's good |
|---|---|---|
| **`+1 min` beside pause** | Extends the timer by a minute, one tap | **Assumes your estimate was wrong and makes being wrong cheap.** No re-entering a picker, no admission of failure. The most ADHD-literate button in the app |
| **Dashed-outline empty slots** | `Anytime today works` · `What's happening today?` · `End the day your way` | An empty slot looks like *a slot*, not a void. Invitation instead of blankness — and the copy is warm, not instructional |
| **Pinch to switch views** | Two-finger pinch toggles timeline ↔ list | Taught by one dismissible coach card, then invisible. A gesture, not a segmented control taking up permanent space |
| **Collapsible sections with counts** | `MORNING (3) ⌄` | Cognitive load control the user operates. Collapse what isn't now |
| **Progress pill, always visible** | `🎉 3/8` top-left | Never makes you count what's left |
| **Live Activity** | Black pill on the lock screen with the emoji, timer, `+1` and pause | The session is controllable **without opening the app** |
| **Nested subtasks with `0/4`** | `Morning routine` expands to Wake up / Brush teeth / Breakfast | Big task → small steps, inline, no navigation |
| **`DONE (1)` collapsed section** | Completed items strike through and move down | They persist and stay checkable — object permanence without clutter |
| **Dismissible nudge cards** | `Add smart widgets — 2 MIN →` with an X | Suggests setup, with a time cost stated, and takes no for an answer |

---

## 6. Motion, sound, haptics — and the honest limits

### Sound and music — **yes, there is music**

The Focus screen header carries a chip reading **`♪ Groovy Beats`** with an equaliser icon, and
elsewhere **`Tune in ♪♩`**. **Tiimo ships named focus-music tracks inside the app.**

> ⚠️ One comparison article states Tiimo "does not offer ambient sounds." **The screenshots
> contradict it** — the article is either stale or wrong. Screens beat secondary sources.

### What Tiimo says about their own sensory design

From their sensory-design writing, they build with **"light emissions, motion patterns, haptic
feedback, and audio cues"** as deliberate cognitive-processing supports, and they explicitly avoid:

- **harsh alarms**
- **guilt-based notifications**
- **red failure marks** — *"offering just feedback instead"*

> **That last line is the most important sentence in this whole teardown**, and it comes from the
> App of the Year winner. It is precisely the anti-guilt, no-streaks, no-red-badges stance in
> `INTERACTION.md` §2 — independently arrived at, and commercially validated at the top of the
> App Store.

### Motion — one clear observation, and one honest gap

**Observed:** the focus timer sits in an **ambient particle field** — small crescent moons,
petals and confetti-like shapes drifting around the ring, varying by theme.

**This contradicts the rule in `INTERACTION.md` §3** — *"nothing moves that the user didn't
cause."* The contradiction is real and worth resolving rather than ignoring:

**Context decides it.** Tiimo's particles live on a screen you *stare at for fifteen minutes*
while deliberately not doing anything else — ambient motion there is atmosphere, and it gives the
eye somewhere to rest. A grocery list is a **ninety-second, one-handed, standing-in-an-aisle**
interaction. Ambient motion there is noise.

**So the rule stands for us, but it should be stated as context-dependent rather than absolute.**

**Cannot determine from static screens:** animation durations, easing curves, spring parameters,
transition choreography, the specific haptic patterns, or what the sounds actually sound like.
**Those need the app on a device.** *(Recommended: an hour with Tiimo installed, specifically
noting what haptic fires on task completion and whether a sound accompanies it.)*

---

## 7. Onboarding — admirable, and mostly not for us

16 screens. Splash with **Apple Design Award 2024 Finalist** laurels → email sign-up → *"What's
your biggest need right now?"* (5 options + *Something else*) → social proof *"You're part of more
than 500,000 happy Tiimo users"* → calendar import → widget nudge → the plan.

**Good:** the need-selection question personalises the first session *and* segments their market
in one tap. Wearing the awards on the splash is confident and earns trust immediately.

**Not for us.** Sixteen screens and a **mandatory account** before you see anything is the
opposite of `INTERACTION.md`'s task-initiation principle. Tiimo can charge that toll because
they're a *planner* — you arrive intending to set up a system. Someone opening a grocery list
wants to type "milk" **right now**, and any wall before that is where they leave.

**The rule this sharpens for us:** *setup cost must be proportional to session length.* A planner
earns a setup ritual. A list app has ninety seconds and must spend them all on the list.

---

## 8. What we take, what we leave

### Take

1. **Serif display against sans body.** The cheapest, highest-impact brand decision available, and
   the category doesn't do it. Our totals should be set in it too — `≈ $84` in a serif reads as a
   figure in a ledger, not an error message
2. **Emoji on tinted discs looks premium.** The App of the Year winner does exactly this. It
   materially weakens the "we need product photography" argument in `SOURCING.md` — **reconsider
   before spending on 414 generated images**
3. **Dashed empty slots with warm, invitational copy.** Directly applicable to an empty list and
   to unpriced items
4. **`+1 min` as a philosophy** — make being wrong cheap and unembarrassing. Ours: correcting a
   wrong estimated price should be one tap from the row, never a settings journey
5. **Semantic section tinting.** Ours is aisle categories rather than time of day, but the
   principle — tint carries meaning, not decoration — transfers exactly
6. **Progress always visible.** `🎉 3/8` ≈ our `2 of 7 remaining` and the running total
7. **Collapsible sections with counts.** Let the user hide the aisles they've finished
8. **Live Activity.** A shopping trip is *exactly* a session: items remaining and a running total
   on the lock screen. **We had this as a widget only — Tiimo shows the session framing is
   stronger.** New idea, worth adding
9. **Wear the awards.** If we're ever featured, it goes on the splash

### Leave

1. **Long onboarding and mandatory accounts.** Fatal for a list app
2. **Ambient particle motion.** Right for a 15-minute focus screen, wrong for a 90-second aisle
3. **The floating mascot.** Theirs is an AI assistant button, and it partially obscures content in
   nearly every screenshot. `BRAND.md`'s mascot caution holds
4. **Their feature set.** They're a planner: courses, podcasts, body doubling, community. That is
   the "deck of trade of all" outcome this project explicitly refuses

---

---

## 8b. ⚠️ Update — the current build, and a correction

Screenshots of the live app (July 2026) show a build **materially newer than Mobbin's library**,
and it **overturns one of my confident claims above.**

### The correction I have to make

In §6 I wrote that Tiimo's *"no red failure marks, no guilt-based notifications"* stance
independently validated our anti-streak position. **The current build ships a streak:**

> **`2 DAY STREAK` · `2/3 days`** with a flame icon and a progress bar, sitting beside
> **`0 COMPLETED` · `0/1 tasks`** on a new **Stats** tab.

And beyond the streak, a full collectible system: **"Spark"** — a carousel of orbs, most locked
as frosted white spheres, one earned and marbled, the active one a deep blue gradient, labelled
`Spark · 1 tasks`. Plus **Mood and Daily Reflections**, a seven-dot week row.

**So the App of the Year winner shipped the exact mechanic I said a principled app wouldn't.**
That's the fact; here is what I think it does and doesn't mean:

- **It's a gentle streak.** No red, no loss framing, no "you broke your streak" language visible.
  A soft progress bar toward 3 days. That is a long way from Duolingo. **The distinction our
  `INTERACTION.md` should be drawing is not streak-vs-no-streak but punishment-vs-none**
- **It's still a retention mechanic**, and pretending otherwise would be dishonest. Two readings
  fit: they found calm alone didn't retain, **or** they're drifting under growth pressure. From
  outside we can't tell — the same epistemics as the AnyList price question
- **The cadence argument survives intact, and it's the one that matters for us.** Tiimo is used
  *daily*; a daily streak is coherent there. **People shop once or twice a week.** A daily streak
  on a grocery list would punish people for not shopping, which is absurd. **Our refusal of
  streaks should rest on cadence, not on borrowed virtue** — that's a load-bearing reason, and
  the borrowed one just collapsed

### The pricing finding — the most commercially useful thing here

> **`Start 7 day free trial` · "Cancel anytime. $54.00 per year ($4.5 / month)"**

**The iPhone App of the Year charges $54/year — 1.8× our planned $29.99 — with the same 7-day
trial we chose.** In a neighbouring category, from an app whose whole positioning is care for a
vulnerable audience. This is the strongest evidence yet that **$29.99 is conservative rather than
aggressive**, and it directly softens `PLAN.md` §8's "pricing above the category anchor" risk.

### What else is new

| Change | Note |
|---|---|
| **Five tabs**: To-do · Calendar · Focus · **Stats** · **the mascot** | The mascot is now a *tab*, not a floating button — it's the AI, promoted to primary navigation |
| **AI co-planner is the headline** | *"Brain dump it all. I'll sort and structure it."* over the open-handed mascot, with a text field and a black **`Speak`** button. **Voice-first input into the AI** |
| **`Plan like a pro ⚡`** | A scrolling row of in-app **video tutorials** — co-planner, widgets, live activities, web planner, customisation. Education as retention |
| **`Knowledge`** section, `Rate the app`, `Share feedback` | Standard, but note the rate prompt is a passive row, not an interrupt |
| **`Posting to social? ✨ Tag us, we're @tiimoapp`** | A growth loop banner |
| **`Allow live activities`** is a tutorial card | Confirms the Live Activity recommendation in §8 — they're actively pushing users to enable it |
| **Their To-do has `Work · Groceries · Home · Wishlist` tabs** | ⚠️ **Tiimo ships a groceries list.** Not a competitor — no prices, no aisles, no sharing — but the App of the Year has a grocery surface, and it's worth watching |

### The streak is permanent chrome, not a Stats-tab detail

A further correction on my own correction. **The streak and Spark counters sit in the top-left of
every screen** — `🔥 2` and `✦ 0` — on the To-do tab and the Calendar tab alike. They are not
tucked away on Stats; they are **persistent app furniture, present before you've done anything.**

One screenshot also catches a **transient streak panel mid-dismissal** — a row of day circles with
one filled and checked, labelled `DAY STREAK`, ghosting out over the main screen. So there's an
animated streak reveal as well as the permanent counter.

**That's more committed to the mechanic than "they added a streak" implies.** It doesn't change
the cadence argument for us, but it does mean this was a deliberate, prominent product decision
rather than a quiet experiment.

### Two craft details worth taking, from the empty screens

**1. Empty-state copy is written per context, not repeated.** Four sections, four different
prompts:

| Section | Placeholder |
|---|---|
| `ANYTIME (0)` | *"Anytime today works"* |
| `MORNING (0)` | *"What's on your morning list?"* |
| `AFTERNOON (0)` | *"What's happening today?"* |
| `EVENING (0)` | *"End the day your way"* |

Most apps ship one placeholder string repeated. **Writing each slot in its own voice is nearly
free and it's most of why the empty screen feels warm rather than unfinished.** Directly
applicable to our empty aisle sections.

**2. Priority uses shape *and* colour, never colour alone.** On the To-do tab:
`▲ HIGH` (pink) · `● MEDIUM` (peach) · `▼ LOW` (blue) — a triangle up, a filled circle, a triangle
down. This is exactly the rule in `INTERACTION.md` §7, executed by an App of the Year winner, and
it's the one we most need for **estimated vs observed prices**: `~` prefix *and* weight *and*
colour, never colour by itself.

Also observed: **empty sections stay visible with a `(0)` count** rather than being hidden — the
structure of the day persists whether or not it's full. And a third accent appears, a bold
**chartreuse** onboarding card among the pale blue and lavender ones, which stops the pastel
palette from going soft everywhere.

### The shape of the drift

Post-award, Tiimo added **streaks, collectibles, stats, mood tracking, and in-app video**. That is
the standard engagement-mechanics expansion, and it arrived *after* the design award, not before
it. **The version Apple rewarded is the calmer one.**

For us that's a caution in both directions: don't assume the awarded aesthetic is what retains,
and don't assume the retention mechanics are what got rewarded.

---

## 8c. The two builds side by side — and the one swap that explains everything

| | Mobbin build *(pre-award era)* | Live build *(July 2026)* |
|---|---|---|
| **Tabs** | To-do · Today · Focus · Me *(earlier still: Plan · Explore · Focus · Learn)* | To-do · Calendar · Focus · **Stats** · **Mascot** |
| **Header, left** | **`🎉 0/8`** — today's task progress | **`🔥 2`** streak · **`✦ 0`** Spark |
| **Header, centre** | — | **`Get Pro ✦`** |
| **The mascot** | Floating button, bottom-right, over content | **Promoted to a tab** — the AI is now primary navigation |
| **AI** | Present, secondary | **The headline.** *"Brain dump it all. I'll sort and structure it."* + a **`Speak`** button |
| **Rewards** | None | **Streak, Spark collectibles, Stats tab, Mood tracking** |
| **Learning** | A whole **Learn tab** — courses, podcast, body doubling | Demoted to a `Knowledge` row + `Plan like a pro ⚡` video cards |
| **Reach** | iPhone | **+ desktop / web planner** |
| **Price** | not shown | **$54.00/yr ($4.50/mo)**, 7-day trial |
| **Unchanged** | serif display, time-of-day tints, dashed empty slots, emoji-on-pastel, focus ring, focus music, warm paper + lavender | *identical* |

### The swap that tells the whole story

The header used to read **`🎉 0/8`** — *how is today going.* It now reads **`🔥 2  ✦ 0`** —
*what have you accumulated.*

That is a change of kind, not of degree:

| `🎉 0/8` | `🔥 2 · ✦ 0` |
|---|---|
| **Present tense** — about right now | **Cumulative** — about your record |
| **Resets daily**, harmlessly | **Persists**, and can be broken |
| **Nothing to lose** | **Something to lose** |
| Intrinsic — the work is the point | Extrinsic — the counter is the point |
| Party popper 🎉 — celebratory | Flame 🔥 — pressure |

**The visual language, typography and warmth are untouched. The motivational model was replaced.**
Tiimo still *looks* exactly like the app Apple gave the award to; underneath, it now runs on the
mechanics Tiimo's own writing said it avoids.

### What this actually teaches us

1. **Calm aesthetics and calm mechanics are separable, and only one of them wins awards.** You can
   keep the serif, the paper, the soft tints and the warm copy while swapping the motivational
   engine underneath. Apple's editors rewarded the surface. **So the surface is worth copying and
   proves nothing about retention.**
2. **They almost certainly hit a retention wall.** Nobody adds streaks, collectibles and mood
   tracking in one release because the numbers were fine. That's the honest inference, and it's a
   warning: **"be calm" may not be sufficient as a retention strategy.**
3. **Our equivalent already exists and is better.** We don't need an invented counter, because the
   trip total resolving from `≈ $84` to a real figure is **earned, non-arbitrary, and happens
   every single trip.** It is the intrinsic version of what Tiimo replaced with a flame. Protect
   that, and the pressure to bolt on a streak never arrives.
4. **Watch the AI promotion.** The mascot went from floating button to tab, and voice-into-AI is
   now the headline. Apple's award citation called Tiimo an *AI planner*. **The award may have
   been for the AI, not the calm** — which would reframe point 1 again.

---

## 9. The strategic read

**Apple gave iPhone App of the Year to a neurodivergent-first app.** Two things follow:

1. **The ADHD-informed line in `INTERACTION.md` §1 is validated, including where it was cautious.**
   Tiimo markets to neurodivergent people explicitly and openly — and does **not** claim to
   diagnose or treat anything. *Design for it, don't sell a treatment for it.* That's exactly the
   line we drew, and it turns out to be the line the App of the Year winner walks.
2. **Editorial featuring is our only free distribution at scale** (`PLAN.md` §5.4), and Apple's
   editors have just signalled unusually strongly what they reward. **Building genuinely
   ADHD-literate interaction is no longer only an ethical position — it is the most plausible
   route to being featured.**

**And the honest caveat:** Tiimo is a planner with 500,000+ users, courses and a community. We are
a grocery list. **Copy the sensibility, not the surface** — the serif, the warmth, the anti-guilt
stance, the "make being wrong cheap" instinct. Not the timeline, not the onboarding, not the
mascot, and above all not the feature count.

## Sources

- [Tiimo — iPhone App of the Year 2025](https://www.tiimoapp.com/resource-hub/tiimo-winner-2025-app-store-awards)
- [Apple — 2025 App Store Award winners (MacRumors)](https://www.macrumors.com/2025/12/04/apple-announces-2025-app-store-award-winners/)
- [Tiimo — sensory-friendly design for ADHD and autism](https://www.tiimoapp.com/resource-hub/sensory-design-neurodivergent-accessibility)
- [Tiimo screens on Mobbin](https://mobbin.com/apps/tiimo-ios) — [today/timeline](https://mobbin.com/screens/8a6a1881-0e17-4cfa-9aa4-114d0b90aeec) · [timeline gaps](https://mobbin.com/screens/2e5e28b9-c537-46b3-89fe-5d46c59fe6a3) · [focus ring + music chip](https://mobbin.com/screens/ea6a4edb-b54b-4856-bc65-b735e809b033) · [duration dial](https://mobbin.com/screens/328f1217-8ef6-4980-a8ff-3b5a9edb6c2e) · [Live Activity](https://mobbin.com/screens/08174296-6797-414b-ac9d-fad2e80ce106) · [onboarding flow](https://mobbin.com/flows/817f5bfd-1701-4756-bcbc-dcdfc3597723)
