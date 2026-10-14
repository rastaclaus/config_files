#!/usr/bin/env python3
"""Script for swaybar info output."""

# ruff: noqa: T201, D103, D101

import datetime
import json
import os
import sys
import time
import zoneinfo
from dataclasses import dataclass

import psutil  # type: ignore[import-untyped]
import requests  # type: ignore[import-untyped]

LAT = float(os.environ.get("WEATHER_LAT", "55.816078"))
LON = float(os.environ.get("WEATHER_LON", "37.703576"))

WEATHER_API_URL = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
USER_AGENT = os.environ.get(
    "WEATHER_USER_AGENT",
    "swaybar-status/1.0 github.com/rastaclaus tema.rastaclaus@gmail.com",
)
WEATHER_UPDATE_INTERVAL = 600  # 10 minutes in seconds
GENERAL_UPDATE_INTERVAL = 1  # 1 second

WEATHER_SYMBOLS = {
    "clearsky": "☀️",  # Clear sky
    "fair": "🌤️",  # Mainly clear
    "partlycloudy": "⛅",  # Partly cloudy
    "cloudy": "☁️",  # Overcast
    "fog": "🌫️",  # Foggy
    "lightrain": "🌦️",  # Slight rain
    "rain": "🌧️",  # Rain
    "heavyrain": "🌧️",  # Heavy rain
    "lightrainshowers": "🌦️",  # Slight rain showers
    "rainshowers": "🌧️",  # Rain showers
    "heavyrainshowers": "🌧️",  # Heavy rain showers
    "lightsleet": "🌨️",  # Slight sleet
    "sleet": "🌨️",  # Sleet
    "heavysleet": "🌨️",  # Heavy sleet
    "lightsnow": "🌨️",  # Slight snow
    "snow": "🌨️",  # Snow
    "heavysnow": "🌨️",  # Heavy snow
    "lightsleetshowers": "🌨️",  # Slight sleet showers
    "sleetshowers": "🌨️",  # Sleet showers
    "heavysleetshowers": "🌨️",  # Heavy sleet showers
    "lightsnowshowers": "🌨️",  # Slight snow showers
    "snowshowers": "🌨️",  # Snow showers
    "heavysnowshowers": "🌨️",  # Heavy snow showers
}


def _symbol_emoji(code: str) -> str:
    base = code
    for suffix in ("_day", "_night", "_polartwilight"):
        if base.endswith(suffix):
            base = base[: -len(suffix)]
            break
    if "thunder" in base:
        return "⛈️"
    return WEATHER_SYMBOLS.get(base, "❓")


@dataclass
class WeatherData:
    temperature: float | None = None
    weather_code: str | None = None
    last_attempt: float = 0


def _get_current_time() -> str:
    now = datetime.datetime.now(tz=zoneinfo.ZoneInfo("Europe/Moscow"))
    return now.strftime("%A %Y-%m-%d %H:%M:%S")


def _get_weather(weather_data: WeatherData) -> str:
    current_time = time.time()

    if current_time - weather_data.last_attempt >= WEATHER_UPDATE_INTERVAL:
        weather_data.last_attempt = current_time
        try:
            response = requests.get(
                WEATHER_API_URL,
                params={"lat": LAT, "lon": LON},
                headers={"User-Agent": USER_AGENT},
                timeout=5,
            )
            response.raise_for_status()
            data = response.json()
            current = data["properties"]["timeseries"][0]["data"]
            weather_data.temperature = current["instant"]["details"]["air_temperature"]
            summary = (
                current.get("next_1_hours")
                or current.get("next_6_hours")
                or current.get("next_12_hours")
            )["summary"]["symbol_code"]
            weather_data.weather_code = summary
        except Exception as err:  # noqa: BLE001
            print(err, file=sys.stderr)
            return "N/A"

    if weather_data.temperature is None or weather_data.weather_code is None:
        return "N/A"

    weather_icon = _symbol_emoji(weather_data.weather_code)
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
