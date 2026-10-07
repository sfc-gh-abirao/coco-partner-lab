/* ============================================================================
   00_preflight.sql
   Run this FIRST. It is entirely read-only — it creates nothing, changes
   nothing, and costs effectively nothing.

   It tells you which parts of the lab your Snowflake role can complete, so you
   find out now rather than twenty minutes in.

   HOW TO RUN
     1. Set your role and warehouse in the session (or in your CoCo connection).
     2. Run the whole file top to bottom.
     3. Read the VERDICT in Section 3.
     4. Report your verdict to the facilitator before the session if you can.

   Every attendee has a complete path through the lab. There is no verdict that
   means "sit and watch".
   ============================================================================ */

/* ----------------------------------------------------------------------------
   SECTION 1 — WHO AM I
   If the role or warehouse here is not what you expect, fix that before
   reading anything else.
   ---------------------------------------------------------------------------- */
SELECT
    CURRENT_ACCOUNT()   AS account,
    CURRENT_REGION()    AS region,
    CURRENT_USER()      AS username,
    CURRENT_ROLE()      AS active_role,
    CURRENT_WAREHOUSE() AS active_warehouse,
    CURRENT_VERSION()   AS snowflake_version;

/* ----------------------------------------------------------------------------
   If active_warehouse came back NULL, set one now. Nothing in the lab runs
   without it:

     USE WAREHOUSE COCO_LAB_WH;   -- or whichever warehouse you were given
   ---------------------------------------------------------------------------- */

/* ----------------------------------------------------------------------------
   SECTION 2 — WHAT CAN THIS ROLE DO

   Replace COCO_LAB_ENGINEER below with your active role if it differs. The
   ->> pipe operator post-processes the SHOW output as a single statement, so
   there is nothing to run in the right order and nothing to get wrong.
   ---------------------------------------------------------------------------- */
SHOW GRANTS TO ROLE COCO_LAB_ENGINEER
->> SELECT
        COALESCE(BOOLOR_AGG("privilege" = 'CREATE SCHEMA'
                            AND "granted_on" = 'DATABASE'),   FALSE) AS can_create_schema,
        COALESCE(BOOLOR_AGG("privilege" IN ('USAGE','OWNERSHIP')
                            AND "granted_on" = 'WAREHOUSE'),  FALSE) AS has_warehouse_grant,
        COALESCE(BOOLOR_AGG("privilege" = 'EXECUTE TASK'),    FALSE) AS can_run_tasks,
        COALESCE(BOOLOR_AGG("privilege" = 'EXECUTE MANAGED TASK'),
                                                              FALSE) AS can_run_serverless_tasks,
        COALESCE(BOOLOR_AGG("privilege" = 'EXECUTE DATA METRIC FUNCTION'),
                                                              FALSE) AS can_attach_dmfs,
        COUNT(*)                                                     AS grants_examined
    FROM $1;

/* ----------------------------------------------------------------------------
   SECTION 3 — THE VERDICT
   Read the verdict and what_to_do columns. That is your instruction for the lab.
   ---------------------------------------------------------------------------- */
SHOW GRANTS TO ROLE COCO_LAB_ENGINEER
->> SELECT
        CASE
            WHEN can_create_schema AND has_warehouse_grant AND can_attach_dmfs THEN 'FULL'
            WHEN can_create_schema AND has_warehouse_grant                     THEN 'CORE'
            ELSE 'REPO-ONLY'
        END AS verdict,

        CASE
            WHEN can_create_schema AND has_warehouse_grant AND can_attach_dmfs
                THEN 'Everything is available. Run 01_setup.sql, then 02_seed_data.sql, then open lab/LAB_GUIDE.md.'
            WHEN can_create_schema AND has_warehouse_grant
                THEN 'Dynamic tables are available; data metric functions are not. Run 01_setup.sql and 02_seed_data.sql, then open lab/LAB_GUIDE.md and take the CORE path wherever it forks. You will build assertion views instead of DMFs, which test the same conditions.'
            ELSE 'No Snowflake write access detected. Open lab/track-zero-privilege.md instead. You will do Core A and Core C, which need no Snowflake privileges at all and are the most portable parts of this session. Do not wait for grants.'
        END AS what_to_do,

        IFF(can_run_tasks, 'yes',
            'no — the orchestration step becomes optional') AS orchestration_available,

        OBJECT_CONSTRUCT(
            'can_create_schema',        can_create_schema,
            'has_warehouse_grant',      has_warehouse_grant,
            'can_run_tasks',            can_run_tasks,
            'can_run_serverless_tasks', can_run_serverless_tasks,
            'can_attach_dmfs',          can_attach_dmfs
        ) AS detail
    FROM (
        SELECT
            COALESCE(BOOLOR_AGG("privilege" = 'CREATE SCHEMA'
                                AND "granted_on" = 'DATABASE'),  FALSE) AS can_create_schema,
            COALESCE(BOOLOR_AGG("privilege" IN ('USAGE','OWNERSHIP')
                                AND "granted_on" = 'WAREHOUSE'), FALSE) AS has_warehouse_grant,
            COALESCE(BOOLOR_AGG("privilege" = 'EXECUTE TASK'),   FALSE) AS can_run_tasks,
            COALESCE(BOOLOR_AGG("privilege" = 'EXECUTE MANAGED TASK'),
                                                                 FALSE) AS can_run_serverless_tasks,
            COALESCE(BOOLOR_AGG("privilege" = 'EXECUTE DATA METRIC FUNCTION'),
                                                                 FALSE) AS can_attach_dmfs
        FROM $1
    );

/* ============================================================================
   THREE HONEST CAVEATS ABOUT THE VERDICT

   1. SHOW GRANTS TO ROLE reports privileges granted DIRECTLY to the named role.
      If you inherit privileges through a role hierarchy, this under-reports and
      your real verdict may be better than what it says. Re-run it naming the
      specific role you were given for the lab.

   2. A privilege existing is not the same as it working. The definitive test is
      01_setup.sql actually succeeding. If the verdict says FULL and setup then
      fails, trust setup and tell the facilitator — that means the grants script
      is wrong, which is worth knowing.

   3. This file does not test your Snowflake edition, because it does not need
      to. Data metric functions require Enterprise Edition AND an account-level
      privilege. If either is missing you cannot attach one, so the single
      can_attach_dmfs flag covers both cases.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   SECTION 4 — OPTIONAL: ANYTHING LEFT OVER FROM A PREVIOUS RUN
   Should return no rows on a first run. Errors harmlessly if COCO_LAB does not
   exist yet, which is itself a useful signal.
   ---------------------------------------------------------------------------- */
SHOW SCHEMAS LIKE 'ENG_%' IN DATABASE COCO_LAB;
