# Lab guide

**60 minutes. Three parts. Work at your own pace.**

You are not expected to finish everything. Core A and Core C are the parts you
will still be using in six months, which is why they come first and last rather
than being buried as extras.

| | | Time | Needs Snowflake? |
|---|---|---|---|
| **Step 0** | Pre-flight and setup | 5 min | — |
| **Core A** | Onboard an unfamiliar repo | 18 min | **No** |
| **Core B** | Build and verify a pipeline | 20 min | Yes |
| **Core C** | Encode a standard as a skill | 12 min | **No** |
| | Compare notes | 5 min | — |

Every step ends with a **Checkpoint**. Compare your output against it and move
on. Do not queue for the facilitator on something a checkpoint can answer.

---

## Step 0 — Pre-flight and setup (5 min)

```
lab/00_preflight.sql      read-only, prints your verdict
lab/01_setup.sql          creates your schema     (FULL / CORE only)
lab/02_seed_data.sql      generates the raw data  (FULL / CORE only)
```

### Your verdict decides your path

| Verdict | What it means | Where to go |
|---|---|---|
| **FULL** | Everything, including data metric functions | Continue below |
| **CORE** | Dynamic tables yes, DMFs no | Continue below, take the **CORE path** at the fork in Core B |
| **REPO-ONLY** | No Snowflake write access | **[track-zero-privilege.md](track-zero-privilege.md)** |

**If you got REPO-ONLY, go there now.** Do not wait for grants, and do not sit
quietly hoping it resolves. You will do Core A and Core C, which need no
Snowflake access and are the most transferable parts of this session.

### Checkpoint 0

After `02_seed_data.sql`, the checkpoint query should return roughly:

| | |
|---|---|
| `order_rows` | ~503,990 |
| `distinct_order_ids` | 499,000 |
| `duplicate_order_ids` | ~4,990 |
| `null_customer_pct` | ~2.0 |
| `raw_status_values` | 7 |
| `normalized_status_values` | 4 |
| `order_line_rows` | ~1,500,000 |
| `day_span` | 89 |

The generator is random, so your numbers will differ slightly. Order of
magnitude is what matters. If `raw_status_values` is not 7, you are running an
older copy of the seed script — re-pull.

---

## Core A — Onboard an unfamiliar repo (18 min)

**Scenario.** You joined this engagement on Monday. The engineer who built most
of `legacy_project/` left eighteen months ago. Finance says the revenue number is
wrong. You have not seen the code before.

You are producing three things. Write them down as you go — Core C consumes them.

### A1. What does this project do, and where are the docs wrong? (7 min)

Start with `.git-history-notes.md` and `README.md`.

The useful move is not "summarise this repo". It is **asking the agent to check
claims against code**. The README is confident and partly wrong, which is worse
than missing documentation, because wrong docs make you confident and incorrect.

Things worth verifying rather than trusting:

- Does every model named in the README actually exist?
- Does the claimed test coverage match `_marts.yml` and `_staging.yml`?
- Does the claimed refresh cadence match the `TARGET_LAG` values in
  `models/dynamic/`?
- Is the claimed naming convention the one the code uses?

**Checkpoint A1.** You should have found at least three concrete contradictions
between README and code. If you found fewer, you are summarising rather than
verifying — point the agent at a specific claim and ask whether the code
supports it.

### A2. Find the revenue bug (7 min)

Finance says revenue is overstated. Find out why, in the code.

> **If "grain" is not a word you use day to day:** the grain of a table is what
> one row represents — one row per order, one row per shipment, one row per
> customer per day. You may know it as granularity, or level of detail. That is
> all you need to make sense of the hints below.

Two hints, in increasing order of how much they give away. Use the first before
the second.

<details>
<summary>Hint 1</summary>

Think about grain. Ask about grain explicitly — "does this aggregate at the
correct grain" gets you much further than "review this model".
</details>

<details>
<summary>Hint 2</summary>

Something in the repo already computes customer revenue a second way, and the
person who wrote it noticed the discrepancy. Look in `sql/adhoc/`.
</details>

**Checkpoint A2.** You should be able to state:

- the file and the specific line that is wrong
- why it is wrong, in terms of grain
- why it was a reasonable change to make at the time
- roughly how large the error is

If you can name the file but not why the change was reasonable, keep going. That
last part is what you will have to explain to the customer, and it is the
difference between "your predecessor was careless" and "here is how this
happened".

### A3. Write it down (4 min)

Fill in `MEMORY.md` at the repo root. It is currently a stub with TODOs.

Aim for **at least three conventions**, the bug, and the stale-README items. For
each entry, write the rule **and the reason it holds**, so a future session can
tell when it has stopped applying.

An entry that restates what the code already says is not worth storing. An entry
that captures something you could only learn by investigating is.

**Checkpoint A3.** Start a new chat and ask:

```
What should I know about this project before changing anything?
```

If the answer reflects what you wrote, `MEMORY.md` is working. If it does not,
your entries are probably too vague to act on.

---

## Core B — Build and verify a pipeline (20 min)

**FULL and CORE only.** REPO-ONLY, skip to Core C.

Build `RAW` → `STAGED` → `CURATED` as dynamic tables over the data you seeded.

### B1. Build it in Plan mode (8 min)

**Use Plan mode.** Generate a plan, read it, change at least one thing, then
build from it.

Requirements for the pipeline:

- **Staged layer:** normalise `order_status` (there are seven raw spellings that
  should collapse to four), drop or quarantine rows with NULL `customer_id`,
  handle the duplicate `order_id` rows, and deal with negative quantities.
  Decide what "handle" means and be able to defend it.
- **Curated layer:** daily revenue per customer, aggregated at the **correct
  grain**. You have just seen what happens when it is not.
- Set `REFRESH_MODE` explicitly on both.
- Pick a `TARGET_LAG` you can justify.

The decisions here are the actual work. Deleting rows with NULL `customer_id` and
quarantining them into a side table are both defensible; picking one without
noticing you made a choice is not.

**Checkpoint B1.**

```sql
SHOW DYNAMIC TABLES IN SCHEMA IDENTIFIER($lab_schema_fqn)
->> SELECT "name", "refresh_mode", "target_lag", "refresh_mode_reason" FROM $1;
```

Every row should show `refresh_mode = INCREMENTAL` and a NULL reason. Then:

```sql
-- Your curated revenue total should match this. If it is higher, you have a fanout.
SELECT SUM(order_total) AS finance_reconciliation_total
FROM RAW_ORDERS
WHERE UPPER(REPLACE(order_status, '_', '')) NOT IN ('CANCELLED', 'DRAFT');
```

### B2. Verify refresh mode, and break it on purpose (5 min)

Run `lab/03_broken_artifacts.sql`. It creates a dynamic table that succeeds and
is quietly wrong.

1. Read the message the `CREATE` statement returns.
2. Find its `refresh_mode` and `refresh_mode_reason`.
3. Try `ALTER DYNAMIC TABLE ... SET REFRESH_MODE = INCREMENTAL`. Note exactly
   what Snowflake says.
4. Recreate it correctly, so the age calculation does not block incremental
   refresh.

The diagnosis is at the bottom of `03_broken_artifacts.sql`. Try it first.

**Checkpoint B2.** You can answer:

- Why did it choose FULL?
- Where was that decision visible, and where was it not?
- Why can't `ALTER` fix it?
- What would have made this a build failure instead of a cost problem?

### B3. Quality checks (7 min) — the fork

#### FULL path: data metric functions

Attach DMFs with named expectations to your staged layer. Cover at least:

- no NULLs in your customer key
- no duplicates on your order key

Use the `WITH DATA METRIC FUNCTION` clause at creation time where you can, and
set a `DATA_METRIC_SCHEDULE`. Then make one fail on purpose and find the result
in `SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS`.

> **Before you leave:** unset your `DATA_METRIC_SCHEDULE`, or run
> `admin/TEARDOWN.sql`. A scheduled DMF keeps consuming serverless credits
> indefinitely. This is on your own account.

#### CORE path: assertion views

No DMF privilege. Build the same checks as views that return **only violating
rows**, so empty means healthy:

```sql
CREATE OR REPLACE VIEW ASSERT_NO_NULL_CUSTOMER AS
SELECT 'null_customer_id' AS assertion, COUNT(*) AS violation_count
FROM STG_ORDERS WHERE customer_id IS NULL
HAVING COUNT(*) > 0;
```

Then a task that queries them and fails loudly if anything returns rows.

Worth knowing what you gave up: DMFs give you scheduling, history, and
expectations as first-class objects. Assertion views give you the same checks
with none of the infrastructure. On a customer engagement without Enterprise
Edition, this is the fallback — so it is worth having built one.

**Checkpoint B3.** At least two checks exist, and at least one is currently
failing because of the seeded dirt. A quality check that has never failed has not
been tested.

---

## Core C — Encode a standard as a skill (12 min)

**Everyone does this**, regardless of verdict. It is the takeaway with the
longest life.

You have spent 40 minutes learning things about this codebase and about dynamic
tables. Right now all of it lives in your head and in one repo's `MEMORY.md`.

### C1. Write the skill (8 min)

Create a skill file at the repo root: `SKILL.md`. CoCo reads any file named
`SKILL.md` (or files in `.cortex-plugin/skills/`) when it starts a session. The
format is plain markdown — rules and reasoning, no special syntax needed. Example
skeleton:

```markdown
# Delivery standards

## Dynamic tables
- Always set REFRESH_MODE explicitly. AUTO silently resolves to FULL when the
  definition contains non-deterministic functions, and ALTER cannot correct it.

## Aggregation grain
- Never sum a header-grain measure after joining to a finer grain. ...

## Staging
- Normalise status values once in the staged layer. ...
```

Fill it with **your** delivery standards. Draw on:

- the conventions you found in Core A
- the `REFRESH_MODE` rule from Core B
- the grain rule — never sum a header-grain measure after joining to a finer grain
- the normalise-once-in-staging rule
- whatever your firm already does that you had to explain to somebody recently

Make it specific enough to act on. "Write good SQL" is not a standard. "Dynamic
tables must set `REFRESH_MODE` explicitly, because `AUTO` silently resolves to
`FULL` and `ALTER` cannot correct it" is.

### C2. Prove it (4 min)

New chat. Ask for something the skill should shape:

```
Add a dynamic table giving weekly revenue per customer segment.
```

Does the output follow your rules without being reminded? If not, your skill is
too vague — tighten it and try again. That iteration *is* the exercise.

**Checkpoint C.** You have a skill file, and a fresh conversation where the
agent applied it unprompted.

### Why this is last

Honestly: its value shows up on your next engagement, not in this room. You
cannot verify a reusable asset by using it once. What you can verify is that it
changes the agent's output, which is what C2 does.

---

## Compare notes (5 min)

Three volunteers, one convention each. Not a demo — the interesting thing is
where people disagreed.

Two things worth surfacing:

- Did anyone handle NULL `customer_id` differently? Both quarantining and
  dropping are defensible. Which did your firm's standard imply?
- Did anyone's skill conflict with someone else's? That is the conversation to
  have before you are on a customer site with two engineers and two standards.

---

## If you finish early

Pick one from [`stretch/`](stretch/):

| | |
|---|---|
| `stretch-a-dbt-local.md` | Port Core B into dbt, run via CoCo's local execution mode |
| `stretch-b-orchestration.md` | Task graph plus a CoCo automation for freshness |
| `stretch-c-cowork-readiness.md` | Semantic view over your curated model — what CoWork needs |

---

## Before you leave

**Run [`admin/TEARDOWN.sql`](../admin/TEARDOWN.sql)**, or at minimum unset any
`DATA_METRIC_SCHEDULE` you set and suspend any tasks you created.

This is your own Snowflake account. A scheduled data metric function left
attached to a table will keep billing serverless credits long after everyone has
forgotten this session happened.
