-- Order line items. One row per line per order.

with source as (

    select * from {{ source('northwind_raw', 'order_lines') }}

),

renamed as (

    select
        order_line_id,
        order_id,
        product_id,
        quantity,
        unit_price                as unit_price_amount,
        line_discount_pct,
        quantity * unit_price * (1 - coalesce(line_discount_pct, 0))
                                  as line_total_amount,
        _loaded_at

    from source

)

select * from renamed
