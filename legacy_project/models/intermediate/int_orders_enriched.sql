-- Orders with customer attributes attached.

with orders as (

    select * from {{ ref('stg_orders') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

),

joined as (

    select
        orders.order_id,
        orders.customer_id,
        orders.status,
        orders.placed_at,
        orders.order_total_amount,
        orders.currency_code,
        orders.sales_channel,
        customers.customer_name,
        customers.customer_segment,
        customers.industry_code,
        customers.account_manager_id

    from orders
    left join customers
        on orders.customer_id = customers.customer_id

)

select * from joined
