# Interaction, motion, sound and feedback — designing for the ADHD brain

Research and design principles. **No UI layout in this document** — that comes later, and
deliberately after this, because the feel should decide the layout rather than the other way
round.

---

## 1. The positioning risk — read this before writing any copy

The ADHD angle is a real differentiator and it is also the one part of this plan that can get the
app rejected or, worse, regulated. Two constraints, both current:

- **Apple** requires apps that claim to diagnose or treat a health condition to show regulatory
  approval. Apps touching mental-health territory face heightened review, and 2026 review is
  stricter on unsubstantiated wellness claims than it was.
- **The FDA judges intended use by the totality of presentation** — claims, functionality,
  context — **not by disclaimers.** A disclaimer at the bottom of a page does not undo a headline
  that promises to help a condition.

> **The rule: we design for ADHD. We do not market a treatment for ADHD.**

| Don't say | Do say |
|---|---|
| "Built for ADHD" as the App Store subtitle | "A grocery list that doesn't fight you" |
| "Helps manage ADHD symptoms" | "Fewer decisions, no notifications, nothing to maintain" |
| "Clinically designed", "therapeutic" | "Designed with people who find lists hard to stick to" |
| ADHD in the store title or keywords as a claim | ADHD named openly on a *"why it works this way"* page in-app and on the site |

This isn't timidity — it's the stronger position. **"ADHD-friendly" as a badge is a crowded,
cheapening claim.** Being visibly, unusually calm and low-friction is a thing people *feel* in the
first thirty seconds, and it's not copyable by adding a badge.

---

## 2. What designing for ADHD actually means here

ADHD affects executive function: task initiation, working memory, self-regulation, and time
perception. Mapped onto a grocery list, that produces concrete, testable requirements — not
vibes.

| The difficulty | What it looks like at the shop | What the app must do |
|---|---|---|
| **Task initiation** | The list never gets made | **Open directly into the list.** No home screen, no dashboard, no "create your first list" wizard. Adding is ≤2 taps. Voice add exists precisely because typing is a starting cost |
| **Working memory** | "What else did I need? What have I spent?" | **Never make the user hold state in their head.** Running total always visible. Remaining count always visible. Checked items sink but stay readable |
| **Time blindness / prospective memory** | Remembering the list exists, at the store | **The widget and the store-arrival trigger are externalised memory.** This is the single most valuable ADHD accommodation we ship, and it's free (`FEATURES.md` §10) |
| **Cognitive load / overwhelm** | 40 items, unsorted, in a loud shop | **Aisle grouping is an attention feature, not just a convenience.** One screen, one job. Generous whitespace. No badges, no counters competing for attention |
| **Decision fatigue** | Freezing at a choice | **Defaults everywhere.** Category is chosen for you. Quantity defaults to 1. Estimated price appears without being asked for. Every one is overridable, none is required |
| **Object permanence** | "Did I already check that off?" | Checked items **sink, never vanish.** Undo always available |
| **Rejection sensitivity / shame** | Abandoning an app that nags | **No streaks. No "you haven't opened this in 5 days." No red badges.** Never make the app a source of guilt |

### The trap we explicitly refuse

The research is uncomfortable and worth stating plainly: **the same variable-reward loops that
make apps "engaging" are the ones ADHD brains are most vulnerable to.** Unpredictable rewards
drive compulsion more strongly than predictable ones. Streaks, surprise animations, notification
pulls and gamified points are effective *because* they exploit that.

So the stance, and it's a design constraint with teeth:

> **Feedback is immediate, proportionate and completely predictable. Every time. No variable
> rewards, no streaks, no engagement mechanics, no notification designed to pull someone back.**

An app that treats the user's attention as theirs is a differentiator that a competitor with an
advertising business model **structurally cannot copy**. Listonic is ~90% ad-funded; attention is
their inventory. It cannot be ours.

---

## 3. Motion

Motion has one job: **explain what just happened and where things went.** Anything decorative is
noise, and for this audience noise is expensive.

### Rules

- **Fast.** 150–250 ms for state changes, up to 350 ms for a screen transition. Anything slower
  is a thing to wait for
- **Spring, not linear.** Physical damping reads as real; linear easing reads as a computer
  animating at you
- **Interruptible, always.** A second tap during an animation is obeyed instantly, never queued
  or swallowed
- **Nothing moves that the user didn't cause.** No idle animation, no attention-seeking motion, no
  autoplay
- **One thing moves at a time.** Simultaneous animation is where "busy" comes from
- **`Reduce Motion` is a first-class path, not a degradation.** Every animation has a defined
  no-motion equivalent — usually a 100 ms cross-fade or an instant state change. Test the app
  entirely in this mode; a meaningful share of this audience runs it permanently

### The inventory

| Moment | Motion | With Reduce Motion |
|---|---|---|
| Item added | Row springs in at its sorted position, brief tint that settles | Fade in, no tint |
| **Check off** | Strikethrough draws left→right (~180 ms), row desaturates, then sinks | Instant strike + move |
| Uncheck | Exact reverse — reversibility is the point | Instant |
| Swipe to delete | Row follows the finger 1:1, snaps past threshold | Unchanged — direct manipulation isn't "motion" |
| Undo | Row returns along the path it left by | Instant reappear |
| Total updates | Digits roll, **~200 ms, no bounce** | Instant |
| Category collapse | Height animates, contents fade | Instant |
| Reorder (drag) | Neighbours part to make room, live | Unchanged |
| Sync arriving | **The gentlest one in the app** — a soft tint on the changed row, no toast, no banner | Tint without animation |
| Paywall | Standard sheet. No theatre | Standard |

**Sync deserves its own note.** Someone else adding an item while you're mid-shop is the moment
the app is most likely to feel chaotic. Changes from other people should arrive *quietly* and be
discoverable, not announced.

---

## 4. Haptics

Haptics are the **primary** feedback channel, not the garnish. They work in a noisy supermarket,
they work with the phone on silent, they work in a pocket, and they don't demand you look.

### The map

| Event | Pattern (`expo-haptics`) | Why |
|---|---|---|
| **Check off an item** | `impactLight` | The core gesture, done 20–40× a trip. **Must be light** — anything heavier becomes irritating by item ten |
| Uncheck | `selection` | Distinct from checking, deliberately smaller |
| Add an item | `selection` | Confirms registration without ceremony |
| Delete | `impactMedium` | Weightier because it's destructive |
| Undo | `impactLight` | Reassurance |
| Drag pickup / drop | `impactLight` / `selection` | Standard direct-manipulation language |
| **Whole list complete** | `notificationSuccess` | The one moment that earns a distinct pattern — see §6 |
| Error (sync failed, payment failed) | `notificationError` | Rare by design |
| Scrolling, navigation, opening a sheet | **Nothing** | Haptics mark **state changes**, never movement. This rule alone prevents most haptic fatigue |

### Rules

- **One haptic per user action.** Never stack them
- **Nothing the user didn't cause.** A remote sync must never buzz someone's pocket
- **A single settings toggle disables all of it**, and it's easy to find. Some people find haptics
  aversive, and that includes some of this audience
- Respect the system haptics setting without needing our own

---

## 5. Sound

**Default: off.** Not quiet — *off*.

The reasoning is specific. A grocery app is used in public. Sound in a shop is a small social
cost, and a sound that fires 30 times a trip is a large one. Haptics already carry the
confirmation, in silent mode, where sound cannot.

If enabled by the user:

- **Short.** Under 120 ms. A tick, not a chime
- **Soft-attack, low-brightness.** No sharp transients, no synthetic sparkle
- **Two sounds total.** A check tick and a completion tone. That's the whole library
- **Respects the silent switch, always** — via the ambient audio category, never playback
- **Never plays over other audio.** People shop with podcasts and music on; ducking someone's
  audio to confirm they bought milk is unacceptable

**Sound is where "less is more" is most literal.** Two sounds, off by default, is the entire
design.

---

## 6. The completion moment

The last item checked off is the emotional peak of the product. It is worth designing properly and
it is worth **under**-designing.

The obvious move is confetti. **Confetti is wrong here**, for two reasons that both matter:

1. It contradicts calm. A burst of particles is stimulation, and this audience gets plenty.
2. It's a variable-reward pattern in costume — the thing §2 refuses.

Design it as **arrival**, not celebration:

- The total settles to its final figure and **stops being an estimate** — the `≈` resolves, which
  is a small honest reveal the whole cost feature has been building toward
- A single `notificationSuccess` haptic
- One quiet line: *"That's everything — 23 items, $84."* Real numbers, not praise
- **The screen becomes calm rather than busy.** Nothing new appears; things stop moving
- No score, no streak, no share prompt, no rating request in this moment

**Ending well means the app gets out of the way.** Finishing the shop should feel like putting
something down, not like a level-up.

---

## 7. Accessibility, which is the same work

Every ADHD accommodation above is also a general accessibility win, and the formal requirements
overlap almost entirely:

- **Dynamic Type** through the largest accessibility sizes. Rows must reflow, not clip — this is
  already a known issue in the mockup, where the quantity chip truncates long names
  (`PLAN.md` §9)
- **VoiceOver**: each row announces name, quantity, price and checked state as one coherent
  phrase — not four fragments
- **44 pt minimum touch targets.** The check-off target should be considerably larger; it's used
  one-handed, in motion, while carrying things
- **Contrast**: 4.5:1 for body text. Grey estimate text is the risk — verify it, don't assume it
- **Reduce Motion** and **Reduce Transparency** honoured throughout
- **Never colour alone.** Estimated versus observed prices are distinguished by the `~` prefix
  *and* weight *and* colour

---

## 8. What to actually test

Design intent is untestable; these aren't:

- **Time from app-open to first item added.** Target ≤2 s. This is the task-initiation metric and
  the most important number in this document
- **Taps per added item.** Target ≤2
- **Frame timing on check-off** — 60 fps, no dropped frames, on the oldest supported device
- **A full session with Reduce Motion + largest Dynamic Type + VoiceOver.** Not a checklist pass:
  an actual shop
- **Haptic fatigue**: check off 40 items in a row. If it's annoying by item ten, the pattern is
  too strong
- **Sync-during-shopping**: two devices, one shop, live edits. Does it feel calm or chaotic?

---

## 9. Sources

- [UX Design for ADHD — Bootcamp](https://medium.com/design-bootcamp/ux-design-for-adhd-when-focus-becomes-a-challenge-afe160804d94)
- [Designing for ADHD in UX — UXPA International](https://uxpa.org/designing-for-adhd-in-ux/)
- [Principles of Neurodivergent UX Design](https://www.accessibilitychecker.org/blog/neurodivergent-ux-design/)
- [Digital Minimalism for ADHD — on dopamine and variable rewards](https://www.brain.fm/blog/digital-minimalism-adhd-phone-focus)
- [ADHD-Friendly App Design: what to look for and avoid](https://www.monstermath.app/blog/adhd-friendly-app-design-what-to-look-for-and-what-to-avoid)
- [Microinteractions: making UI feedback accessible](https://www.accessibilitychecker.org/blog/microinteractions/)
- [Apple — App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [FDA SaMD boundary for health apps, 2026](https://yonkerstimes.com/title-is-your-healthcare-app-a-medical-device-the-fda-samd-line-2026/)
