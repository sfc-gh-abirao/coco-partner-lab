-- Order headers. One row per order.

with source as (

    select * from {{ source('northwind_raw', 'orders') }}

),

renamed as (

    select
        order_id,
        customer_id,
        order_status              as status,
        order_placed_at           as placed_at,
        order_total               as order_total_amount,
        currency_code,
        sales_channel,
        _loaded_at

    from source
    where order_placed_at >= '{{ var("migration_cutoff_date") }}'

)

select * from renamed
