with hourly as (

    select * from {{ ref('fct_weather_hourly') }}

)

select
    location_id,
    date_day,
    round(avg(temperature_c), 1) as avg_temp_c,
    max(temperature_c) as max_temp_c,
    min(temperature_c) as min_temp_c,
    sum(precipitation_mm) as total_precip_mm,
    count_if(precipitation_mm > 0) as rain_hours,
    count_if(temperature_c >= 32) as hot_hours
from hourly
group by location_id, date_day