with history AS(

    select * 
    from {{ ref('stg_weather__hourly') }}
)

select *
from history