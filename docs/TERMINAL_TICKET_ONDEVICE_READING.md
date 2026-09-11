# TERMINAL_TICKET_ONDEVICE_READING — the phone reads the receipt

> STATUS: open — written by cloud 2026-09-11 on the founder's direction: *"make sure that you are
> using the iPhone power for computer vision… the local LLMs, everything that we need."*
> **This is the main event. Start it first** — `TERMINAL_TICKET_FIELD_REPAIR` is the smaller
> ticket beside it, and only its one-line photo count blocks anything here.
> Same operating mode and honesty laws as `TERMINAL_TICKET_GATE_AUTOPILOT.md`.
>
> Context you already have: wave 10 is gated green and build 1.0 (1) is on a phone, carrying an
> honest `.invalid`-marker disclosure that says this build has no receipt reader. That sentence
> was right. This ticket is how it stops being needed.

## The point

Bagged's differentiator is a price on every row that came from the user's own receipt. Today the
only thing in this app that can read a receipt is an Edge Function on a Supabase project that has
never been created. The feature has therefore never worked once, for anyone, and it has been
blocked on someone else's account setup since 2026-08-16.

**Meanwhile the phone in the user's hand can read the receipt itself.** Apple ships on-device text
recognition on every supported device, and an on-device language model on Apple Intelligence
devices. Neither costs a cent, neither needs a network, neither needs a key, and neither sends the
photo anywhere — which is a stronger version of the privacy promise `PRODUCT.md` already makes.

**The goal of this ticket: a receipt scan that works on a plane, on a phone that has never signed
in, in a build with no backend configured at all.** The cloud becomes the escalation for the
receipts the phone could not read, not the only path.

## The one structural rule that keeps this small

`ScanBackend` already exists and is already the seam:

```swift
protocol ScanBackend: Sendable {
    func scan(image: Data, mediaType: ScanMediaType, shopHint: String?) async -> ScanOutcome
}
```

**Build `OnDeviceScanBackend` as a conformance to that protocol and change nothing downstream.**
`CaptureSession`, the review screen, the line resolver, the confidence tiers, the `>3× estimate`
flag, the op writes — all of it already works against this protocol and must keep working
untouched. If you find yourself editing `ReceiptReviewScreen`, stop: you have gone outside the seam
and something is wrong with the design, not with the screen.

`BaggedApp.makeScanBackend` picks the backend. After this ticket its order is:

1. `ScriptedScanBackend` — DEBUG + UI tests, unchanged.
2. **`OnDeviceScanBackend`** — the default, always available.
3. `ScanClient` — only as the escalation inside the on-device backend, and only when configured.

## Tiers, and which devices get which

Design it as three tiers with an honest floor, because Apple Intelligence is not on every phone.

### Tier 1 — Vision text recognition. Every device, iOS 18+, offline, free. **Non-negotiable floor.**

Recognise the text and **keep the geometry**. A receipt is one of the most parseable documents
there is precisely because of its layout: description on the left, amount right-aligned, one line
per item. Bounding boxes are what make that reliable; a flat string loses the association between
a name and its price.

- Use Vision's text recognition with `.accurate`, language correction on, and a revision pinned
  explicitly so an OS update cannot silently change the output.
- Assemble observations into lines by vertical overlap, then split each line into left (name) and
  right (amount) by horizontal position.
- Parse money with `Decimal`/`NSDecimalNumber`, **never `Double`** — `MoneyText` and the existing
  minor-unit discipline are already in the repo; follow them. Amounts become `amount_minor`.

### Tier 2 — the on-device model, where the hardware has one.

For the parts geometry cannot settle: which lines are items versus subtotal/tax/loyalty, what the
shop is called, multi-line items, weighed goods (`1.24 kg @ $3.99/kg`), and discounts.

- Apple's **Foundation Models** framework (iOS 26+) gives a `LanguageModelSession` with *guided
  generation* — you declare the Swift type you want back and the model is constrained to produce
  it. That is exactly the shape of this problem, and it means no JSON parsing and no prompt
  injection surface from receipt text.
- **Check availability at runtime and degrade silently.** The model exists only on Apple
  Intelligence devices, and only when the user has it enabled and the device is not in a state
  that withholds it (low battery, thermals). Tier 1 must produce a usable result on its own.
- The model's job is **structuring text, never inventing money.** An amount must trace back to
  characters Vision actually recognised. If the model returns a number that is not in the OCR
  output, drop it and mark the line `not_sure` — see the honesty section.

### Tier 3 — Anthropic, for the receipts the phone could not read.

Only when tiers 1–2 come back with low confidence or too few lines, only when a reader endpoint is
configured, and — decide this explicitly — probably only with the user's say-so on that receipt,
since it is the one path that sends their photo off the device.

**The API key never ships in the app.** Not in Info.plist, not in an xcconfig, not obfuscated in
the binary. Anyone with the `.ipa` can read it, and it is the founder's account and the founder's
bill. `ScanClient` already does this correctly — it calls an endpoint that holds the key. Keep it.
What changes is only *which* endpoint; see the founder list.

## This is not a new direction — it is the one `DECISIONS.md` already made

Two lines that were written long before the founder tested anything, and that the current code does
not honour:

- *"The rule: free tier → on-device only. Paid tier → cloud allowed, low-frequency only."*
- *"Minimum iOS 18. **Foundation Models (iOS 26) is availability-gated, never a dependency**."*

Receipt scanning was placed on the cloud as a paid, low-frequency feature, which fit the rule. What
did not fit was making it the **only** path, so that a build with no backend has no reader at all.
This ticket moves the default back to where the cost architecture always said it belonged.

## iOS version and the deployment target

`project.yml` says iOS 18.0. Tier 2 needs iOS 26.

- [ ] **Do not raise the deployment target for this.** Gate tier 2 behind `if #available` and keep
      the floor at 18. Raising the minimum drops real users to buy a feature that a fallback
      already covers.
- [ ] Every API named in this ticket must be **verified against the SDK you have**, not taken from
      me. I am working from memory, without a compiler, and this project's rule is that a claim you
      did not execute is not a claim. Exact type names, initialisers, and availability attributes:
      check them, and if something here is wrong, fix it and say so in the Log.

## Honesty rules this must not break — these come from PRODUCT and they are the whole product

1. **Three tiers, never confusable.** `$4.49` measured · `~$5.00` estimated · `—` none, and `≈` on
   any total containing an estimate. A price read off a receipt is **measured**. A price the model
   guessed is **not measured** and must never render as if it were.
2. **Nothing commits unreviewed.** The existing review screen stays in the path. On-device reading
   makes scanning cheaper, not more automatic.
3. **A number nobody can point at does not exist.** Every `amount_minor` must be traceable to
   recognised characters. This is the single most important rule in the ticket: the failure mode of
   a language model on a blurry receipt is a confident, plausible, wrong number, and this app's
   entire value is that its numbers are real.
4. **Confidence is not decoration.** `ScanConfidence` already has `sure` / `not_sure` / `no_match`.
   A line the model disambiguated rather than read should not be `sure`.
5. **`>3×` the catalog estimate stays flagged.** That check has caught real errors before; it must
   run on on-device output too.
6. **The photo does not leave the device** in tiers 1–2. Say so on screen.

## `ScanReceipt` has two fields the phone cannot answer

`isPlus` and `scansUsed` come from the server's response today, and `SubscriptionStore.record`
consumes them. An on-device scan has no server to ask.

- [ ] Do **not** invent them and do **not** let an on-device scan write an entitlement fact. Make
      the on-device path return a receipt that carries no claim about entitlement, and have
      `SubscriptionStore` leave both untouched for it. W10-P2 added an entitlement read that no
      longer needs a scan, which is what makes this possible — and its rule already applies: a
      thing that is not a statement about entitlement must not be written as one.

## Acceptance — and it is all by execution

- [ ] Compiles and the full ladder is green, with counts.
- [ ] **Unit tests over fixed OCR output**, not over images: feed recorded Vision observations
      (name + box + confidence) into the assembler and assert the lines. That is the part that must
      never regress, and it is testable without a camera.
- [ ] **Real receipts, on a device, photographed by you.** At least five, and say which shops. For
      each, record: lines found vs lines on the paper, the total the app computed vs the printed
      total, and every place it was wrong. **Put the numbers in the Log, including the failures.**
      A pass rate is the deliverable here, not a green checkmark.
- [ ] One of those five must be photographed **in Airplane Mode** and must work.
- [ ] One must be run on a device **without Apple Intelligence** (or with it switched off) to prove
      the tier-1 floor is real.
- [ ] Mutation test the honesty rule: make the model return an amount that is not in the OCR text
      and prove the line is rejected rather than rendered as measured.

## What to do about the queued photos

`Repository.pendingScans()` may hold real receipt photos the founder already took, queued since
before this existed. Once the on-device reader works, they can finally be read.

- [ ] Read them with the on-device backend on next launch, and take the result to the review screen
      rather than committing anything silently.

## Log

<!-- Append dated entries. Never rewrite above this line. -->
