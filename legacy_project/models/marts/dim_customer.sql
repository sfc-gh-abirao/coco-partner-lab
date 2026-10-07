-- Customer dimension. SCD type 1 — we overwrite, no history.

with customers as (

    select * from {{ ref('stg_customers') }}

),

primary_address as (

    select
        customer_id,
        city,
        state_province,
        country_code
    from {{ ref('stg_customer_addresses') }}
    where is_primary
      and address_type = 'BILLING'

),

final as (

    select
        customers.customer_id,
        customers.customer_name,
        customers.customer_segment,
        customers.industry_code,
        customers.account_manager_id,
        customers.signed_up_at,
        customers.is_active,
        primary_address.city,
        primary_address.state_province,
        primary_address.country_code

    from customers
    left join primary_address
        on customers.customer_id = primary_address.customer_id

)

select * from final
