import os
import snowflake.connector

conn = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    private_key_file=os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"],
    warehouse="WEATHER_WH",
    role="PIPELINE_ROLE",
)

cur = conn.cursor()
cur.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), COUNT(*) FROM WEATHER_DB.RAW.WEATHER_RAW")
print(cur.fetchone())
conn.close()