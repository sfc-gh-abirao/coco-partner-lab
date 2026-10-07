/*
    Order totals recomputed from lines, because the header order_total on a
    handful of migrated orders doesn't reconcile with the sum of its lines.
    Finance dashboard uses this rather than the header value.

    DP 2023-07-11
    DP 2023-09-14  round to 2dp; was showing 6dp in the dashboard
*/

select
    ol.order_id,
    count(*)                                   as line_count,
    round(sum(ol.line_total_amount), 2)        as computed_total_amount,
    round(sum(ol.quantity), 0)                 as total_quantity
from {{ ref('stg_order_lines') }} ol
where ol.order_id in (
        select order_id
        from {{ ref('stg_orders') }}
    )
group by ol.order_id
