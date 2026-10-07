-- Carrier on-time performance. Grain: carrier x month.
-- MO 2024-04-15

with shipments as (

    select * from {{ ref('fct_shipments') }}

),

by_carrier_month as (

    select
        carrier_id,
        carrier_name,
        service_level,
        date_trunc('month', shipped_at)                     as month_start_date,
        count(*)                                            as shipment_count,
        count_if(is_late)                                   as late_shipment_count,
        count_if(is_late) / nullif(count(*), 0)              as late_rate,
        avg(delivery_variance_hours)                        as avg_variance_hours,
        median(delivery_variance_hours)                     as median_variance_hours,
        sum(freight_cost_amount)                            as freight_cost_amount,
        sum(billed_weight_kg)                               as billed_weight_kg

    from shipments
    where actual_delivery_at is not null
    group by 1, 2, 3, 4

)

select * from by_carrier_month
