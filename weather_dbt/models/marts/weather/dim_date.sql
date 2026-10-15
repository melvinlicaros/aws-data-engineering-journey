with numbers as (

    select row_number() over (order by seq4()) - 1 as n
    from table(generator(rowcount => 730))

),

dates as (

    select dateadd(day, n, '2026-01-01'::date) as date_day
    from numbers

)

select
    date_day,
    year(date_day) as year,
    month(date_day) as month,
    monthname(date_day) as month_name,
    dayname(date_day) as day_name,
    dayofweekiso(date_day) as day_of_week,
    case
        when dayofweekiso(date_day) in (6, 7) then true
        else false
    end as is_weekend
from dates