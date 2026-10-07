-- Shipments. One row per shipment. A shipment can cover multiple orders.

with source as (

    select * from {{ source('northwind_raw', 'shipments') }}

),

renamed as (

    select
        shipment_id,
        order_id,
        carrier_id,
        origin_facility_code,
        destination_postal_code,
        shipped_at,
        promised_delivery_at,
        actual_delivery_at,
        shipment_status           as status,
        billed_weight_kg,
        freight_cost              as freight_cost_amount,
        _loaded_at

    from source
    where shipped_at >= '{{ var("migration_cutoff_date") }}'

)

select * from renamed
