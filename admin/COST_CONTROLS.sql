/* ============================================================================
   COST_CONTROLS.sql
   Cost controls for the CoCo partner enablement lab.

   Run as ACCOUNTADMIN, AFTER ROLE_AND_GRANTS.sql.

   ---------------------------------------------------------------------------
   WHY THERE ARE THREE LAYERS

   Two different things consume credits, and they are controlled by completely
   different mechanisms. Conflating them is the usual reason "can engineers use
   this?" goes unanswered.

     Warehouse compute   Normal Snowflake compute. Controlled by warehouse
                         sizing, timeouts, and resource monitors. Well
                         understood, and small for this lab.

     CoCo AI credits     Metered separately as AI credits. A resource monitor
                         does NOT cap this. Needs the CoCo-specific controls in
                         Layers 2 and 3.

   Layers, cheapest to implement first:

     Layer 1  Warehouse hygiene and a resource monitor.
     Layer 2  Daily estimated credit limits per CoCo surface. Simplest per-user
              cap. Account or user parameters.
     Layer 3  A per-user quota over the CORTEX CODE domain, with automatic
              block enforcement. The most capable control.

   Layer 1 plus either Layer 2 or Layer 3 is sufficient. Doing both 2 and 3 is
   belt and braces and is fine.

   ---------------------------------------------------------------------------
   EXPECTED SPEND FOR THIS LAB

   15 engineers, 60 minutes.

     Warehouse    Single-digit credits in total. One XSMALL warehouse with
                  AUTO_SUSPEND = 60. The largest single operation is generating
                  ~500k synthetic rows, which takes well under a minute.

     CoCo         Depends on how much the engineers use it, which is the point
                  of the session. The per-user daily limits below are what turn
                  this from open-ended into a number you have chosen.

     Serverless   Only if Tier 3 of ROLE_AND_GRANTS.sql was granted. Data metric
                  functions bill on their schedule. Negligible during the lab;
                  unbounded afterwards if teardown is skipped. See TEARDOWN.sql.

   Set the numbers below to values you are comfortable with. The defaults are
   deliberately conservative.
   ============================================================================ */

USE ROLE ACCOUNTADMIN;

/* ============================================================================
   LAYER 1 — WAREHOUSE HYGIENE AND RESOURCE MONITOR
   ============================================================================ */

-- Statement timeouts on the warehouse. A runaway query in a lab is almost
-- always a mistake rather than real work, so failing fast is the correct
-- behaviour and costs nothing.
--
-- 600s statement timeout: generous for this lab, where the slowest legitimate
--   operation is seeding data.
-- 300s queued timeout: with 15 people on one XSMALL warehouse there will be
--   queueing. Better to error than to accumulate a long queue silently.
ALTER WAREHOUSE COCO_LAB_WH SET
  STATEMENT_TIMEOUT_IN_SECONDS        = 600,
  STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 300;

-- Resource monitor on the lab warehouse.
--
-- Adjust CREDIT_QUOTA to taste. 20 credits is several times the expected spend,
-- which is the right shape for a monitor: it should catch something going
-- wrong, not interrupt the session.
--
-- Triggers are deliberately staged. The SUSPEND at 100% lets running queries
-- finish; SUSPEND_IMMEDIATE at 110% does not. Using only SUSPEND_IMMEDIATE is a
-- common mistake that kills in-flight work for no benefit.
CREATE RESOURCE MONITOR IF NOT EXISTS COCO_LAB_MONITOR WITH
  CREDIT_QUOTA   = 20
  FREQUENCY      = DAILY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS
    ON 75  PERCENT DO NOTIFY
    ON 100 PERCENT DO SUSPEND
    ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE COCO_LAB_WH SET RESOURCE_MONITOR = COCO_LAB_MONITOR;

/* ----------------------------------------------------------------------------
   Note on what a resource monitor does and does not do.

   It caps WAREHOUSE credits only. It has no effect on CoCo AI credits, on
   serverless task credits, or on serverless data metric function credits. If
   Layer 1 is all you configure, CoCo consumption itself is uncapped. That is
   the gap Layers 2 and 3 close.
   ---------------------------------------------------------------------------- */

/* ============================================================================
   LAYER 2 — DAILY ESTIMATED CREDIT LIMITS PER COCO SURFACE

   The simplest CoCo cost control. Blocks a user from a specific CoCo surface
   once their estimated usage in a rolling 24-hour window exceeds the limit.

   Set per surface, because the surfaces are metered separately:
     Desktop    the CoCo desktop IDE  <- what this lab uses
     CLI        the CoCo command line
     Snowsight  CoCo inside Snowsight

   Set at the account level as a default, and optionally override per user.

   Parameter names vary by Snowflake version. Confirm the exact names for your
   account before running this section:

     SHOW PARAMETERS LIKE '%CORTEX_CODE%DAILY%' IN ACCOUNT;

   Then uncomment and set the surface you care about. For this lab, Desktop is
   the one that matters.
   ---------------------------------------------------------------------------- */

-- Inspect what is available and currently set, before changing anything.
SHOW PARAMETERS LIKE '%CORTEX_CODE%' IN ACCOUNT;

-- Account-level default, applying to every user. Uncomment and set the value
-- and the exact parameter name from the SHOW output above.
--
-- ALTER ACCOUNT SET <cortex_code_desktop_daily_credit_limit_parameter> = 5;

-- Per-user override, for anyone who needs more headroom than the default.
--
-- ALTER USER <engineer> SET <cortex_code_desktop_daily_credit_limit_parameter> = 10;

/* ----------------------------------------------------------------------------
   Prefer Layer 3 if you want notifications before the block, visibility into
   per-user spend in Snowsight, or one control covering every CoCo surface at
   once. Layer 2 is the right choice when you want a single number in place with
   no additional objects to manage.
   ---------------------------------------------------------------------------- */

/* ============================================================================
   LAYER 3 — PER-USER QUOTA OVER THE CORTEX CODE DOMAIN

   A first-class quota object with monthly, weekly, and daily per-user limits,
   notifications, and built-in automatic blocking. The CORTEX CODE domain covers
   all three CoCo surfaces in one control.

   Recommended for this lab, because notifications let engineers see they are
   approaching a limit rather than hitting a wall mid-exercise.
   ============================================================================ */

-- Somewhere to keep cost-management objects. Reuse an existing location if you
-- already have one.
CREATE DATABASE IF NOT EXISTS COST_MGMT_DB;
CREATE SCHEMA   IF NOT EXISTS COST_MGMT_DB.QUOTAS;

USE SCHEMA COST_MGMT_DB.QUOTAS;

-- The quota object. Configured by calling methods on it, below.
CREATE SNOWFLAKE.CORE.QUOTA IF NOT EXISTS COCO_LAB_QUOTA();

-- Scope it to CoCo. CORTEX CODE covers CoCo Desktop, CLI, and Snowsight.
CALL COCO_LAB_QUOTA!ADD_SHARED_RESOURCE('CORTEX CODE');

-- Optional: also cover CoWork, if engineers will attempt the CoWork stretch
-- exercise. Note that a quota monitors either warehouse compute or AI domains,
-- never a mix — the units differ. CORTEX CODE and SNOWFLAKE INTELLIGENCE are
-- both AI domains, so combining them is fine.
--
-- CALL COCO_LAB_QUOTA!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');

/* ----------------------------------------------------------------------------
   Scope the quota to the lab attendees.

   By default a new quota monitors EVERY user in the account. For a lab you
   almost certainly want it narrowed, or you will be enforcing limits on people
   who never attended.

   Two ways to narrow it. Naming users directly is simpler for a one-off
   session; tags are better if you want this to keep working as people join.
   ---------------------------------------------------------------------------- */

-- Simpler: name the attendees. Accumulates across calls, so you can add more
-- later without repeating the list.
--
-- CALL COCO_LAB_QUOTA!INCLUDE_USERS(['ENGINEER_1', 'ENGINEER_2', 'ENGINEER_3']);

-- Or exclude everyone else, if your account is small enough that the attendees
-- are effectively everyone.

-- Confirm the scope resolved to the users you expect, before enabling
-- enforcement. Tag-based resolution can lag by up to about two hours, so do
-- this the day before rather than minutes before.
CALL COCO_LAB_QUOTA!GET_QUOTA_SCOPE();
CALL COCO_LAB_QUOTA!GET_USERS();

/* ----------------------------------------------------------------------------
   Set the limits.

   Limits are per user, not pooled, and each cycle is evaluated independently —
   a user is blocked as soon as they cross ANY limit you set.

   For a one-day lab, the daily limit is the one doing the work. The monthly
   limit is a backstop in case the account is left configured afterwards.
   ---------------------------------------------------------------------------- */
CALL COCO_LAB_QUOTA!SET_PER_USER_LIMIT(5,  'DAILY');
CALL COCO_LAB_QUOTA!SET_PER_USER_LIMIT(25, 'MONTHLY');

-- Warn the user at 80% of their daily limit, on actual rather than projected
-- spend. Projected is better for ongoing use, but projections need enough
-- elapsed time in the cycle to mean anything and are not calculated during
-- roughly the first 12 hours of a daily cycle — which is the entire lab.
CALL COCO_LAB_QUOTA!ADD_NOTIFICATION_THRESHOLD(80, 'ACTUAL', TRUE, 'DAILY');

-- Who gets the admin summary when someone crosses a threshold.
-- Each address must be a verified email on a Snowflake user, or the
-- notification is dropped and an event is logged instead.
--
-- CALL COCO_LAB_QUOTA!SET_ADMIN_EMAILS('you@example.com');

/* ----------------------------------------------------------------------------
   Enable block enforcement.

   First argument: enable blocking. Second: email the user when they are
   blocked, so they understand why CoCo stopped responding rather than filing a
   bug. Leave the second TRUE.
   ---------------------------------------------------------------------------- */
CALL COCO_LAB_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE, TRUE);

-- Read back the configuration and confirm it matches what you intended.
CALL COCO_LAB_QUOTA!GET_CONFIG();

/* ----------------------------------------------------------------------------
   TWO CAVEATS, BOTH INHERENT TO HOW ENFORCEMENT WORKS

   1. Enforcement is evaluated within MINUTES of a spend event, not at request
      time. A user can briefly overshoot their limit before the block lands. The
      overshoot is bounded by what they spend in that short window, which is
      small for interactive use. Set the limit with a little headroom rather
      than exactly at your tolerance.

   2. Configuration changes take roughly 5 to 10 MINUTES to propagate, including
      changes to limits and scope. Configure this the day before the session.
      Doing it five minutes beforehand means it is not yet in force.

   Blocks release automatically when the cycle resets — daily at UTC midnight.
   There is no manual unblock step, and none is needed.

   If someone is blocked mid-lab and genuinely needs to continue, raise the
   limit for the whole quota. Blocks clear automatically once the change
   propagates and the user is back under the limit:

     CALL COCO_LAB_QUOTA!SET_PER_USER_LIMIT(10, 'DAILY');
   ---------------------------------------------------------------------------- */

/* ============================================================================
   MONITORING DURING AND AFTER THE SESSION
   ============================================================================ */

-- Who is currently blocked.
CALL COCO_LAB_QUOTA!GET_ACTIVE_BLOCKS_V2();

-- Per-user CoCo spend for the session. Finalized usage only, so there is a lag
-- — expect to run this after the session rather than during it. The date range
-- must fall within the current or prior calendar month.
--
-- CALL COCO_LAB_QUOTA!GET_SPENDING_DETAILS_BY_USERS('2026-09-01', '2026-09-30');

-- Warehouse credits consumed by the lab warehouse.
-- ACCOUNT_USAGE has a latency of up to a few hours, so this is a
-- post-session query rather than a live dashboard.
SELECT
    DATE_TRUNC('hour', start_time) AS hour,
    warehouse_name,
    SUM(credits_used)              AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'COCO_LAB_WH'
  AND start_time >= DATEADD('day', -2, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1;

-- Serverless data metric function spend. Only relevant if Tier 3 of
-- ROLE_AND_GRANTS.sql was granted. If this returns rows days after the session,
-- teardown did not complete and you are still being billed.
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 100;

/* ============================================================================
   TURNING IT ALL OFF

   See TEARDOWN.sql, which removes the quota, the resource monitor, the
   database, the warehouse, and the role, and unsets any data metric function
   schedules.

   The one item that must not be skipped is unsetting DMF schedules. A scheduled
   data metric function left attached to a table keeps consuming serverless
   credits indefinitely, long after everyone has forgotten the session happened.
   ============================================================================ */
