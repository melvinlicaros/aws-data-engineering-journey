import json
import requests

URL = "https://api.open-meteo.com/v1/forecast"


def fetch_weather(latitude, longitude):
    """Kunin ang hourly weather data para sa isang location."""
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "hourly": "temperature_2m,relative_humidity_2m,precipitation",
        "timezone": "Asia/Manila",
    }
    response = requests.get(URL, params=params, timeout=30)
    response.raise_for_status()
    return response.json()


def save_raw(data, path):
    """I-save ang raw data as JSON file."""
    with open(path, "w") as f: # buksan ang file na nasa "path"
        json.dump(data, f, indent=2) # isulat ang "data" sa file na 'yon
    print("Save_to", path)


if __name__ == "__main__":

    
    data_Mabalacat = fetch_weather(15.22, 120.57)
    print("Location:", data_Mabalacat["latitude"], data_Mabalacat["longitude"])
    print("Number of rows:", len(data_Mabalacat["hourly"]["time"]))
    save_raw(data_Mabalacat, "data/raw_weather_mabalacat.json")

    data_Manila = fetch_weather(14.60, 120.98)
    save_raw(data_Manila, "data/raw_weather_manila.json")
   