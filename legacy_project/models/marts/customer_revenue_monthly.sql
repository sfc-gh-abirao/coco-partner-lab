-- Monthly customer revenue. Grain: customer x month.
-- MO 2024-06-08

with orders as (

    select * from {{ ref('stg_orders') }}

),

monthly as (

    select
        customer_id,
        date_trunc('month', placed_at)      as month_start_date,
        count(*)                            as order_count,
        sum(order_total_amount)             as revenue_amount,
        avg(order_total_amount)             as avg_order_value_amount

    from orders
    where status not in ('CANCELLED', 'DRAFT')
    group by customer_id, date_trunc('month', placed_at)

),

final as (

    select
        monthly.customer_id,
        customers.customer_name,
        customers.customer_segment,
        monthly.month_start_date,
        monthly.order_count,
        monthly.revenue_amount,
        monthly.avg_order_value_amount

    from monthly
    left join {{ ref('stg_customers') }} customers
        on monthly.customer_id = customers.customer_id

)

select * from final
