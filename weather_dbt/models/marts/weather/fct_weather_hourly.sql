with weather as (

    select * from {{ ref('weather_hourly') }}

),

locations as (

    select * from {{ ref('dim_location') }}

)

select
    l.location_id,
    cast(w.observed_at as Date) as date_day,
    w.observed_at,
    w.temperature_c,
    w.humidity_pct,
    w.precipitation_mm,
    w.loaded_at
from weather w
left join locations l
    on w.location_name = l.location_name