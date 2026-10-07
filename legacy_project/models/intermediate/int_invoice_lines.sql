-- Invoice lines, linked back to the shipments they bill for.

with invoices as (

    select * from {{ ref('stg_invoices') }}

),

invoice_lines as (

    select * from {{ source('northwind_raw', 'invoice_lines') }}

),

joined as (

    select
        invoice_lines.invoice_line_id,
        invoice_lines.invoice_id,
        invoice_lines.shipment_id,
        invoice_lines.charge_type,
        invoice_lines.charge_amount,
        invoices.customer_id,
        invoices.invoiced_at,
        invoices.payment_status

    from invoice_lines
    inner join invoices
        on invoice_lines.invoice_id = invoices.invoice_id

)

select * from joined
