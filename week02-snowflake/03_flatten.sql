USE WAREHOUSE WEATHER_WH;
USE DATABASE WEATHER_DB;
USE SCHEMA RAW;

SELECT r.file_name,
       f.*
FROM WEATHER_RAW r,
LATERAL FLATTEN(input => r.raw_data:hourly:time) f 
LIMIT 10;

SELECT
    r.file_name,
    f.value::TIMESTAMP_NTZ AS observed_at,
    r.raw_data:hourly:temperature_2m[f.index]::FLOAT AS temperature_c,
    r.raw_data:hourly:relative_humidity_2m[f.index]::INT AS humidity_pct,
    r.raw_data:hourly:precipitation[f.index]::FLOAT AS precipitation_mm
FROM WEATHER_RAW r,
LATERAL FLATTEN(input => r.raw_data:hourly:time) f
LIMIT 10;

SELECT raw_data FROM WEATHER_RAW;


SELECT
    r.file_name,
    COUNT(*) AS No_of_records
FROM WEATHER_RAW r,
LATERAL FLATTEN(input => r.raw_data:hourly:time) f 
GROUP BY r.file_name;

CREATE OR REPLACE VIEW WEATHER_DB.ANALYTICS.WEATHER_HOURLY AS
WITH flattened AS (
    SELECT
        r.file_name,
        r.loaded_at,
        r.raw_data:latitude::FLOAT AS latitude,
        r.raw_data:longitude::FLOAT AS longitude,
        f.value::TIMESTAMP_NTZ AS observed_at,
        r.raw_data:hourly:temperature_2m[f.index]::FLOAT AS temperature_c,
        r.raw_data:hourly:relative_humidity_2m[f.index]::INT AS humidity_pct,
        r.raw_data:hourly:precipitation[f.index]::FLOAT AS precipitation_mm
    FROM WEATHER_DB.RAW.WEATHER_RAW r,
    LATERAL FLATTEN(input => r.raw_data:hourly:time) f
)
SELECT *
FROM flattened
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY latitude, longitude, observed_at
    ORDER BY loaded_at DESC
) = 1;


SELECT *
FROM WEATHER_DB.ANALYTICS.WEATHER_HOURLY;

select *
from weather_raw;

SELECT file_name, loaded_at
FROM WEATHER_DB.RAW.WEATHER_RAW;

SELECT COUNT(*) FROM WEATHER_DB.ANALYTICS.WEATHER_HOURLY;

SELECT DISTINCT loaded_at
FROM WEATHER_DB.ANALYTICS.WEATHER_HOURLY;

SELECT COUNT(*)
FROM WEATHER_DB.ANALYTICS.WEATHER_HOURLY;
SELECT DISTINCT loaded_at
FROM WEATHER_DB.ANALYTICS.WEATHER_HOURLY;