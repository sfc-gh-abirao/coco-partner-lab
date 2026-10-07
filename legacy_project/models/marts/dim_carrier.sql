-- Carrier dimension.

with carriers as (

    select * from {{ ref('stg_carriers') }}

),

final as (

    select
        carrier_id,
        carrier_name,
        carrier_scac,
        service_level

    from carriers

)

select * from final
