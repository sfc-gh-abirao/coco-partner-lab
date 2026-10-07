/*
    The products source changed shape in Jan 2024 — went from one row per
    product to one row per product per price-book version. This flattens it
    back to current-version-only so downstream doesn't break.

    DP 2024-01-09
*/

select
    p.product_id,
    p.product_name,
    p.product_category,
    p.unit_of_measure,
    p.list_price as list_price_amount,
    p.price_book_version,
    p._loaded_at
from {{ source('northwind_raw', 'products') }} p
where p.price_book_version = (
        select max(price_book_version)
        from {{ source('northwind_raw', 'products') }}
        where product_id = p.product_id
    )
