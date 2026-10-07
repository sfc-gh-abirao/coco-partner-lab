-- Product dimension.
-- Sources from v_raw_products rather than a stg_ model because the products
-- source needed the price-book flattening before anything else could use it.

with products as (

    select * from {{ ref('v_raw_products') }}

),

final as (

    select
        product_id,
        product_name,
        product_category,
        unit_of_measure,
        list_price_amount

    from products

)

select * from final
