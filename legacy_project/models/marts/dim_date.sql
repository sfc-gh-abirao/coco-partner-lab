-- Date spine. 2023-01-01 through 2027-12-31.

with spine as (

    select
        dateadd('day', seq4(), '2023-01-01'::date) as date_day
    from table(generator(rowcount => 1826))

),

final as (

    select
        date_day,
        year(date_day)                    as calendar_year,
        quarter(date_day)                 as calendar_quarter,
        month(date_day)                   as calendar_month,
        monthname(date_day)               as month_name,
        dayofweek(date_day)               as day_of_week,
        dayname(date_day)                 as day_name,
        dayofweek(date_day) in (0, 6)     as is_weekend,
        date_trunc('month', date_day)     as month_start_date,
        last_day(date_day)                as month_end_date

    from spine

)

select * from final
