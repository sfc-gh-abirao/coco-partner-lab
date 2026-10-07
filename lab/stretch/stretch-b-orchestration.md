# Stretch B — Orchestration and automation

**15–20 min. Needs `FULL` or `CORE` plus `EXECUTE TASK`, and Core B finished.**

Two different things that both look like scheduling, and are worth separating.

---

## Part 1 — A task graph for the checks

Dynamic tables refresh themselves on `TARGET_LAG`. You do not orchestrate them.
What you do orchestrate is everything around them: quality checks, reconciliation,
and what happens when a check fails.

Build a small graph:

```
root task (scheduled)
  └── run quality checks
        └── reconcile curated total against the finance figure
              └── on failure, notify
```

Points worth getting right:

- Set `SUSPEND_TASK_AFTER_NUM_FAILURES`. A task that fails every ten minutes
  forever is a cost problem, not just a broken pipeline.
- Consider `WHEN SYSTEM$STREAM_HAS_DATA(...)` so the graph only runs when
  something changed. A polling task that finds nothing still costs money.
- If you use serverless tasks, you need `EXECUTE MANAGED TASK` as well as
  `EXECUTE TASK`. If pre-flight said you only have the latter, name a warehouse
  explicitly instead.

Use the `snowflake-tasks` skill. Ask it to review your graph for the failure
modes you have not thought about.

### Checkpoint 1

- The graph runs end to end via `EXECUTE TASK` on the root
- It fails when your seeded dirt violates a check
- `SUSPEND_TASK_AFTER_NUM_FAILURES` is set

---

## Part 2 — A CoCo automation

Different mechanism, different purpose. A Snowflake task runs SQL. A **CoCo
automation** re-runs an agent prompt on a schedule, which is the right tool when
the output needs judgement rather than a boolean.

Set one up that checks pipeline freshness and summarises anything that looks
wrong.

The distinction worth internalising, because customers conflate them:

| | Task | CoCo automation |
|---|---|---|
| Runs | SQL | An agent prompt |
| Output | Rows, or a failure | A written assessment |
| Good for | Deterministic checks, circuit breakers | Digests, triage, "is anything odd" |
| Bad for | Anything needing interpretation | Anything needing a hard pass/fail gate |

Do not replace a circuit breaker with an automation. A quality gate should be
deterministic. An automation is for the weekly summary somebody actually reads.

### Checkpoint 2

- An automation exists and has run once
- You can state which of your checks belongs in a task and which in an
  automation, and why

---

## Before you leave

Suspend or drop every task you created. `admin/TEARDOWN.sql` does it, but check
`SHOW TASKS` yourself — a scheduled task on your own account outlives your
interest in it.
