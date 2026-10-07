/*
    Month-end revenue numbers for finance.

    Finance said the revenue pack didn't tie to the GL and asked me to pull the
    numbers directly. These are the ones they signed off on for Aug 2024.

    Ran once, kept in case they ask again.

    MO 2024-09-03
*/

-- Customer revenue, Aug 2024.
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    COUNT(*)                        AS order_count,
    SUM(o.order_total_amount)       AS revenue_amount
FROM NORTHWIND.STAGING.STG_ORDERS o
INNER JOIN NORTHWIND.STAGING.STG_CUSTOMERS c
    ON o.customer_id = c.customer_id
WHERE o.status NOT IN ('CANCELLED', 'DRAFT')
  AND o.placed_at >= '2024-08-01'
  AND o.placed_at <  '2024-09-01'
GROUP BY
    c.customer_id,
    c.customer_name,
    c.customer_segment
ORDER BY revenue_amount DESC;


-- Total for the same period, to tie to the GL.
SELECT
    SUM(order_total_amount) AS total_revenue_amount
FROM NORTHWIND.STAGING.STG_ORDERS
WHERE status NOT IN ('CANCELLED', 'DRAFT')
  AND placed_at >= '2024-08-01'
  AND placed_at <  '2024-09-01';


/*
    Aside, noting it here so I don't forget:

    These numbers don't match what REVENUE_BY_CUSTOMER reports for the same
    month. Mine are lower. Finance says mine are the ones that tie to the GL,
    so I've given them mine and moved on.

    Should work out where the difference comes from at some point.
*/
