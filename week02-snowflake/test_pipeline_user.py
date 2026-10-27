import snowflake.connector

conn = snowflake.connector.connect(
    account="WNRKWDX-PJ81261",
    user="PIPELINE_USER",
    private_key_file="/Users/melvinlicaros/.snowflake_keys/pipeline_rsa_key.p8",
    warehouse="WEATHER_WH",
    role="PIPELINE_ROLE",
)

cur = conn.cursor()
cur.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), COUNT(*) FROM WEATHER_DB.RAW.WEATHER_RAW")
print(cur.fetchone())
conn.close()