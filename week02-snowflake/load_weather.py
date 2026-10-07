import os
from dotenv import load_dotenv
import snowflake.connector

load_dotenv()

FILES = [
    "data/raw_weather_mabalacat.json",
    "data/raw_weather_manila.json",
]

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse="WEATHER_WH",
    database="WEATHER_DB",
    schema="RAW",
)
cur = conn.cursor()

# 1. I-upload ang bawat file sa stage
for path in FILES:
    full_path = os.path.abspath(path)
    cur.execute(f"PUT file://{full_path} @WEATHER_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE")
    print("Uploaded:", path)

# 2. I-load mula stage papunta sa table
cur.execute("""
    COPY INTO WEATHER_RAW (raw_data, file_name)
    FROM (
    SELECT $1, METADATA$FILENAME
    FROM @WEATHER_STAGE
);
""")
for row in cur.fetchall():
    print(row)

conn.close()