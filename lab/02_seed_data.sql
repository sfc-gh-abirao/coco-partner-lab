/* ============================================================================
   02_seed_data.sql
   Generates the synthetic RAW layer your pipeline will be built on.

   Run AFTER 01_setup.sql, in the same session.

   No files, no stages, no downloads — everything is generated in SQL. Runs in
   well under a minute on an XSMALL warehouse.

   ---------------------------------------------------------------------------
   ABOUT THE DATA

   Northwind Logistics: a freight company. Same fictional customer as
   legacy_project/, so the domain carries across the session.

   The data is deliberately dirty. Real raw layers are, and a pipeline that only
   works on clean input is not a pipeline. What is in here on purpose:

     - about 2% of orders have a NULL customer_id
     - about 1% of order_ids are duplicated
     - order_status uses inconsistent casing and separators, including BOTH
       'Cancelled' and 'CANCELLED', which is what makes a naive
       NOT IN ('Cancelled', ...) filter silently wrong
     - a small number of order lines have negative quantity (returns entered
       against the original order rather than as credit notes)
     - timestamps span 90 days, so incremental refresh is meaningful

   Finding and handling these is the work in Core B. Do not fix them here.
   ============================================================================ */

-- Re-assert context in case you are running this in a fresh session.
SET lab_schema_name = (
    SELECT CONCAT('ENG_', REGEXP_REPLACE(UPPER(CURRENT_USER()), '[^A-Z0-9_]', '_'))
);
SET lab_schema_fqn  = 'COCO_LAB.' || $lab_schema_name;
USE SCHEMA IDENTIFIER($lab_schema_fqn);

/* ============================================================================
   CUSTOMERS — 2,000 rows, clean
   ============================================================================ */
CREATE OR REPLACE TABLE RAW_CUSTOMERS AS
WITH gen AS (
    SELECT
        SEQ4() + 1                            AS rn,
        UNIFORM(1, 5, RANDOM(201))            AS r_segment,
        UNIFORM(1, 6, RANDOM(202))            AS r_country,
        UNIFORM(0, 1200, RANDOM(203))         AS signup_days_ago
    FROM TABLE(GENERATOR(ROWCOUNT => 2000))
)
SELECT
    'CUST-' || LPAD(rn::VARCHAR, 6, '0')      AS customer_id,
    'Northwind Customer ' || rn::VARCHAR      AS customer_name,
    CASE r_segment
        WHEN 1 THEN 'ENTERPRISE'
        WHEN 2 THEN 'MID_MARKET'
        WHEN 3 THEN 'SMB'
        WHEN 4 THEN 'PUBLIC_SECTOR'
        ELSE        'RESELLER'
    END                                       AS customer_segment,
    CASE r_country
        WHEN 1 THEN 'NL' WHEN 2 THEN 'DE' WHEN 3 THEN 'FR'
        WHEN 4 THEN 'BE' WHEN 5 THEN 'GB' ELSE 'PL'
    END                                       AS country_code,
    DATEADD('day', -signup_days_ago, CURRENT_DATE())::DATE AS signed_up_on,
    (MOD(rn, 97) <> 0)                        AS is_active
FROM gen;

/* ============================================================================
   ORDERS — 500,000 rows, with the dirt described above

   Built in two parts:
     base        499,000 distinct orders
     duplicates  ~1% of base re-emitted with the same order_id
   ============================================================================ */
CREATE OR REPLACE TABLE RAW_ORDERS AS
WITH base AS (

    SELECT
        SEQ4() + 1                                   AS rn,
        UNIFORM(1, 2000,   RANDOM(301))              AS cust_seq,
        UNIFORM(0, 10000,  RANDOM(302))              AS r_status,
        UNIFORM(0, 10000,  RANDOM(303))              AS r_nullcust,
        UNIFORM(0, 89,     RANDOM(304))              AS days_ago,
        UNIFORM(0, 86399,  RANDOM(305))              AS secs,
        UNIFORM(2000, 900000, RANDOM(306))           AS cents,
        UNIFORM(1, 4,      RANDOM(307))              AS r_channel
    FROM TABLE(GENERATOR(ROWCOUNT => 499000))

),

shaped AS (

    SELECT
        'ORD-' || LPAD(rn::VARCHAR, 9, '0')          AS order_id,

        -- ~2% NULL customer_id
        IFF(r_nullcust < 200, NULL,
            'CUST-' || LPAD(cust_seq::VARCHAR, 6, '0')) AS customer_id,

        -- Inconsistent casing and separators, as arrives from the source system
        CASE
            WHEN r_status < 5200 THEN 'DELIVERED'
            WHEN r_status < 7000 THEN 'delivered'
            WHEN r_status < 8200 THEN 'In_Transit'
            WHEN r_status < 9000 THEN 'IN_TRANSIT'
            WHEN r_status < 9400 THEN 'Cancelled'
            WHEN r_status < 9700 THEN 'CANCELLED'
            ELSE                      'DRAFT'
        END                                          AS order_status,

        DATEADD('second', secs,
                DATEADD('day', -days_ago, CURRENT_DATE()))::TIMESTAMP_NTZ
                                                     AS order_placed_at,

        (cents / 100.0)::NUMBER(18,2)                AS order_total,
        'EUR'                                        AS currency_code,

        CASE r_channel
            WHEN 1 THEN 'WEB' WHEN 2 THEN 'EDI'
            WHEN 3 THEN 'PHONE' ELSE 'PARTNER_API'
        END                                          AS sales_channel

    FROM base

)

SELECT * FROM shaped
UNION ALL
-- ~1% duplicated order_ids. Same id, slightly later timestamp, as you would see
-- when a source system re-emits a record.
SELECT
    order_id,
    customer_id,
    order_status,
    DATEADD('minute', 7, order_placed_at) AS order_placed_at,
    order_total,
    currency_code,
    sales_channel
FROM shaped
WHERE MOD(TRY_TO_NUMBER(SUBSTR(order_id, 5)), 100) = 0;

/* ============================================================================
   ORDER LINES — roughly 1.25M rows, 1 to 5 per order

   A few lines carry negative quantity. Returns were entered against the
   original order instead of as credit notes.
   ============================================================================ */
CREATE OR REPLACE TABLE RAW_ORDER_LINES AS
WITH orders AS (

    SELECT DISTINCT order_id FROM RAW_ORDERS

),

exploded AS (

    SELECT
        o.order_id,
        l.line_no,
        UNIFORM(1, 400,  RANDOM(401)) AS product_seq,
        UNIFORM(0, 10000, RANDOM(402)) AS r_negative,
        UNIFORM(1, 40,   RANDOM(403)) AS qty,
        UNIFORM(150, 45000, RANDOM(404)) AS unit_cents
    FROM orders o
    JOIN (
        SELECT SEQ4() + 1 AS line_no
        FROM TABLE(GENERATOR(ROWCOUNT => 5))
    ) l
      ON l.line_no <= UNIFORM(1, 5, RANDOM(405))

)

SELECT
    order_id || '-L' || LPAD(line_no::VARCHAR, 2, '0') AS order_line_id,
    order_id,
    'PROD-' || LPAD(product_seq::VARCHAR, 5, '0')      AS product_id,

    -- ~0.4% negative quantity
    IFF(r_negative < 40, -qty, qty)                    AS quantity,

    (unit_cents / 100.0)::NUMBER(18,2)                 AS unit_price
FROM exploded;

/* ============================================================================
   CHECKPOINT

   Run this and compare against the expected values. Approximate is fine —
   the generator is random, so your numbers will differ slightly from anyone
   else's. Order of magnitude is what matters.

   Measured on a reference run, for comparison:
     customer_rows              2,000
     order_rows               503,990   (499,000 base + 4,990 duplicates)
     distinct_order_ids       499,000
     duplicate_order_ids        4,990
     null_customer_pct           2.01
     raw_status_values              7
     normalized_status_values       4
     uppercase_cancelled       15,167   (the rows a naive filter misses)
     order_line_rows        1,496,438
     negative_qty_lines         5,907   (0.39% of lines)
     day_span                      89
   ============================================================================ */
SELECT
    (SELECT COUNT(*) FROM RAW_CUSTOMERS)                        AS customer_rows,
    (SELECT COUNT(*) FROM RAW_ORDERS)                           AS order_rows,
    (SELECT COUNT(DISTINCT order_id) FROM RAW_ORDERS)           AS distinct_order_ids,
    (SELECT COUNT(*) FROM RAW_ORDERS)
      - (SELECT COUNT(DISTINCT order_id) FROM RAW_ORDERS)       AS duplicate_order_ids,
    (SELECT ROUND(100.0 * COUNT_IF(customer_id IS NULL) / COUNT(*), 2)
       FROM RAW_ORDERS)                                         AS null_customer_pct,
    (SELECT COUNT(DISTINCT order_status) FROM RAW_ORDERS)       AS raw_status_values,
    (SELECT COUNT(DISTINCT UPPER(REPLACE(order_status, '_', '')))
       FROM RAW_ORDERS)                                         AS normalized_status_values,
    (SELECT COUNT_IF(order_status = 'CANCELLED') FROM RAW_ORDERS) AS uppercase_cancelled,
    (SELECT COUNT(*) FROM RAW_ORDER_LINES)                      AS order_line_rows,
    (SELECT COUNT_IF(quantity < 0) FROM RAW_ORDER_LINES)        AS negative_qty_lines,
    (SELECT DATEDIFF('day', MIN(order_placed_at), MAX(order_placed_at))
       FROM RAW_ORDERS)                                         AS day_span;

/* ----------------------------------------------------------------------------
   Have a look at the dirt before you start cleaning it. Knowing the shape of
   the mess is the first half of Core B.
   ---------------------------------------------------------------------------- */

-- Every status value and how common it is. Note there are two spellings of
-- cancelled. That matters later.
SELECT order_status, COUNT(*) AS row_count
FROM RAW_ORDERS
GROUP BY order_status
ORDER BY row_count DESC;

-- A few duplicated order_ids, so you can see what the duplication looks like.
SELECT order_id, COUNT(*) AS occurrences
FROM RAW_ORDERS
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY order_id
LIMIT 10;
