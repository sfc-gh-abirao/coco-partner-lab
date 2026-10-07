/*
    One-off backfill. The shipment_events connector dropped roughly 40 hours of
    scans during the 2024-05 outage and we re-pulled them into a staging table.

    DO NOT RUN AGAIN. It is not idempotent — running it twice double-inserts,
    which is what happened the first time and is why dt_shipment_status showed
    duplicate scans for a week.

    Kept only as a record of what was done.

    MO 2024-05-22
*/

-- INSERT INTO NORTHWIND.RAW.SHIPMENT_EVENTS (
--     shipment_event_id,
--     shipment_id,
--     event_code,
--     event_description,
--     event_at,
--     facility_code
-- )
-- SELECT
--     shipment_event_id,
--     shipment_id,
--     event_code,
--     event_description,
--     event_at,
--     facility_code
-- FROM NORTHWIND.RAW.SHIPMENT_EVENTS_BACKFILL_20240522;

-- Verification used at the time:
SELECT
    DATE_TRUNC('hour', event_at) AS event_hour,
    COUNT(*)                     AS event_count
FROM NORTHWIND.RAW.SHIPMENT_EVENTS
WHERE event_at >= '2024-05-20'
  AND event_at <  '2024-05-24'
GROUP BY 1
ORDER BY 1;
