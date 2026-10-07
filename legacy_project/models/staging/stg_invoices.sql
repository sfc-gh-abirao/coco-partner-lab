-- Invoices. One row per invoice. An invoice can cover multiple shipments.

with source as (

    select * from {{ source('northwind_raw', 'invoices') }}

),

renamed as (

    select
        invoice_id,
        customer_id,
        invoice_number,
        invoiced_at,
        due_at,
        invoice_total             as invoice_total_amount,
        currency_code,
        payment_status,
        _loaded_at

    from source

)

select * from renamed
