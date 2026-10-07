-- Carriers.

with source as (

    select * from {{ source('northwind_raw', 'carriers') }}

),

renamed as (

    select
        carrier_id,
        carrier_name,
        carrier_scac,
        service_level,
        is_test_carrier,
        _loaded_at

    from source

    {% if var('exclude_test_carriers') %}
    where not coalesce(is_test_carrier, false)
    {% endif %}

)

select * from renamed
