-- Customers. One row per customer.

with source as (

    select * from {{ source('northwind_raw', 'customers') }}

),

renamed as (

    select
        customer_id,
        customer_name,
        customer_segment,
        industry_code,
        account_manager_id,
        signed_up_at,
        is_active,
        _loaded_at

    from source

)

select * from renamed
