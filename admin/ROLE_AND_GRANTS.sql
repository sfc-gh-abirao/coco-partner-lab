/* ============================================================================
   ROLE_AND_GRANTS.sql
   Least-privilege role for engineers running the CoCo partner enablement lab.

   Run as ACCOUNTADMIN. Idempotent — safe to re-run.
   Run this BEFORE COST_CONTROLS.sql.

   Read admin/ADMIN_HANDOUT.md first if you want the rationale in prose.

   ---------------------------------------------------------------------------
   IF YOUR NAMING CONVENTIONS DIFFER

   Object names are written literally rather than through session variables, so
   that every statement reads exactly as it will execute. To rename, find and
   replace these three strings:

     COCO_LAB              the lab database
     COCO_LAB_WH           the lab warehouse
     COCO_LAB_ENGINEER     the lab role

   ---------------------------------------------------------------------------
   HOW THIS IS STRUCTURED

   Four tiers. You can stop after any tier; the lab detects what it has and
   adapts. Tiers 1 and 2 cover the core exercises.

     Tier 1  Required. Object creation, scoped to one database. No account
             privileges.
     Tier 2  Orchestration. Adds two account-level task privileges.
     Tier 3  Data quality. Enterprise Edition only. One account privilege.
     Tier 4  Optional. Agents for the CoWork exercise.

   Every grant states what breaks if you omit it, so you can make an informed
   decision rather than granting on faith.
   ============================================================================ */

USE ROLE ACCOUNTADMIN;

/* ============================================================================
   TIER 1 — REQUIRED
   ============================================================================ */

-- The role itself. Nothing is inherited into it; it starts empty.
CREATE ROLE IF NOT EXISTS COCO_LAB_ENGINEER
  COMMENT = 'CoCo partner enablement lab. Least privilege, scoped to COCO_LAB. Safe to drop after the session.';

-- One database for the whole cohort. Engineers each create their own schema
-- inside it (see the CREATE SCHEMA grant below), so you do not need a list of
-- usernames and there is no cross-engineer collision.
CREATE DATABASE IF NOT EXISTS COCO_LAB
  COMMENT = 'CoCo enablement lab. Synthetic data only. Drop after the session.';

-- One XSMALL warehouse. AUTO_SUSPEND = 60 is the main cost guard: the lab is
-- bursty, so the warehouse spends most of the session suspended.
-- INITIALLY_SUSPENDED means creating it costs nothing.
CREATE WAREHOUSE IF NOT EXISTS COCO_LAB_WH WITH
  WAREHOUSE_SIZE       = 'XSMALL'
  AUTO_SUSPEND         = 60
  AUTO_RESUME          = TRUE
  INITIALLY_SUSPENDED  = TRUE
  COMMENT              = 'CoCo enablement lab warehouse.';

-- USAGE on the database.
-- Omit this and: nothing works at all. The role cannot see the database.
GRANT USAGE ON DATABASE COCO_LAB TO ROLE COCO_LAB_ENGINEER;

-- CREATE SCHEMA on the database.
-- This is the load-bearing grant, and it is why this script is short. Each
-- engineer creates their own schema and therefore OWNS it, which implicitly
-- confers every CREATE <object> privilege inside that schema — tables, views,
-- dynamic tables, tasks, and so on. Granting a dozen separate object
-- privileges would be equivalent but harder to read and easier to get wrong.
--
-- Scope note: this permits creating schemas only inside COCO_LAB. The role has
-- no CREATE DATABASE privilege, so it cannot create anything outside it.
--
-- Omit this and: engineers have nowhere to work. You would need to pre-create
-- one schema per engineer and grant on each — see the ALTERNATIVE block at the
-- bottom of this file.
GRANT CREATE SCHEMA ON DATABASE COCO_LAB TO ROLE COCO_LAB_ENGINEER;

-- USAGE on the warehouse.
-- Omit this and: every query fails with no active warehouse. Dynamic table
-- refreshes also fail, because refreshes run as the OWNING role and need
-- warehouse USAGE at refresh time, not only at creation time. That distinction
-- causes pipelines that create cleanly and then silently stop refreshing.
GRANT USAGE ON WAREHOUSE COCO_LAB_WH TO ROLE COCO_LAB_ENGINEER;

-- Cortex access, for CoCo itself.
-- CORTEX_USER is granted to PUBLIC by default in most accounts, so this is
-- usually a no-op. Run it anyway: if your account has revoked it from PUBLIC to
-- control Cortex access, the lab role needs it explicitly.
--
-- Omit this and: CoCo cannot make model calls. The lab is unusable.
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE COCO_LAB_ENGINEER;

-- Make the role manageable by your normal admin hierarchy.
GRANT ROLE COCO_LAB_ENGINEER TO ROLE SYSADMIN;

-- Grant to attendees. Replace with your actual usernames, or grant to an
-- existing group role if you provision access that way.
-- GRANT ROLE COCO_LAB_ENGINEER TO USER <engineer_1>;
-- GRANT ROLE COCO_LAB_ENGINEER TO USER <engineer_2>;
-- ...

/* ============================================================================
   TIER 2 — ORCHESTRATION
   Needed for the lab's task-based quality checks and the orchestration stretch
   exercise. Decline this tier and those become optional.
   ============================================================================ */

-- EXECUTE TASK on the account.
-- Account-level because of how Snowflake models task execution, not because
-- the lab needs reach. This privilege lets a role run tasks IT ALREADY OWNS.
-- It confers nothing over tasks owned by any other role.
--
-- Omit this and: ALTER TASK ... RESUME fails. Tasks can be created but never
-- run. This surprises people, because CREATE TASK alone looks sufficient and
-- is not.
GRANT EXECUTE TASK ON ACCOUNT TO ROLE COCO_LAB_ENGINEER;

-- EXECUTE MANAGED TASK on the account.
-- Required only for serverless tasks — those created without a WAREHOUSE
-- clause. The lab uses serverless tasks so quality checks do not contend with
-- the shared lab warehouse.
--
-- Omit this and: serverless task creation fails. You can decline this one
-- specifically and have engineers name COCO_LAB_WH in their tasks instead, in
-- which case Tier 2 needs only EXECUTE TASK.
GRANT EXECUTE MANAGED TASK ON ACCOUNT TO ROLE COCO_LAB_ENGINEER;

/* ============================================================================
   TIER 3 — DATA QUALITY  (Enterprise Edition only)

   On Standard Edition, skip this tier entirely. Data Quality Monitoring is not
   available, and the lab substitutes assertion views plus a scheduled task
   that test the same conditions using Tier 1 and 2 privileges only.
   ============================================================================ */

-- EXECUTE DATA METRIC FUNCTION on the account.
-- Allows serverless execution of data metric functions (DMFs).
--
-- Two things worth knowing before you decide:
--
--   1. This CANNOT be granted to a database role. It is account-scoped, and
--      database roles are confined to the database they live in. It has to go
--      to the custom account role. If you have a standing policy of granting
--      only database roles, this tier is the exception, and declining it is a
--      reasonable call.
--
--   2. Serverless DMFs bill on their schedule, independently of any warehouse.
--      This is the one item in this script that keeps costing money after the
--      session ends if teardown is skipped. TEARDOWN.sql unsets the schedules;
--      please confirm it ran cleanly.
--
-- Omit this and: ALTER TABLE ... ADD DATA METRIC FUNCTION fails with an
-- insufficient-privileges error, and the lab falls back to assertion views.
GRANT EXECUTE DATA METRIC FUNCTION ON ACCOUNT TO ROLE COCO_LAB_ENGINEER;

-- Lets engineers read their own DMF results from
-- SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS.
--
-- Omit this and: DMFs run and record results, but engineers cannot see them,
-- which makes the exercise pointless. Grant both or neither.
GRANT APPLICATION ROLE SNOWFLAKE.DATA_QUALITY_MONITORING_VIEWER
  TO ROLE COCO_LAB_ENGINEER;

/* ============================================================================
   TIER 4 — OPTIONAL, FOR THE COWORK STRETCH EXERCISE
   Only needed by engineers attempting the optional exercise that ends in
   Snowflake CoWork. Safe to decline; the lab marks it optional.
   ============================================================================ */

-- Access to the Cortex Agents API, which is what CoWork runs on.
-- If CORTEX_USER is still granted to PUBLIC in your account this is redundant.
-- It matters when you have revoked Cortex from PUBLIC and want to allow agent
-- access specifically rather than all Cortex features.
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE COCO_LAB_ENGINEER;

-- Note on CREATE SEMANTIC VIEW and CREATE AGENT: no grant is needed here,
-- because engineers own the schemas they create under Tier 1 and ownership
-- already confers both. If you used the ALTERNATIVE block below instead, they
-- do NOT own their schemas and you must grant these two explicitly. The
-- ALTERNATIVE block includes them.

/* ============================================================================
   VERIFICATION
   Run these and read the output before telling engineers they are good to go.
   ============================================================================ */

-- Everything the role now holds. Expect USAGE + CREATE SCHEMA on COCO_LAB,
-- USAGE on COCO_LAB_WH, and whichever account privileges you granted.
SHOW GRANTS TO ROLE COCO_LAB_ENGINEER;

-- Anything granted outside the lab database or warehouse. Should return zero
-- rows. Any row here is something you did not intend to grant.
SELECT "privilege", "granted_on", "name"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "granted_on" NOT IN ('ACCOUNT', 'ROLE', 'DATABASE_ROLE', 'APPLICATION_ROLE')
  AND "name" NOT LIKE 'COCO_LAB%';

/* ----------------------------------------------------------------------------
   THE VERIFICATION THAT ACTUALLY MATTERS

   The queries above prove the grants exist. They do not prove the grants are
   sufficient. Before the session, have one person do this end to end:

     USE ROLE COCO_LAB_ENGINEER;
     -- run lab/00_preflight.sql, lab/01_setup.sql, lab/02_seed_data.sql
     -- then work through lab/LAB_GUIDE.md

   If any lab step fails for want of a privilege, this script is wrong and needs
   fixing before fifteen people hit the same wall simultaneously. A grants
   script that has never been exercised as the target role is a guess.
   ---------------------------------------------------------------------------- */

/* ============================================================================
   ALTERNATIVE — IF YOU WILL NOT GRANT CREATE SCHEMA

   Some accounts have a standing policy against CREATE SCHEMA even within a
   scoped database. In that case, pre-create one schema per engineer and grant
   object privileges explicitly. More statements, same outcome, except that
   engineers no longer own their schemas — which is why the semantic view and
   agent grants become necessary here rather than implicit.

   Repeat per engineer, substituting their username:

     CREATE SCHEMA IF NOT EXISTS COCO_LAB.ENG_ALICE;

     GRANT USAGE                ON SCHEMA COCO_LAB.ENG_ALICE TO ROLE COCO_LAB_ENGINEER;
     GRANT CREATE TABLE         ON SCHEMA COCO_LAB.ENG_ALICE TO ROLE COCO_LAB_ENGINEER;
     GRANT CREATE VIEW          ON SCHEMA COCO_LAB.ENG_ALICE TO ROLE COCO_LAB_ENGINEER;
     GRANT CREATE DYNAMIC TABLE ON SCHEMA COCO_LAB.ENG_ALICE TO ROLE COCO_LAB_ENGINEER;
     GRANT CREATE TASK          ON SCHEMA COCO_LAB.ENG_ALICE TO ROLE COCO_LAB_ENGINEER;  -- Tier 2
     GRANT CREATE SEMANTIC VIEW ON SCHEMA COCO_LAB.ENG_ALICE TO ROLE COCO_LAB_ENGINEER;  -- Tier 4
     GRANT CREATE AGENT         ON SCHEMA COCO_LAB.ENG_ALICE TO ROLE COCO_LAB_ENGINEER;  -- Tier 4

   One caveat specific to this path. Incremental dynamic tables need change
   tracking on their base tables, and Snowflake enables it automatically only
   when the creating role owns those base tables. Engineers still own the tables
   they create here, so this works. But if you ALSO pre-create the base tables as
   ACCOUNTADMIN, change tracking cannot be auto-enabled and dynamic table
   creation fails with an insufficient-privileges error naming CHANGE_TRACKING.
   Create the schemas, not the tables.
   ============================================================================ */
