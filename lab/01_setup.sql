/* ============================================================================
   01_setup.sql
   Creates your personal working schema and sets session context.

   Run AFTER 00_preflight.sql, and only if your verdict was FULL or CORE.
   If your verdict was REPO-ONLY, skip this and open lab/track-zero-privilege.md.

   Idempotent — safe to re-run. It will not destroy work you have already done.

   ---------------------------------------------------------------------------
   Your schema is named after your Snowflake username, so fifteen people can
   share one database without colliding.
   ============================================================================ */

-- Set your role and warehouse. Adjust if you were given different ones.
USE ROLE COCO_LAB_ENGINEER;
USE WAREHOUSE COCO_LAB_WH;

/* ----------------------------------------------------------------------------
   Derive your schema name from your username.

   CURRENT_USER() can contain characters that are not valid unquoted in an
   identifier (dots and hyphens are common in SSO-provisioned accounts).

   Evaluate the sanitization through a scalar SELECT. Direct assignment of
   REGEXP_REPLACE in SET fails with 'assignment from non-constant source
   expression'; the subquery form preserves the intended ENG_<sanitized user>
   naming convention.
   ---------------------------------------------------------------------------- */
SET lab_schema_name = (
    SELECT CONCAT('ENG_', REGEXP_REPLACE(UPPER(CURRENT_USER()), '[^A-Z0-9_]', '_'))
);

SET lab_schema_fqn = 'COCO_LAB.' || $lab_schema_name;

-- Confirm what you are about to create.
SELECT
    CURRENT_USER()     AS username,
    $lab_schema_name   AS your_schema,
    $lab_schema_fqn    AS fully_qualified;

/* ----------------------------------------------------------------------------
   Create it.

   You will own this schema, which implicitly gives you every CREATE privilege
   inside it — tables, views, dynamic tables, tasks. That is why the grants
   script your admin ran is as short as it is.
   ---------------------------------------------------------------------------- */
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($lab_schema_fqn)
  COMMENT = 'CoCo enablement lab. Synthetic data. Safe to drop.';

USE SCHEMA IDENTIFIER($lab_schema_fqn);

/* ----------------------------------------------------------------------------
   Checkpoint.

   Expected: your username, your ENG_* schema, and the COCO_LAB database. If
   current_schema is NULL, the USE SCHEMA above did not take effect — re-run
   from the top before continuing.
   ---------------------------------------------------------------------------- */
SELECT
    CURRENT_USER()      AS username,
    CURRENT_ROLE()      AS active_role,
    CURRENT_DATABASE()  AS current_database,
    CURRENT_SCHEMA()    AS current_schema,
    CURRENT_WAREHOUSE() AS active_warehouse;

/* ============================================================================
   IF THIS FAILED

   "Insufficient privileges to operate on database 'COCO_LAB'"
       Your role lacks CREATE SCHEMA on COCO_LAB. Your pre-flight verdict was
       optimistic — you are effectively REPO-ONLY. Open
       lab/track-zero-privilege.md and tell the facilitator.

   "Database 'COCO_LAB' does not exist or not authorized"
       admin/ROLE_AND_GRANTS.sql has not been run on this account, or it created
       the database under a different name. Ask the facilitator.

   "No active warehouse selected"
       Set one: USE WAREHOUSE COCO_LAB_WH;

   Whatever the error, do not sit waiting for it to be fixed. Open
   lab/track-zero-privilege.md and start there. It needs no Snowflake access and
   covers the most portable parts of the session.
   ============================================================================ */
