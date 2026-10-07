-- Customer addresses. NOTE: multiple rows per customer — one per address type
-- (billing, shipping, registered). Join carefully.

with source as (

    select * from {{ source('northwind_raw', 'customer_addresses') }}

),

renamed as (

    select
        customer_address_id,
        customer_id,
        address_type,
        city,
        state_province,
        postal_code,
        country_code,
        is_primary,
        _loaded_at

    from source

)

select * from renamed
