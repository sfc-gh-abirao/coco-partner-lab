# Admin handout: what this lab needs, and what it costs

**Audience:** the Snowflake account administrator who has to approve this.
**Time to read:** about three minutes. You do not need any other file in this repo.

## What is being requested

Roughly 15 engineers need to complete a 60-minute hands-on lab in a Snowflake
account. The lab builds a small data pipeline from synthetic data that the lab
generates itself, and attaches quality checks to it.

You are being asked to run two scripts:

| Script | What it does |
|---|---|
| [`ROLE_AND_GRANTS.sql`](ROLE_AND_GRANTS.sql) | Creates one database, one XSMALL warehouse, and one custom role with least-privilege grants |
| [`COST_CONTROLS.sql`](COST_CONTROLS.sql) | Puts a resource monitor, a statement timeout, and per-user AI credit limits around that role |

Both are idempotent. Run them in that order.

## What it does not touch

Stated plainly, because this is usually the actual question:

- **No production data.** The lab generates its own synthetic orders and
  customers with `GENERATOR`. It reads nothing outside its own schema.
- **No `CREATE DATABASE` on the account.** You create the one database; the lab
  role cannot create more.
- **No `ACCOUNTADMIN`, `SECURITYADMIN`, or `SYSADMIN`.** The lab role is granted
  to `SYSADMIN` for manageability, and inherits nothing from it.
- **No grants on any existing schema.** The role can only see the lab database.
- **No network, storage, or API integrations.** Nothing egresses.

## The grants, in tiers

The script is written in four tiers. **You can stop after any tier** and the lab
still works — it detects what it has and adapts. Tiers 1 and 2 cover the core
exercises.

### Tier 1 — Required

Standard object-creation privileges scoped to a single schema, plus `USAGE` on
one XSMALL warehouse. Nothing here is account-level.

### Tier 2 — Orchestration

`CREATE TASK` on the schema, plus two **account-level** privileges:
`EXECUTE TASK` and `EXECUTE MANAGED TASK`.

These are account-level because of how Snowflake models task execution, not
because the lab needs broad reach: `EXECUTE TASK` lets a role run tasks
*it already owns*, and `EXECUTE MANAGED TASK` lets it create serverless ones. A
role with these privileges still cannot touch a task owned by anyone else.

If you would rather not grant these, decline this tier. The lab's orchestration
step moves to an optional stretch exercise.

### Tier 3 — Data quality (Enterprise Edition only)

`EXECUTE DATA METRIC FUNCTION` on the account, which allows serverless execution
of data metric functions.

Two things to know. First, data quality monitoring requires **Enterprise
Edition** — on Standard, this tier is simply unavailable. Second, this privilege
**cannot be granted to a database role**, because it is account-scoped; it has to
go to the custom account role.

If you decline this tier, the lab substitutes assertion views and a scheduled
task, which test the same conditions using privileges from Tiers 1 and 2.

### Tier 4 — Optional, for the CoWork portion

`CREATE SEMANTIC VIEW` and `CREATE AGENT` on the lab schema, plus the
`SNOWFLAKE.CORTEX_AGENT_USER` database role. Only needed if engineers want to
attempt the optional stretch exercise that ends in Snowflake CoWork. Safe to
decline.

## What it costs

Two separate things consume credits, and they are worth separating because they
are controlled differently.

**Warehouse compute.** One XSMALL warehouse with `AUTO_SUSPEND = 60`. Generating
the synthetic data is the single largest operation and takes well under a minute.
For 15 engineers over a 60-minute lab, expect **single-digit credits in total**.
`COST_CONTROLS.sql` attaches a resource monitor that suspends the warehouse at a
ceiling you set, so this is bounded by construction rather than by trust.

**CoCo itself.** CoCo consumption is metered as AI credits, separately from
warehouse compute. This is the part most admins have no existing control for, so
`COST_CONTROLS.sql` sets up two layers:

- A **daily estimated credit limit** per CoCo surface (Desktop, CLI, Snowsight).
  Simple per-user cap; blocks the user on a rolling 24-hour window once exceeded.
- A **per-user quota** covering the `CORTEX CODE` domain, which spans all three
  CoCo surfaces. Set a daily limit, enable block enforcement, and users are
  blocked automatically at the limit. Blocks release on their own when the cycle
  resets — no manual unblocking.

Two caveats on the quota, both inherent to how it works:

- Enforcement is evaluated **within minutes of a spend event**, not at request
  time. A user can briefly overshoot their limit before the block lands. The
  overshoot is bounded by what they spend in that short window, which is small
  for interactive use.
- Configuration changes take roughly **5 to 10 minutes to propagate**. Set the
  limits the day before, not five minutes before the session.

If serverless data metric functions are in play (Tier 3), they also consume
serverless credits on their schedule. This is the one item that keeps billing
after the session ends if nobody cleans up, which is why teardown matters.

## Afterwards

Run [`TEARDOWN.sql`](TEARDOWN.sql). It drops the database, warehouse, role, and
quota, suspends and drops any tasks, and unsets data metric function schedules.

The one thing that genuinely must not be skipped is unsetting the data metric
function schedules. A scheduled DMF left attached to a table will keep consuming
serverless credits indefinitely, long after everyone has forgotten the session
happened. `TEARDOWN.sql` handles it, but verify the script ran cleanly.

## If you want to reduce scope further

Some engineers will not get grants in time, or will be on Standard Edition. That
is expected and already handled: the lab's pre-flight script reports one of three
verdicts, and there is a complete track that requires **no Snowflake write access
at all**. Those engineers still complete the most transferable parts of the
session. Declining everything is a valid outcome, not a blocker.
