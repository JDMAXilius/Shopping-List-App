# The `.reminders` assistant schema — parked, not abandoned

**Nothing in this folder is in any build target.** It is complete, reviewed work waiting for an
OS that can run it.

## Why it is parked

W8-P2 built the full `.reminders` App Intents cluster and then proved, from Apple's own
documentation JSON rather than from memory, that **the schema does not exist on iOS 18**.
`AppSchema.Reminders*` is marked **iOS 27.0, beta**. Our deployment target is iOS 18.

Three facts, together, made this the wrong v1 surface:

1. **It runs nowhere yet.** Shipping it means every user below iOS 27 gets no Siri at all, while
   `PRODUCT.md:173` sells "Siri add / what's-left / read-aloud" as a v1 feature worth 8 points.
2. **It cannot answer two-thirds of that promise.** The domain has exactly five actions —
   createList, createReminder, createSection, deleteReminders, updateReminder. **There is no
   read or query intent.** "What's left on my list?" and "read me my list" are unanswerable
   inside the schema, at any OS version.
3. **It cannot say what Bagged means.** The schema has no concept of a shop, so a spoken add can
   never choose one. And it demands nine fields a grocery list cannot honour — `dueDate`,
   `recurrence`, `isFlagged`, `tags`, `urls`, `images`, `locationTrigger`, plus `createList` and
   `createSection` as structure actions. The best available behaviour was to add the item and
   then admit in a second sentence that the due date was dropped — which a half-listening user
   hears as "reminder set".

Twelve types of scaffolding that no shipping OS runs is dead code by ARCHITECTURE §2, and dead
code that *apologises* is worse than none.

## What replaced it

Custom `AppIntent`s in `Intents/`, which work from iOS 16, say exactly what Bagged means
(quantity, shop, the three price tiers spoken correctly), and can answer "what's left".

## When to bring it back

When iOS 27 ships and can be tested on a device. It is genuinely valuable then — the schema is
how Siri routes "add milk to my shopping list" to Bagged natively, with no phrase to memorise.
Bring it back **alongside** the custom cluster, gated `@available(iOS 27, *)`, not instead of it:
the custom intents remain the only ones that can read the list back or set a shop.

Two things to re-check on the way back in, both flagged by W8-P2 and never compiled:

- Whether `perform()` must return `some ReturnsValue<X> & ProvidesDialog` where the stub shows
  only `some ReturnsValue<X>`.
- Whether the extra stored property `detail` on `ItemEntity` survives the macro. It is the only
  place quantity and price can reach the Siri subtitle, since neither is a `.reminders` field.

And one thing it got right that must not be lost: the delete path has no confirmation. The app's
own remove always offers an undo slot, so voice deletion is strictly more dangerous than touch.
Whatever ships must close that.
