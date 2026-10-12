with hourly AS(

    select * 
    from {{ ref('stg_weather__hourly') }}
)

select *
from hourly
qualify row_number() over (
   partition by latitude, longitude, observed_at
   order by loaded_at desc
) = 1