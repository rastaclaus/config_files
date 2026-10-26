#!/usr/bin/env python3
"""Weather block for waybar's custom/weather module.

Ported from sway/swaybar-status.py: pulls the current temperature and symbol
from the met.no locationforecast API and prints a single-line JSON object that
waybar understands (return-type "json").

Pass --plain to print just the text (no JSON), which is what ironbar's script
module expects: `weather.py --plain` -> "☀️ 12°C".

Location can be overridden with WEATHER_LAT / WEATHER_LON, and the met.no
User-Agent with WEATHER_USER_AGENT.
"""

# ruff: noqa: T201, D103, CPY001

import json
import os
import sys

import requests  # type: ignore[import-untyped]

LAT = float(os.environ.get("WEATHER_LAT", "55.817521"))
LON = float(os.environ.get("WEATHER_LON", "37.695987"))

PLAIN = "--plain" in sys.argv[1:]

API_URL = "https://api.met.no/weatherapi/locationforecast/2.0/compact"
USER_AGENT = os.environ.get("WEATHER_USER_AGENT", "waybar-weather/1.0")

SYMBOLS = {
    "clearsky": "☀️",
    "fair": "🌤️",
    "partlycloudy": "⛅",
    "cloudy": "☁️",
    "fog": "🌫️",
    "lightrain": "🌦️",
    "rain": "🌧️",
    "heavyrain": "🌧️",
    "lightrainshowers": "🌦️",
    "rainshowers": "🌧️",
    "heavyrainshowers": "🌧️",
    "lightsleet": "🌨️",
    "sleet": "🌨️",
    "heavysleet": "🌨️",
    "lightsnow": "🌨️",
    "snow": "🌨️",
    "heavysnow": "🌨️",
    "lightsleetshowers": "🌨️",
    "sleetshowers": "🌨️",
    "heavysleetshowers": "🌨️",
    "lightsnowshowers": "🌨️",
    "snowshowers": "🌨️",
    "heavysnowshowers": "🌨️",
}


def symbol_emoji(code: str) -> str:
    base = code
    for suffix in ("_day", "_night", "_polartwilight"):
        if base.endswith(suffix):
            base = base[: -len(suffix)]
            break
    if "thunder" in base:
        return "⛈️"
    return SYMBOLS.get(base, "❓")


def emit(text: str, tooltip: str) -> None:
    if PLAIN:
        print(text, flush=True)
    else:
        print(json.dumps({"text": text, "tooltip": tooltip}), flush=True)


def main() -> None:
    try:
        response = requests.get(
            API_URL,
            params={"lat": LAT, "lon": LON},
            headers={"User-Agent": USER_AGENT},
            timeout=5,
        )
        response.raise_for_status()
        current = response.json()["properties"]["timeseries"][0]["data"]
        temperature = current["instant"]["details"]["air_temperature"]
        summary = (current.get("next_1_hours") or current.get("next_6_hours") or current.get("next_12_hours"))[
            "summary"
        ]["symbol_code"]
    except Exception as err:  # noqa: BLE001
        emit("N/A", str(err))
        return

    emit(f"{symbol_emoji(summary)} {temperature}°C", f"{summary} {temperature}°C")


if __name__ == "__main__":
    main()
