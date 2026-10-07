import os
from dotenv import load_dotenv
import snowflake.connector

load_dotenv()

conn = snowflake.connector.connect(
    account=os.getenv("SNOWFLAKE_ACCOUNT"),
    user=os.getenv("SNOWFLAKE_USER"),
    password=os.getenv("SNOWFLAKE_PASSWORD"),
    warehouse="WEATHER_WH",
    database="WEATHER_DB",
    schema="RAW",
)

cur = conn.cursor()
cur.execute("SELECT CURRENT_USER(), CURRENT_WAREHOUSE(), CURRENT_DATABASE(), ")
print(cur.fetchone())

conn.close()