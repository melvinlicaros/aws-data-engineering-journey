import snowflake.connector

conn = snowflake.connector.connect(
    account="WNRKWDX-PJ81261",
    user="FABRIC_USER",
    private_key_file="/Users/melvinlicaros/.snowflake_keys/fabric_rsa_key.p8",
    warehouse="WEATHER_WH",
    role="ANALYST",
)

cur = conn.cursor()
cur.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), COUNT(*) FROM WEATHER_DB.DBT_MELVIN.FCT_WEATHER_DAILY")
print(cur.fetchone())
conn.close()