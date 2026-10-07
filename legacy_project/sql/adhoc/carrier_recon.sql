/*
    Carrier invoice reconciliation. Carrier billing vs what we recorded as
    freight cost on the shipment.

    Ran for the Q3 dispute with one of the carriers.

    MO 2024-10-19
*/

WITH invoiced AS (

    SELECT
        s.carrier_id,
        DATE_TRUNC('month', i.invoiced_at) AS month_start_date,
        SUM(il.charge_amount)              AS invoiced_amount
    FROM NORTHWIND.MARTS.FCT_INVOICE_LINES il
    INNER JOIN NORTHWIND.MARTS.FCT_SHIPMENTS s
        ON il.shipment_id = s.shipment_id
    WHERE il.charge_type = 'FREIGHT'
    GROUP BY 1, 2

),

recorded AS (

    SELECT
        carrier_id,
        DATE_TRUNC('month', shipped_at) AS month_start_date,
        SUM(freight_cost_amount)        AS recorded_amount
    FROM NORTHWIND.MARTS.FCT_SHIPMENTS
    GROUP BY 1, 2

)

SELECT
    COALESCE(i.carrier_id, r.carrier_id)             AS carrier_id,
    COALESCE(i.month_start_date, r.month_start_date) AS month_start_date,
    r.recorded_amount,
    i.invoiced_amount,
    i.invoiced_amount - r.recorded_amount            AS variance_amount
FROM recorded r
FULL OUTER JOIN invoiced i
    ON r.carrier_id = i.carrier_id
   AND r.month_start_date = i.month_start_date
WHERE ABS(COALESCE(i.invoiced_amount, 0) - COALESCE(r.recorded_amount, 0)) > 100
ORDER BY ABS(COALESCE(i.invoiced_amount, 0) - COALESCE(r.recorded_amount, 0)) DESC;
