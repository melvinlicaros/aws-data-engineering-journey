USE WAREHOUSE WEATHER_WH;
USE DATABASE WEATHER_DB;
USE SCHEMA RAW;

CREATE FILE FORMAT IF NOT EXISTS JSON_FORMAT
TYPE  = JSON;

CREATE STAGE IF NOT EXISTS WEATHER_STAGE
FILE_FORMAT = (FORMAT_NAME = 'JSON_FORMAT');
LIST @WEATHER_STAGE;

CREATE TABLE IF NOT EXISTS WEATHER_RAW
(raw_data variant,
file_name string,
loaded_at timestamp_ntz DEFAULT current_timestamp());

COPY INTO WEATHER_RAW (raw_data, file_name)
FROM (
    SELECT $1, METADATA$FILENAME
    FROM @WEATHER_STAGE
);

SELECT *
FROM WEATHER_RAW;

SELECT
    file_name,
    raw_data:latitude,
    raw_data:timezone
FROM WEATHER_RAW;

SELECT 
file_name,
raw_data:latitude::float AS latitude,
raw_data:timezone::string AS timezone
FROM WEATHER_RAW;