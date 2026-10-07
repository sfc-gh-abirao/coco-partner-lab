# CoCo Partner Enablement — Lab Materials

Hands-on materials for a Snowflake CoCo enablement session. Everything here is
designed to be worked through with CoCo Desktop open on a real Snowflake account.

## Getting started

1. **Run [`lab/00_preflight.sql`](lab/00_preflight.sql)** in your Snowflake
   account. It is read-only and prints a verdict: `FULL`, `CORE`, or `REPO-ONLY`.

2. **If your verdict is `FULL` or `CORE`:**
   run [`lab/01_setup.sql`](lab/01_setup.sql), then
   [`lab/02_seed_data.sql`](lab/02_seed_data.sql), then open
   [`lab/LAB_GUIDE.md`](lab/LAB_GUIDE.md).

3. **If your verdict is `REPO-ONLY`:**
   go straight to [`lab/track-zero-privilege.md`](lab/track-zero-privilege.md).
   You will complete the most portable parts of the lab — no Snowflake write
   access needed. Do not wait for grants.

## For your Snowflake admin

Hand them [`admin/ADMIN_HANDOUT.md`](admin/ADMIN_HANDOUT.md). It is one page:
what is being requested, why, what it costs, and how to clean up afterwards.

## Repository layout

```
legacy_project/     A deliberately messy "inherited" dbt project — the exercise subject
lab/                Pre-flight, setup, seed data, lab guide, stretch exercises
admin/              Least-privilege role, grants, cost controls, teardown
```

## When you are done

Run [`lab/99_cleanup.sql`](lab/99_cleanup.sql). It drops your personal schema
and suspends anything you left running, without affecting other attendees.

If you are the account admin cleaning up after the session, run
[`admin/TEARDOWN.sql`](admin/TEARDOWN.sql) instead.

## Caveats

- Everything runs against **your own** Snowflake account. Clean up when done.
- `legacy_project/` is synthetic. It is modelled on real inherited projects, but
  no customer code appears in it.
- Data quality monitoring with data metric functions requires **Enterprise
  Edition**. The lab detects this and provides an equivalent path.
