# TERMINAL_TICKET_FIELD_REPAIR — what the founder found on a real phone

> STATUS: open — written by cloud 2026-09-11, after the founder tested build 1.0 (1) and reported
> that receipt scanning does nothing and that the shop/GPS behaviour does not work.
> Same operating mode and honesty laws as `TERMINAL_TICKET_GATE_AUTOPILOT.md`.

## Where this starts, corrected against what you actually did

I wrote a first draft of this ticket assuming the project might not even compile. It was wrong and
I am saying so rather than quietly fixing it: **wave 10 was gated green** (Data 69/69, BaggedTests
284/284, the revert proof holding, RLS 20/20 on real Postgres) and **build 1.0 (1) is on a phone**.
The `.invalid` marker trick that satisfies the Release preflight without weakening it was the right
call, and the disclosure it drives —

> *"This test build has no receipt reader. Photos you take are kept on this phone and never read.
> Enter by hand works normally."*

— is exactly the sentence that should have been there. The app told the truth about itself.

**So the founder's report is not a bug report. It is the build working as built, and the build not
being the product yet.** Two things follow, and they are what this ticket is for.

## §A — The thing the founder actually needs: the phone must read the receipt

There is one receipt reader in this app and it lives on a server that has never been created. That
is `TERMINAL_TICKET_FOUNDER_BLOCKERS` item 1, open since 2026-08-16, and waiting for it has now
cost a month in which the differentiator did not exist.

**The reader moves onto the phone.** That is `TERMINAL_TICKET_ONDEVICE_READING` — the main event,
and this ticket exists mostly to clear the ground for it.

- [ ] Before you start it: **count the queued photos** on the founder's device or the simulator —
      `Repository.pendingScans()`. Those are real receipts, taken and kept, that nothing has ever
      read. The number is the size of the debt, and it belongs in the Log.

## §B — The shop/GPS behaviour: prove the mechanism, then report honestly

There is **no store discovery anywhere in this app**. `grep` finds no MapKit, no `MKLocalSearch`, no
`CLGeocoder`, no `MKMapItem` in App/, Packages/, Widget/ or Intents/. That is deliberate:
`PlaceStore.pinHere`'s comment says a "search nearby" box "sends a coordinate to somebody's server,
which is the one thing this app promises not to do".

So the only path a shop has to a location is: create the shop → **stand inside it** and tap pin →
grant "while using" → separately grant **Always** → leave → come back. It is entirely possible to
conclude "the GPS doesn't work" while every line behaves correctly.

- [ ] **Prove the mechanism end to end on the simulator** and put the evidence in the Log: simulate
      a location, create a shop, pin it, grant Always, then cross into the fence with a GPX route
      (Xcode → Debug → Simulate Location) and confirm the active shop switches.
- [ ] On a real device: confirm which permission prompts actually appear. `requestAlways()` refuses
      unless `permission == .whileUsing` already — check the "Allow background arrivals" button in
      `ShopEditorScreen` is reachable and does something.
- [ ] Report whether `waiting` (armed pins iOS has no room to watch) is ever non-zero.
- [ ] **If any of that is broken, that is a real bug and it is yours to fix.** If all of it works,
      say so plainly — "works as designed, is not what was expected" is a finding, not a dodge.

**Do not add a shop search.** Whether Bagged may send a coordinate to Apple to name nearby shops is
a product decision the founder has been asked for directly (`DECISIONS.md` → "There is no store
discovery"). The cheap alternative that needs no decision at all: **the receipt names the shop**, so
once §A lands, a scan can offer to create and pin it.

## §C — Siri, which nobody has ever confirmed works

Five App Intents exist (`AddItem`, `CheckOff`/`Uncheck`, `ReadList`, `RemoveItem`, `WhatsLeft`) plus
`BaggedShortcuts`. No log anywhere says they have been spoken to.

- [ ] On the device with the TestFlight build: open Shortcuts and say whether Bagged's actions are
      listed.
- [ ] Say each phrase to Siri. Record **verbatim** what Siri answers, including the failures.
- [ ] `IntentContext.current()` throws `notReady` on a schema mismatch, and wave 10 bumped the
      schema to **v8** — so until the app has been launched once after install, every intent and the
      widget refuse. Confirm that is what happens, and that it is a sentence rather than a crash.

## §D — Two loose ends from the build you shipped

- [ ] **A3's last box is still open:** verify on the device that app, widget and intents open the
      *same* database. A mis-registered App Group does not crash — it silently gives each process
      its own empty file.
- [ ] The founder has not been told what the screens panel is. It ships in this build on purpose
      (A4b) and comes out before submission.

## Log

<!-- Append dated entries. Never rewrite above this line. -->
