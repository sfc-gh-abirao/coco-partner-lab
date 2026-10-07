/*
    Customer revenue rollup. Finance consumes this directly — it feeds the
    monthly revenue pack, so don't rename columns without telling them.

    Requested by finance 2024-02. They wanted revenue split out by product
    category alongside the customer totals, so this joins through to the line
    items to pick up the category.

    DP 2024-02-27
*/

select
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    p.product_category,
    count(distinct o.order_id)          as order_count,
    sum(o.order_total_amount)           as revenue_amount,
    min(o.placed_at)                    as first_order_at,
    max(o.placed_at)                    as last_order_at
from {{ ref('stg_orders') }} o
inner join {{ ref('stg_customers') }} c
    on o.customer_id = c.customer_id
inner join {{ ref('stg_order_lines') }} ol
    on o.order_id = ol.order_id
inner join {{ ref('v_raw_products') }} p
    on ol.product_id = p.product_id
where o.status not in ('CANCELLED', 'DRAFT')
group by
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    p.product_category
