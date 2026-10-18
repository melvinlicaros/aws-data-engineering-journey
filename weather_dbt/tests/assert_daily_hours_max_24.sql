select *
from {{ ref('fct_weather_daily') }}
where rain_hours > 24
   or hot_hours > 24