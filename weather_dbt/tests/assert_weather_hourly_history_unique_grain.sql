select
    file_name,
    loaded_at,
    observed_at,
    count(*) as row_count
from {{ ref('weather_hourly_history') }}
group by file_name, loaded_at, observed_at
having count(*) > 1