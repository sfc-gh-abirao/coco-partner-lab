-- Order fact. One row per order.

with orders as (

    select * from {{ ref('int_orders_enriched') }}

),

totals as (

    select * from {{ ref('v_order_totals') }}

),

final as (

    select
        orders.order_id,
        orders.customer_id,
        orders.status,
        orders.placed_at,
        orders.sales_channel,
        orders.currency_code,
        orders.order_total_amount,
        totals.computed_total_amount,
        totals.line_count,
        totals.total_quantity,
        abs(coalesce(orders.order_total_amount, 0)
            - coalesce(totals.computed_total_amount, 0)) > 0.01
                                        as has_total_mismatch

    from orders
    left join totals
        on orders.order_id = totals.order_id

)

select * from final
