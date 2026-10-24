{{ config(materialized='incremental') }}

with history as (

    select * from {{ ref('stg_weather__hourly') }}

)

select * from history

{% if is_incremental() %}
where loaded_at > (select max(loaded_at) from {{ this }})
{% endif %}