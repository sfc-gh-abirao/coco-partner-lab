# Zero-privilege track

**For anyone whose pre-flight verdict was `REPO-ONLY`.**

Nothing here needs a Snowflake connection, a warehouse, or any grant. You will
work entirely in the repository.

---

## First, the honest framing

This is not the consolation version of the lab. Core A and Core C are the two
parts of this session that transfer to every future engagement, and they are both
here. What you are missing is Core B — building the dynamic table pipeline — which
is the part you can do any time you have an account, and which you have probably
done before anyway.

The parts that are genuinely hard to practise are inheriting an unfamiliar
codebase and encoding standards so you stop re-teaching them. Those are the parts
you are doing.

So: do not wait for grants, and do not treat this as marking time.

---

## 60 minutes

| | | Time |
|---|---|---|
| **A** | Onboard an unfamiliar repo | 25 min |
| **C** | Encode a standard as a skill | 20 min |
| **D** | Read the pipeline you did not build | 10 min |
| | Compare notes | 5 min |

You have more time per part than the main track, so go deeper rather than
faster.

---

## Part A — Onboard an unfamiliar repo (25 min)

Follow **Core A** in [LAB_GUIDE.md](LAB_GUIDE.md) — sections A1, A2 and A3.

With the extra seven minutes, add these:

### A4. Map the consumers

Before you change anything on a real engagement, you need to know what breaks.

Work out what depends on `revenue_by_customer.sql` — inside the repo, and what
the code and comments tell you about consumers outside it.

The lesson is what the repo cannot tell you. There is a finance dashboard
consuming it, and nothing in the code names it. On a real engagement that gap is
where the incident comes from.

### A5. Estimate the work

Produce something you could actually send:

- What would it take to fix the revenue bug without breaking the product split?
- What would it take to reconcile the three naming conventions, and is it worth it?
- Which of these would you do in week one, and which would you leave alone?

That last question is the real skill. Not everything wrong needs fixing on a
two-week engagement, and knowing what to leave alone is what separates a useful
consultant from an expensive one.

**Checkpoint A.** You could walk into a stakeholder meeting and describe what
this project does, what is wrong with it, what you would fix first, and what you
would deliberately not touch.

---

## Part C — Encode a standard as a skill (20 min)

Follow **Core C** in [LAB_GUIDE.md](LAB_GUIDE.md).

With the extra eight minutes, make it genuinely reusable:

### C3. Add the rules you did not learn today

Your firm already has standards that live in people's heads. Pick two or three
you have had to explain to a new starter in the last six months and write them
down properly:

- How you lay out a project
- What must be true before a model ships
- Your warehouse sizing defaults, and why
- How you name things, having picked one convention

### C4. Test it against something unfamiliar

Point the skill at a **different** part of `legacy_project/` — one you have not
looked at closely. `models/marts/v_customer_360.sql` and
`models/marts/carrier_performance.sql` are good candidates.

```
Review this model against my standards and tell me what does not comply.
```

A skill that only works on the code you wrote it from is not a standard, it is a
note. This is the test that distinguishes them.

**Checkpoint C.** Your skill flagged something in a file you had not read when
you wrote it.

---

## Part D — Read the pipeline you did not build (10 min)

You cannot run Core B. You can read exactly what it would have created, which is
worth more than it sounds — the lesson in it is a reading lesson, not a running
one.

Open [`03_broken_artifacts.sql`](03_broken_artifacts.sql). **Stop at the
`DIAGNOSIS BELOW` marker.**

From the artifact definitions alone, work out:

1. `DT_CUSTOMER_LATEST_ORDER` gets `REFRESH_MODE = FULL` despite nothing failing.
   Which specific expression causes that, and why?
2. `V_REVENUE_BY_CUSTOMER_PRODUCT` overstates revenue by roughly 3x. Where?
3. `WHERE order_status NOT IN ('Cancelled', 'DRAFT')` fails to exclude thousands
   of cancelled orders. Why?

Then read the diagnosis and check yourself.

**All three of these are findable by reading.** That is the point — the engineers
who shipped them all had working Snowflake accounts, and the account did not help
them. Reading carefully, and knowing which questions to ask, did.

**Checkpoint D.** You got at least two of the three before reading the
diagnosis. If you got all three, write down the question you asked yourself to
find each one, and put those questions in your skill.

---

## Compare notes (5 min)

Join the main track's discussion. You have something specific to contribute:
you found the same three defects the others found by running things, and you
found them by reading. Say which questions got you there.

---

## Afterwards

Nothing to tear down — you created nothing.

When you do get Snowflake access, Core B is worth doing on your own. It takes
about twenty minutes, and `lab/00_preflight.sql` will tell you when you are ready.
