/*
    dt_shipment_status
    Near-real-time shipment status for the ops tracking dashboard.

    Not managed by dbt — models/dynamic is disabled in dbt_project.yml. This is
    applied by hand. See the runbook in Confluence (link rotted, ask Marcus).

    MO 2024-07-30
*/

CREATE OR REPLACE DYNAMIC TABLE NORTHWIND.MARTS.DT_SHIPMENT_STATUS
    TARGET_LAG = '4 hours'
    WAREHOUSE  = NORTHWIND_TRANSFORM_WH
AS
WITH status_events AS (

    SELECT
        e.shipment_id,
        e.event_code,
        e.event_description,
        e.event_at,
        e.facility_code,
        ROW_NUMBER() OVER (
            PARTITION BY e.shipment_id
            ORDER BY e.event_at DESC
        ) AS event_recency_rank
    FROM NORTHWIND.RAW.SHIPMENT_EVENTS e

),

latest_status AS (

    SELECT
        shipment_id,
        event_code      AS current_status_code,
        event_description AS current_status_description,
        event_at        AS status_as_of,
        facility_code   AS last_seen_facility_code
    FROM status_events
    WHERE event_recency_rank = 1

)

SELECT
    s.shipment_id,
    s.order_id,
    s.carrier_id,
    s.destination_postal_code,
    s.shipped_at,
    s.promised_delivery_at,
    ls.current_status_code,
    ls.current_status_description,
    ls.status_as_of,
    ls.last_seen_facility_code,
    DATEDIFF('hour', ls.status_as_of, CURRENT_TIMESTAMP()) AS hours_since_last_scan,
    CASE
        WHEN ls.current_status_code = 'DLV' THEN FALSE
        WHEN CURRENT_TIMESTAMP() > s.promised_delivery_at THEN TRUE
        ELSE FALSE
    END AS is_past_promise
FROM NORTHWIND.STAGING.STG_SHIPMENTS s
LEFT JOIN latest_status ls
    ON s.shipment_id = ls.shipment_id;
