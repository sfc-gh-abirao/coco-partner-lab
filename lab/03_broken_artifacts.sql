/* ============================================================================
   03_broken_artifacts.sql
   Creates the things you will diagnose.

   Run AFTER 02_seed_data.sql, in the same session.

   Everything here is created successfully. Nothing errors. That is the point —
   these are the failures that do not announce themselves.

   ---------------------------------------------------------------------------
   DO NOT READ PAST THE ARTIFACT DEFINITIONS IF YOU WANT TO DIAGNOSE THEM
   YOURSELF. The explanation is at the bottom of this file, and the lab guide
   points you here only after you have had a go.
   ============================================================================ */

SET lab_schema_name = (
    SELECT CONCAT('ENG_', REGEXP_REPLACE(UPPER(CURRENT_USER()), '[^A-Z0-9_]', '_'))
);
SET lab_schema_fqn  = 'COCO_LAB.' || $lab_schema_name;
USE SCHEMA IDENTIFIER($lab_schema_fqn);

/* ============================================================================
   ARTIFACT 1 — A dynamic table that a previous engineer left behind

   Latest order per customer, with an age calculation for the ops dashboard.
   Modelled on models/dynamic/dt_shipment_status.sql in legacy_project/, which
   is the same pattern against a different table.

   This creates successfully. Read the status message Snowflake returns.
   ============================================================================ */
CREATE OR REPLACE DYNAMIC TABLE DT_CUSTOMER_LATEST_ORDER
    TARGET_LAG = '4 hours'
    WAREHOUSE  = COCO_LAB_WH
AS
WITH ranked AS (

    SELECT
        order_id,
        customer_id,
        order_status,
        order_placed_at,
        order_total,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY order_placed_at DESC
        ) AS recency_rank
    FROM RAW_ORDERS
    WHERE customer_id IS NOT NULL

),

latest AS (

    SELECT * FROM ranked WHERE recency_rank = 1

)

SELECT
    order_id,
    customer_id,
    order_status,
    order_placed_at,
    order_total,
    DATEDIFF('hour', order_placed_at, CURRENT_TIMESTAMP()) AS hours_since_order
FROM latest;

/* ============================================================================
   ARTIFACT 2 — A revenue rollup the finance team uses

   Revenue by customer and product, so finance can see the product split
   alongside customer totals. Modelled on
   legacy_project/models/marts/revenue_by_customer.sql.

   This runs and returns plausible numbers.
   ============================================================================ */
CREATE OR REPLACE VIEW V_REVENUE_BY_CUSTOMER_PRODUCT AS
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    ol.product_id,
    COUNT(DISTINCT o.order_id)   AS order_count,
    SUM(o.order_total)           AS revenue_amount
FROM RAW_ORDERS o
INNER JOIN RAW_CUSTOMERS c
    ON o.customer_id = c.customer_id
INNER JOIN RAW_ORDER_LINES ol
    ON o.order_id = ol.order_id
WHERE o.order_status NOT IN ('Cancelled', 'DRAFT')
GROUP BY
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    ol.product_id;

/* ----------------------------------------------------------------------------
   And the figure finance actually reconciles against, pulled independently.
   ---------------------------------------------------------------------------- */
CREATE OR REPLACE VIEW V_REVENUE_TOTAL_FINANCE AS
SELECT SUM(order_total) AS revenue_amount
FROM RAW_ORDERS
WHERE order_status NOT IN ('Cancelled', 'DRAFT');

/* ============================================================================
   YOUR STARTING POINT

   Run these three. They are the symptom, not the diagnosis.
   ============================================================================ */

-- 1. What refresh mode did the dynamic table end up with, and why?
SHOW DYNAMIC TABLES LIKE 'DT_CUSTOMER_LATEST_ORDER' IN SCHEMA IDENTIFIER($lab_schema_fqn)
->> SELECT "name", "target_lag", "refresh_mode", "refresh_mode_reason" FROM $1;

-- 2. Do the two revenue figures agree?
SELECT
    (SELECT SUM(revenue_amount) FROM V_REVENUE_BY_CUSTOMER_PRODUCT) AS rollup_total,
    (SELECT revenue_amount      FROM V_REVENUE_TOTAL_FINANCE)       AS finance_total,
    (SELECT SUM(revenue_amount) FROM V_REVENUE_BY_CUSTOMER_PRODUCT)
      - (SELECT revenue_amount  FROM V_REVENUE_TOTAL_FINANCE)       AS difference,
    ROUND(
        (SELECT SUM(revenue_amount) FROM V_REVENUE_BY_CUSTOMER_PRODUCT)
        / NULLIF((SELECT revenue_amount FROM V_REVENUE_TOTAL_FINANCE), 0)
    , 2)                                                            AS ratio;

-- 3. Does the cancelled-order filter do what it claims?
SELECT order_status, COUNT(*) AS row_count
FROM RAW_ORDERS
WHERE order_status NOT IN ('Cancelled', 'DRAFT')
GROUP BY order_status
ORDER BY row_count DESC;

/* ============================================================================
   ============================================================================

                        DIAGNOSIS BELOW — STOP HERE

      Work on it first. The lab guide tells you when to come back and read.

   ============================================================================
   ============================================================================ */

/* ----------------------------------------------------------------------------
   ARTIFACT 1 — Refresh mode

   refresh_mode is FULL, not INCREMENTAL, because REFRESH_MODE was not set and
   the default AUTO evaluated the definition and chose FULL. The cause is
   CURRENT_TIMESTAMP() in the hours_since_order expression: change tracking is
   not supported on non-deterministic functions.

   Why it matters. A FULL refresh recomputes the entire table every time. Here
   that is every 4 hours, forever, over 500k rows — and on a real pipeline over
   hundreds of millions. Nothing fails. The bill just quietly goes up.

   Three things make this worth encoding as a standing rule:

     1. Snowflake DOES tell you, in the status message returned by the CREATE
        statement. You will see it in a worksheet. You will not see it when the
        DDL runs from a deploy script, a task, or CI, which is where production
        DDL actually runs.

     2. After the fact, the only evidence is the refresh_mode and
        refresh_mode_reason columns of SHOW DYNAMIC TABLES. Nobody checks those
        unless they already suspect something.

     3. ALTER cannot fix it. Try it:

              ALTER DYNAMIC TABLE DT_CUSTOMER_LATEST_ORDER
                  SET REFRESH_MODE = INCREMENTAL;

        Snowflake rejects REFRESH_MODE as an invalid property for a dynamic
        table. The refresh mode is fixed at creation. The only route is
        CREATE OR REPLACE.

   The rule worth carrying to customer work: always set REFRESH_MODE explicitly.
   Setting REFRESH_MODE = INCREMENTAL converts this from a silent cost problem
   into a compilation error at create time that names the offending construct —
   it fails your build instead of your budget.

   The fix here is to move the age calculation out of the dynamic table and into
   a view on top of it, so the non-deterministic function is evaluated at query
   time rather than at refresh time.

   ----------------------------------------------------------------------------
   ARTIFACT 2 — Revenue

   The rollup total is several times the finance total — on a reference run,
   6,005,475,697.75 against 2,043,661,340.31, a ratio of 2.94. Both are valid
   SQL.

   V_REVENUE_BY_CUSTOMER_PRODUCT joins RAW_ORDERS to RAW_ORDER_LINES to get
   product_id, then sums o.order_total — an ORDER HEADER amount. The join
   produces one row per order line, so each order's total is counted once per
   line. An order with four lines contributes its full value four times.

   This is a classic fanout. It is easy to miss because:
     - the join is there for a real reason (the product split was requested)
     - the SQL is valid and the numbers look plausible
     - COUNT(DISTINCT o.order_id) in the same query IS correct, which makes the
       whole thing look considered
     - it only overstates, and revenue that looks high rarely gets challenged

   The fix is to sum a line-grain measure — quantity * unit_price — rather than
   a header-grain one, or to aggregate the header separately and join the
   product split on afterwards.

   The same bug is in legacy_project/models/marts/revenue_by_customer.sql. The
   discrepancy is also noted, unresolved, in
   legacy_project/sql/adhoc/finance_month_end.sql.

   ----------------------------------------------------------------------------
   ARTIFACT 3 — The filter that misses rows

   Query 3 still returns cancelled orders. On a reference run, 15,167 of them.

   The seed data contains two spellings, 'Cancelled' and 'CANCELLED'. The filter
   NOT IN ('Cancelled', 'DRAFT') matches exact strings, so it removes one
   spelling and silently keeps the other. Every downstream revenue figure then
   includes cancelled orders.

   Both artifacts above filter on raw status values, and both are wrong in the
   same way for the same reason. That is the argument for normalising status once
   in the staged layer rather than re-filtering in every model that needs it —
   one place to be right, instead of one place per consumer to be wrong.
   ---------------------------------------------------------------------------- */
