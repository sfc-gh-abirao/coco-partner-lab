-- Invoice line fact. One row per invoice line.

with invoice_lines as (

    select * from {{ ref('int_invoice_lines') }}

),

final as (

    select
        invoice_line_id,
        invoice_id,
        shipment_id,
        customer_id,
        charge_type,
        charge_amount,
        invoiced_at,
        payment_status

    from invoice_lines

)

select * from final
