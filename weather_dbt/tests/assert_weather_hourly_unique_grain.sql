select
    latitude,
    longitude,
    observed_at,
    count(*) as row_count
from {{ ref('weather_hourly') }}
group by latitude, longitude, observed_at
having count(*) > 1

