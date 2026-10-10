with source as (

    select * from {{ source('weather', 'weather_raw') }}

),

flattened as (

    select
        r.file_name,
        r.loaded_at,
        r.raw_data:latitude::FLOAT AS latitude,
        r.raw_data:longitude::FLOAT AS longitude,
        f.value::TIMESTAMP_NTZ AS observed_at,
        r.raw_data:hourly:temperature_2m[f.index]::FLOAT AS temperature_c,
        r.raw_data:hourly:relative_humidity_2m[f.index]::INT AS humidity_pct,
        r.raw_data:hourly:precipitation[f.index]::FLOAT AS precipitation_mm
    from source r,
    lateral flatten(input => r.raw_data:hourly:time) f

)

select * from flattened