import json
import pandas as pd

# 1. Load raw data
with open("data/raw_weather.json") as f:
    raw = json.load(f)

df = pd.DataFrame(raw["hourly"])
print("=== RAW ===")
print(df.head())
print(df.dtypes)

# 2. Clean and transform
df = df.rename(columns={
    "time": "timestamp",
    "temperature_2m": "temperature_c",
    "relative_humidity_2m": "humidity_pct",
    "precipitation": "precipitation_mm",
})
df["timestamp"] = pd.to_datetime(df["timestamp"])
df["date"] = df["timestamp"].dt.date
df["hour"] = df["timestamp"].dt.hour
df["is_raining"] = df["precipitation_mm"] > 0
df["is_hot"] = df["temperature_c"] > 30

# 3. Data quality checks
assert df["timestamp"].is_unique, "Duplicate timestamps found!"
print("\n=== NULLS PER COLUMN ===")
print(df.isna().sum())

# 4. Daily summary
daily = df.groupby("date").agg(
    avg_temp_c=("temperature_c", "mean"),
    max_temp_c=("temperature_c", "max"),
    min_temp_c=("temperature_c", "min"),
    total_rain_mm=("precipitation_mm", "sum"),
    rain_hours=("is_raining", "sum"),
    hot_hours=("is_hot", "sum"),
).round(1)
print("\n=== DAILY SUMMARY ===")
print(daily)

# 5. Save clean data
df.to_csv("data/clean_weather.csv", index=False)
print("\nSaved to data/clean_weather.csv")