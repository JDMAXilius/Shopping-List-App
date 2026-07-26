# The ten conversations — validating the cost bet before building it

The whole strategy rests on one unproven reading: that AnyList's 14 years without prices means
**unclaimed territory** rather than **tried and not worth it** (`PLAN.md` §8, risk 1). This is how
to find out in a week instead of six months.

**Total cost: ~8 hours over one week.** Against a 4–6 month build.

---

## 1. The rule that makes this work

> **Never ask what someone would do. Ask what they did.**

People are generous and want to be helpful, so they say yes to hypotheticals. "Would you like to
see prices in your list?" gets a 90% yes and tells you **nothing** — that same yes is what makes
founders build features nobody uses.

Past behaviour can't be faked. Someone who kept a receipt, made a spreadsheet, or can tell you
what last Tuesday's shop cost has the problem. Someone who shrugs doesn't — no matter how
enthusiastic they are about the idea.

**Three hard rules:**

1. **Never describe the app.** Not once. The moment you pitch, they start being polite instead of
   honest, and the interview is over even though it keeps going.
2. **Ask for specifics, then ask them to show you.** "You track spending?" → *"Can you show me?"*
   The gap between what people say they do and what's on their phone is the entire finding.
3. **Silence is a tool.** After an answer, wait. The second sentence is usually the true one.

---

## 2. Who to talk to

**Ten people who shop for a household of 2+ and currently use a list app or notes app.**

Deliberately mixed, because a uniform sample only confirms what you already think:

| Segment | How many | Why |
|---|---|---|
| Current **AnyList / OurGroceries / Bring!** users | 4 | The buyers. They already pay for list software |
| **Notes / Reminders / paper** users | 3 | The larger market. Tests whether the wedge reaches beyond app-switchers |
| People who **already track grocery spend somehow** | 2 | The strongest signal — find out what their workaround costs them |
| Someone who **tried a list app and stopped** | 1 | Churn is the most under-asked question in this category |

**Where to find them:** App Store review authors for AnyList/OurGroceries (public), r/ADHD,
r/EatCheapAndHealthy, r/Frugal, r/MealPrepSunday, budget and meal-planning Facebook groups,
and — best of all — friends of friends, two degrees out so they'll be honest with you.

> ⚠️ **Interview people in the market you're launching in.** The plan targets **US iOS**. Ten
> conversations with shoppers in another country validate a different market — prices, store
> formats, and what people consider a normal grocery bill all differ. If the launch market
> changes, the whole `MARKET.md` model changes with it.

---

## 3. The script — 25 minutes

### Opening (2 min)

> "I'm doing research on how people do their grocery shopping. I'm not selling anything and
> there's nothing to sign up for. There are no right answers — I'm just trying to understand how
> it actually works for you. Mind if I record so I don't have to take notes?"

### Part 1 — The last trip *(the grounding)*

Everything specific, nothing hypothetical.

- "Walk me through your last grocery trip, from deciding to go to getting home."
- "How did the list get made? Who put it together?"
- "Did anyone else add to it?"
- **"Before you got to the till — did you have a sense of what it would come to?"**
- **★ "What did it actually come to?"**
- "Was that more or less than you expected? By roughly how much?"
- "How did that feel?"

**★ is the single most important question in the interview.** If they know the number, the problem
is live for them. If they shrug, it isn't — however much they like the idea later.

### Part 2 — Evidence the problem already costs them

- "When was the last time a grocery bill surprised you?"
- "What did you do about it?"
- **"Do you track what you spend on groceries anywhere?"**
  - If yes → **"Can you show me?"** *(Screen share. Look at the real thing.)*
  - "How long have you kept that up? When did you last update it?"
- "Have you ever set yourself a budget for a shop? What happened?"
- "Have you ever put something back — at the shelf or at the till — because of the price?"
- "Do you keep receipts? What for?"

**A shaky spreadsheet someone has maintained for eight months is worth more than ten
enthusiastic yeses.** That's a person paying a cost to solve this today.

### Part 3 — The app they already use

- **"Can you open your list app and show me what's in it right now?"**
- "How many items? When did you last open it?"
- "What's the most annoying thing about it?"
- "Have you ever tried a different one? What made you switch — or not?"
- **"Are you paying for it?"**
  - If yes → "What made you decide to? Do you remember what it cost?"
  - If no → "What would have to be true for you to?"

### Part 4 — The bet, asked without leading

Only now, and still without describing anything.

- **"Has it ever crossed your mind to want prices in your list app?"**
  - If yes → "What made you think of that? Did you do anything about it?"
  - **If they've never once thought of it — write that down. It's data, and it's the answer you
    least want.**
- "If your list showed a rough estimate — 'about $84', not exact — would that be useful, or
  annoying?"
- "What would make it annoying?"

That second question is the only near-hypothetical in the script, and it's here deliberately: it
tests the **estimate-honesty design** (`~`, `≈`, grey vs solid) directly. If people say "a wrong
number is worse than no number," that's not a rejection of the wedge — it's a specification.

### Part 5 — Friction *(the ADHD angle, unnamed)*

- "Do you ever make a list and then not use it in the shop?"
- "What stops you opening it?"
- "Is there anything about these apps that feels like work?"
- "Does anyone else in your household use the list? How does that go?"

**Never say "ADHD."** If it's a real pattern, it shows up in the answers.

### Close

- "What should I have asked and didn't?"
- **"Who else shops like you that I should talk to?"** *(This is how you get from 4 interviews
  to 10.)*

---

## 4. Never ask these

| ❌ Don't | Why |
|---|---|
| "Would you use an app that tracks grocery prices?" | Hypothetical. Guaranteed yes. Worthless |
| "Would you pay $29.99 a year for this?" | People are terrible at predicting their own spending |
| "Do you think prices in a list app would be useful?" | Asks them to compliment your idea |
| "We're building an app that…" | The interview ends here and you won't notice |
| "Don't you find it annoying when…?" | Puts the answer in their mouth |

---

## 5. Decide the scoring **before** you start

Written down in advance, so the result can't be rationalised afterwards. **This is the part
people skip, and skipping it is how validation becomes theatre.**

| Outcome | Criteria | What it means |
|---|---|---|
| **✅ Strong** | ≥5 of 10 know roughly what their last shop cost **and** ≥3 show you a real, currently-maintained tracking workaround | The wedge is real. Build it |
| **🟡 Ambiguous** | People like the idea but nobody has a workaround, and few know their last total | **The most likely outcome, and the most dangerous.** It reads as encouragement. Treat it as "wanted, not retained": build cost as *one* feature, not the positioning |
| **❌ Fail** | ≥7 shrug at the total, nobody tracks, and a *different* annoyance comes up repeatedly | The premise is wrong. That different annoyance is your actual wedge |

**Also record, every time:**

- How many can name their last total, unprompted
- How many have a live workaround, seen on screen
- How many already pay for a list app, and how much
- **The top annoyance named, in their words** — tally these. If seven people name the same thing
  and it isn't price, you've just found the product
- Whether "prices" ever comes up before you raise it

**Be willing to lose.** Ten conversations that kill the cost wedge saved five months. That is the
best possible return on a week.

---

## 6. Recruiting messages

**To someone two degrees out:**

> "I'm doing research on how people handle grocery shopping — not selling anything, no app to
> download. 25 minutes on a call, and I'd mostly be asking about your last shop. Would you be up
> for it, or know someone who would?"

**To a Reddit / group post:**

> "Researching how households handle grocery lists and grocery spending. Looking for 25 minutes
> with people who shop for 2+ people. Not selling anything, nothing to sign up for — I just want
> to understand how it actually works. Happy to share what I learn."

**To an App Store reviewer** *(they left a public review, so they're already engaged)*:

> "Saw your review of [AnyList] — you clearly use it properly. I'm researching how people use
> grocery list apps and would love 25 minutes. Not selling anything."

---

## 7. The week

| | |
|---|---|
| Mon | Write the list of who to ask. Send 25 messages — expect ~10 yeses **(2h)** |
| Tue–Thu | Six interviews **(2.5h)** |
| Fri | Four interviews **(1.5h)** |
| Fri PM | Tally against §5. Write one page: what you heard, what surprised you, the decision **(2h)** |

**~8 hours.** `Core` and `Catalog` can be built in parallel — they're useful under every outcome,
since a list app needs a resolver whatever the positioning turns out to be.
