-- Shipment legs. Explodes a shipment into its individual legs so ops can see
-- where a delay was introduced.

with shipments as (

    select * from {{ ref('stg_shipments') }}

),

legs as (

    select * from {{ source('northwind_raw', 'shipment_legs') }}

),

joined as (

    select
        legs.shipment_leg_id,
        legs.shipment_id,
        legs.leg_sequence,
        legs.origin_code,
        legs.destination_code,
        legs.departed_at,
        legs.arrived_at,
        shipments.carrier_id,
        shipments.promised_delivery_at,
        datediff('minute', legs.departed_at, legs.arrived_at) as leg_duration_minutes

    from legs
    inner join shipments
        on legs.shipment_id = shipments.shipment_id

)

select * from joined
