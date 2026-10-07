-- Shipment fact. One row per shipment.

with shipments as (

    select * from {{ ref('stg_shipments') }}

),

carriers as (

    select * from {{ ref('stg_carriers') }}

),

final as (

    select
        shipments.shipment_id,
        shipments.order_id,
        shipments.carrier_id,
        carriers.carrier_name,
        carriers.service_level,
        shipments.origin_facility_code,
        shipments.destination_postal_code,
        shipments.shipped_at,
        shipments.promised_delivery_at,
        shipments.actual_delivery_at,
        shipments.status,
        shipments.billed_weight_kg,
        shipments.freight_cost_amount,
        datediff('hour',
                 shipments.promised_delivery_at,
                 shipments.actual_delivery_at)  as delivery_variance_hours,
        shipments.actual_delivery_at > shipments.promised_delivery_at
                                                as is_late

    from shipments
    inner join carriers
        on shipments.carrier_id = carriers.carrier_id

)

select * from final
