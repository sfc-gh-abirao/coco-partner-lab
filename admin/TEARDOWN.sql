/* ============================================================================
   TEARDOWN.sql
   Removes everything created by ROLE_AND_GRANTS.sql, COST_CONTROLS.sql, and the
   lab itself.

   Run as ACCOUNTADMIN, after the session.

   ---------------------------------------------------------------------------
   READ THIS FIRST

   One step here genuinely matters more than the others: unsetting data metric
   function schedules. A scheduled DMF left attached to a table keeps consuming
   serverless credits indefinitely, independently of any warehouse and
   independently of any resource monitor. Nobody notices, because there is no
   warehouse in the query history to look at.

   Dropping the database removes the tables and therefore the associations, so
   Step 3 below covers it. Step 1 exists for the case where you want to keep the
   lab database around but stop the billing.

   Order matters. Suspend before dropping, so nothing fires mid-teardown.
   ============================================================================ */

USE ROLE ACCOUNTADMIN;

/* ============================================================================
   STEP 1 — STOP ANYTHING ON A SCHEDULE

   Do this even if you intend to drop the database, because it is cheap and it
   removes the failure mode where a later step errors out and leaves scheduled
   work running.
   ============================================================================ */

-- Find every task the lab created, across all engineer schemas.
SHOW TASKS IN DATABASE COCO_LAB;

-- Suspend them. Copy the fully-qualified names from the output above.
-- ALTER TASK COCO_LAB.<schema>.<task_name> SUSPEND;

-- Find every table carrying a data metric function schedule. A non-empty value
-- here means the table is being measured on a schedule and billing for it.
SHOW PARAMETERS LIKE 'DATA_METRIC_SCHEDULE' IN DATABASE COCO_LAB;

-- Clear the schedule on any table that has one. Setting it to an empty string
-- suspends every DMF on that table in a single statement, which is easier than
-- dropping each association individually.
-- ALTER TABLE COCO_LAB.<schema>.<table> SET DATA_METRIC_SCHEDULE = '';

/* ============================================================================
   STEP 2 — REMOVE THE QUOTA

   Disabling enforcement first unblocks anyone currently blocked, within about
   5 to 10 minutes. Do this before dropping the quota so nobody is left blocked
   by an object that no longer exists to explain why.
   ============================================================================ */

USE SCHEMA COST_MGMT_DB.QUOTAS;

-- Who is blocked right now. Worth a look: if someone is blocked, they may have
-- been stuck for part of the session and not said anything.
CALL COCO_LAB_QUOTA!GET_ACTIVE_BLOCKS_V2();

-- Optional: capture per-user CoCo spend before you destroy the quota. This is
-- the only convenient per-user view of the session's CoCo consumption, and it
-- is worth keeping if you want to size limits for next time.
-- Adjust the dates; the range must fall in the current or prior calendar month.
--
-- CALL COCO_LAB_QUOTA!GET_SPENDING_DETAILS_BY_USERS('2026-09-01', '2026-09-30');

-- Release any blocks.
CALL COCO_LAB_QUOTA!SET_BLOCK_ENFORCEMENT_ENABLED(FALSE, FALSE);

DROP SNOWFLAKE.CORE.QUOTA IF EXISTS COCO_LAB_QUOTA;

-- Only drop these if you created them for this lab and nothing else uses them.
-- Most accounts will already have a cost-management database worth keeping.
-- DROP SCHEMA   IF EXISTS COST_MGMT_DB.QUOTAS;
-- DROP DATABASE IF EXISTS COST_MGMT_DB;

/* ============================================================================
   STEP 3 — DROP THE LAB OBJECTS

   Dropping the database removes the schemas, tables, dynamic tables, views,
   tasks, and any remaining DMF associations in one statement.
   ============================================================================ */

-- Detach the resource monitor before dropping it, or the drop fails because the
-- warehouse still references it.
ALTER WAREHOUSE IF EXISTS COCO_LAB_WH UNSET RESOURCE_MONITOR;

DROP RESOURCE MONITOR IF EXISTS COCO_LAB_MONITOR;
DROP WAREHOUSE        IF EXISTS COCO_LAB_WH;
DROP DATABASE         IF EXISTS COCO_LAB;
DROP ROLE             IF EXISTS COCO_LAB_ENGINEER;

/* ----------------------------------------------------------------------------
   If you set Layer 2 daily credit limits in COST_CONTROLS.sql, unset them too.
   Use the parameter names you found with SHOW PARAMETERS at the time.

   -- ALTER ACCOUNT UNSET <cortex_code_desktop_daily_credit_limit_parameter>;
   -- ALTER USER <engineer> UNSET <cortex_code_desktop_daily_credit_limit_parameter>;
   ---------------------------------------------------------------------------- */

/* ============================================================================
   STEP 4 — VERIFY

   Every query below should come back empty. Anything that does not is left over.
   ============================================================================ */

SHOW DATABASES         LIKE 'COCO_LAB';
SHOW WAREHOUSES        LIKE 'COCO_LAB_WH';
SHOW ROLES             LIKE 'COCO_LAB_ENGINEER';
SHOW RESOURCE MONITORS LIKE 'COCO_LAB_MONITOR';

/* ----------------------------------------------------------------------------
   The billing check.

   ACCOUNT_USAGE lags by up to a few hours, so run this a day or two later
   rather than immediately. If it returns rows with timestamps after your
   teardown, something is still scheduled and still billing.
   ---------------------------------------------------------------------------- */
SELECT start_time, end_time, credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_QUALITY_MONITORING_USAGE_HISTORY
WHERE start_time >= DATEADD('day', -3, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 50;

SELECT start_time, name, credits_used_compute
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_HISTORY
WHERE service_type ILIKE '%SERVERLESS_TASK%'
  AND start_time >= DATEADD('day', -3, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 50;
