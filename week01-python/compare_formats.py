import os
import pandas as pd

# 1. Basahin ang dalawang files
df_csv = pd.read_csv("data/clean_weather.csv")
df_parquet = pd.read_parquet("data/clean_weather.parquet")  # TODO: basahin ang Parquet file

# 2. I-compare ang data types
print("=== CSV DTYPES ===")
print(df_csv.dtypes)
print("\n=== PARQUET DTYPES ===")
print(df_parquet.dtypes)  # TODO

# 3. I-compare ang file sizes
csv_size = os.path.getsize("data/clean_weather.csv")
parquet_size = os.path.getsize("data/clean_weather.parquet")  # TODO
print(f"\nCSV size:     {csv_size:,} bytes")
print(f"Parquet size: {parquet_size:,} bytes")