/*
    Wide customer view for sales ops. They wanted "everything about a customer
    on one row".

    DP 2023-10-05
*/

select
    c.customer_id,
    c.customer_name,
    c.customer_segment,
    c.industry_code,
    c.signed_up_at,
    c.is_active,
    (select count(*) from {{ ref('stg_orders') }} o
      where o.customer_id = c.customer_id)                      as lifetime_order_count,
    (select sum(o.order_total_amount) from {{ ref('stg_orders') }} o
      where o.customer_id = c.customer_id)                      as lifetime_revenue_amount,
    (select max(o.placed_at) from {{ ref('stg_orders') }} o
      where o.customer_id = c.customer_id)                      as last_order_at,
    (select count(*) from {{ ref('stg_invoices') }} i
      where i.customer_id = c.customer_id
        and i.payment_status = 'OVERDUE')                       as overdue_invoice_count,
    (select count(*) from {{ ref('stg_shipments') }} s
      inner join {{ ref('stg_orders') }} o on s.order_id = o.order_id
      where o.customer_id = c.customer_id
        and s.actual_delivery_at > s.promised_delivery_at)       as late_shipment_count
from {{ ref('stg_customers') }} c
