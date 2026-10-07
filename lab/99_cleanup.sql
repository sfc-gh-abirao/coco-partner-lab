/* ============================================================================
   99_cleanup.sql
   Cleans up YOUR lab work without touching anyone else's.

   Run this when you are finished. It drops your personal schema and suspends
   anything you left running. It does NOT drop the shared database, warehouse,
   or role — that is the admin's job after the session.

   Safe to run multiple times. Errors on objects that do not exist are harmless.
   ============================================================================ */

USE ROLE COCO_LAB_ENGINEER;
USE WAREHOUSE COCO_LAB_WH;

-- Derive your schema name, same logic as 01_setup.sql.
SET lab_schema_name = (
    SELECT CONCAT('ENG_', REGEXP_REPLACE(UPPER(CURRENT_USER()), '[^A-Z0-9_]', '_'))
);
SET lab_schema_fqn = 'COCO_LAB.' || $lab_schema_name;

-- Show what is about to be dropped.
SELECT $lab_schema_fqn AS schema_to_drop;

/* ----------------------------------------------------------------------------
   Suspend any tasks first. A running task blocks schema drops.
   ---------------------------------------------------------------------------- */
SHOW TASKS IN SCHEMA IDENTIFIER($lab_schema_fqn);

-- Suspend each task. If you created more than three, add lines.
-- Errors harmlessly if the task does not exist.
BEGIN
    FOR task_row IN (
        SELECT "name" AS task_name
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        WHERE "state" = 'started'
    )
    DO
        EXECUTE IMMEDIATE 'ALTER TASK ' || $lab_schema_fqn || '.' || task_row.task_name || ' SUSPEND';
    END FOR;
END;

/* ----------------------------------------------------------------------------
   Suspend any dynamic tables so they stop refreshing immediately.
   ---------------------------------------------------------------------------- */
SHOW DYNAMIC TABLES IN SCHEMA IDENTIFIER($lab_schema_fqn);

BEGIN
    FOR dt_row IN (
        SELECT "name" AS dt_name
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    )
    DO
        EXECUTE IMMEDIATE 'ALTER DYNAMIC TABLE ' || $lab_schema_fqn || '.' || dt_row.dt_name || ' SUSPEND';
    END FOR;
END;

/* ----------------------------------------------------------------------------
   Drop the schema. CASCADE removes everything in it.
   ---------------------------------------------------------------------------- */
DROP SCHEMA IF EXISTS IDENTIFIER($lab_schema_fqn);

/* ----------------------------------------------------------------------------
   Confirm.
   ---------------------------------------------------------------------------- */
SELECT
    CURRENT_USER()    AS username,
    $lab_schema_fqn   AS dropped_schema,
    'Clean. Nothing left running on your account.' AS status;
