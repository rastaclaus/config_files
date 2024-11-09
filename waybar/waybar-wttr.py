#!/usr/bin/env python
import json
from typing import Any
from typing import TypedDict
import requests

"""
WMO Weather interpretation codes (WW)
Code	Description
0	Clear sky
1, 2, 3	Mainly clear, partly cloudy, and overcast
45, 48	Fog and depositing rime fog
51, 53, 55	Drizzle: Light, moderate, and dense intensity
56, 57	Freezing Drizzle: Light and dense intensity
61, 63, 65	Rain: Slight, moderate and heavy intensity
66, 67	Freezing Rain: Light and heavy intensity
71, 73, 75	Snow fall: Slight, moderate, and heavy intensity
77	Snow grains
80, 81, 82	Rain showers: Slight, moderate, and violent
85, 86	Snow showers slight and heavy
95 *	Thunderstorm: Slight or moderate
96, 99 *	Thunderstorm with slight and heavy hail
"""


WEATHER_CODES = {
    0: ["☀️ "],  # Clear sky
    1: ["🌤️"],  # Mainly clear
    2: ["⛅"],  # Partly cloudy
    3: ["☁️ "],  # Overcast
    45: ["🌫️"],  # Fog
    48: ["🌫️"],  # Depositing rime fog
    51: ["🌧️"],  # Light drizzle
    53: ["🌧️"],  # Moderate drizzle
    55: ["🌧️"],  # Dense drizzle
    56: ["🌨️"],  # Light freezing drizzle
    57: ["🌨️"],  # Dense freezing drizzle
    61: ["🌧️"],  # Slight rain
    63: ["🌧️"],  # Moderate rain
    65: ["🌧️"],  # Heavy rain
    66: ["🌨️"],  # Light freezing rain
    67: ["🌨️"],  # Heavy freezing rain
    71: ["🌨️"],  # Slight snow fall
    73: ["🌨️"],  # Moderate snow fall
    75: ["🌨️"],  # Heavy snow fall
    77: ["🌨️"],  # Snow grains
    80: ["🌧️"],  # Slight rain showers
    81: ["🌧️"],  # Moderate rain showers
    82: ["🌧️"],  # Violent rain showers
    85: ["🌨️"],  # Slight snow showers
    86: ["🌨️"],  # Heavy snow showers
    95: ["⛈️ "],  # Thunderstorm
    96: ["⛈️ "],  # Thunderstorm with slight hail
    99: ["⛈️ "],  # Thunderstorm with heavy hail
}

OPEN_METEO_URL = "http://api.open-meteo.com/v1/forecast"

REQUEST_PARAMS = {
    "latitude": 55.816709,
    "longitude": 37.693257,
    "current": ["temperature_2m", "wind_speed_10m", "weather_code"],
}


"""
```json
"custom/weather": {
    "format": "{}",
    "tooltip": true,
    "interval": 3600,
    "exec": "waybar-wttr.py",
    "return-type": "json"
}
```
"""

class OpenMeteoCurrentData(TypedDict):
    temperature_2m: float
    wind_speed_10m: float
    weather_code: int
    time: str


class OpenMeteoResponse(TypedDict):
    latitude: float
    longitude: float
    generationtime_ms: float
    utc_offset_seconds: int
    timezone: str
    timezone_abbreviation: str
    elevation: float
    current_units: dict[str, str]
    current: OpenMeteoCurrentData

def get_weather():
    try:
        response = requests.get(OPEN_METEO_URL, params=REQUEST_PARAMS)
        response.raise_for_status()
        data: OpenMeteoResponse = response.json()

        current: OpenMeteoCurrentData = data["current"]
        temp: float = round(current["temperature_2m"])
        wind: float = round(current["wind_speed_10m"])
        weather_code = current["weather_code"]

        weather_icon = WEATHER_CODES[weather_code][0]

        output = {
            "text": f"{weather_icon} {temp}°C {wind}m/s",
            "tooltip": f"Temperature: {temp}°C\nWind: {wind}m/s",
            "class": "custom-weather",
        }
        print(json.dumps(output))


    except Exception as e:
        output = {
            "text": "Weather Error",
            "tooltip": str(e),
            "class": "custom-weather-error",
        }
        print(json.dumps(output))


if __name__ == "__main__":
    get_weather()
