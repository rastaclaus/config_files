#!/usr/bin/env python3
"""Script for swaybar info output."""

# ruff: noqa: T201, D103, D101, FA102

import datetime
import json
import time
import zoneinfo
from dataclasses import dataclass

import psutil  # type: ignore[import-untyped]
import requests  # type: ignore[import-untyped]

LAT, LON = 55.816078, 37.703576

WEATHER_API_URL = "https://api.open-meteo.com/v1/forecast"
WEATHER_UPDATE_INTERVAL = 600  # 10 minutes in seconds
GENERAL_UPDATE_INTERVAL = 1  # 1 second

WEATHER_CODES = {
    0: "☀️",  # Clear sky
    1: "🌤️",  # Mainly clear
    2: "⛅",  # Partly cloudy
    3: "☁️",  # Overcast
    45: "🌫️",  # Foggy
    48: "🌫️",  # Depositing rime fog
    51: "🌧️",  # Light drizzle
    53: "🌧️",  # Moderate drizzle
    55: "🌧️",  # Dense drizzle
    61: "🌧️",  # Slight rain
    63: "🌧️",  # Moderate rain
    65: "🌧️",  # Heavy rain
    71: "🌨️",  # Slight snow
    73: "🌨️",  # Moderate snow
    75: "🌨️",  # Heavy snow
    77: "🌨️",  # Snow grains
    80: "🌧️",  # Slight rain showers
    81: "🌧️",  # Moderate rain showers
    82: "🌧️",  # Violent rain showers
    85: "🌨️",  # Slight snow showers
    86: "🌨️",  # Heavy snow showers
    95: "⛈️",  # Thunderstorm
    96: "⛈️",  # Thunderstorm with slight hail
    99: "⛈️",  # Thunderstorm with heavy hail
}


@dataclass
class WeatherData:
    temperature: float | None = None
    weather_code: int | None = None
    last_update: float = 0


def _get_current_time() -> str:
    now = datetime.datetime.now(tz=zoneinfo.ZoneInfo("Europe/Moscow"))
    return now.strftime("%A %Y-%m-%d %H:%M:%S")


def _get_weather(weather_data: WeatherData) -> str:
    current_time = time.time()

    if (
        current_time - weather_data.last_update >= WEATHER_UPDATE_INTERVAL
        or (weather_data.temperature is None
        and weather_data.weather_code is None)
    ):
        try:
            response = requests.get(
                WEATHER_API_URL,
                params={
                    "latitude": LAT,
                    "longitude": LON,
                    "current_weather": True,
                    "temperature_unit": "celsius",
                },
                timeout=5,
            )
            response.raise_for_status()
            data = response.json()
            current = data.get("current_weather", {})
            weather_data.temperature = current.get("temperature")
            weather_data.weather_code = current.get("weathercode")
            weather_data.last_update = current_time
        except Exception:  # noqa: BLE001
            return "N/A"

    if weather_data.temperature is None or weather_data.weather_code is None:
        return "N/A"

    weather_icon = WEATHER_CODES.get(weather_data.weather_code, "❓")
    return f"{weather_icon} {weather_data.temperature}°C"


def _get_cpu_usage() -> float:
    return psutil.cpu_percent(interval=0.1)


def _get_mem_usage() -> float:
    return psutil.virtual_memory().percent


def main() -> None:
    print(json.dumps({"version": 1}), flush=True)
    print("[", flush=True)
    first = True
    weather_data = WeatherData()

    while True:
        time_str = _get_current_time()
        weather_str = _get_weather(weather_data)
        cpu = _get_cpu_usage()
        mem = _get_mem_usage()

        status_blocks = [
            {
                "name": "time",
                "full_text": f"Time: {time_str}",
            },
            {
                "name": "weather",
                "full_text": f"Weather: {weather_str}",
            },
            {
                "name": "cpu",
                "full_text": f"CPU: {cpu:.1f}%",
            },
            {
                "name": "memory",
                "full_text": f"Mem: {mem:.1f}%",
            },
        ]

        if not first:
            print(",")
        else:
            first = False

        print(json.dumps(status_blocks), flush=True)
        time.sleep(GENERAL_UPDATE_INTERVAL)


if __name__ == "__main__":
    main()
