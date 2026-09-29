import json
import requests

URL = "https://api.open-meteo.com/v1/forecast"
params = {
    "latitude": 14.60,
    "longitude": 120.98,
    "hourly": "temperature_2m,relative_humidity_2m,precipitation",
    "timezone": "Asia/Manila",
}

response = requests.get(URL, params=params, timeout=30)
response.raise_for_status()
data = response.json()

print("Status:", response.status_code)
print("Top-level keys:", list(data.keys()))
print("Hourly fields:", list(data["hourly"].keys()))
print("Number of rows:", len(data["hourly"]["time"]))

with open("data/raw_weather.json", "w") as f:
    json.dump(data, f, indent=2)

print("Saved to data/raw_weather.json")