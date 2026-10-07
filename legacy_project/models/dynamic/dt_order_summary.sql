/*
    dt_order_summary
    Rolling order summary for the ops dashboard's order panel.

    Setting REFRESH_MODE explicitly here. The shipment status one surprised us
    and I don't want to repeat it.

    MO 2024-08-12
*/

CREATE OR REPLACE DYNAMIC TABLE NORTHWIND.MARTS.DT_ORDER_SUMMARY
    TARGET_LAG   = '1 hour'
    WAREHOUSE    = NORTHWIND_TRANSFORM_WH
    REFRESH_MODE = INCREMENTAL
AS
SELECT
    o.order_id,
    o.customer_id,
    o.status,
    o.placed_at,
    o.order_total_amount,
    o.sales_channel,
    COUNT(ol.order_line_id)      AS line_count,
    SUM(ol.quantity)             AS total_quantity,
    SUM(ol.line_total_amount)    AS computed_total_amount
FROM NORTHWIND.STAGING.STG_ORDERS o
LEFT JOIN NORTHWIND.STAGING.STG_ORDER_LINES ol
    ON o.order_id = ol.order_id
GROUP BY
    o.order_id,
    o.customer_id,
    o.status,
    o.placed_at,
    o.order_total_amount,
    o.sales_channel;
