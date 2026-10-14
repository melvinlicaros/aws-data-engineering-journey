with locations as (

    select * from {{ ref('locations') }}

),

coords as (

    select
        location_name,
        avg(latitude) as latitude,
        avg(longitude) as longitude
    from {{ ref('stg_weather__hourly') }}
    group by location_name

)

select
    l.location_id,
    l.location_name,
    l.province,
    l.region,
    c.latitude,
    c.longitude
from locations l
left join coords c
    on l.location_name = c.location_name