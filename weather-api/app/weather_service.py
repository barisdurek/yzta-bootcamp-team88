import os
from pathlib import Path
from typing import Any

import requests
from dotenv import load_dotenv


# weather-api klasöründeki .env dosyasını yükle
BASE_DIR = Path(__file__).resolve().parent.parent
ENV_PATH = BASE_DIR / ".env"

load_dotenv(dotenv_path=ENV_PATH)

OPENWEATHER_URL = "https://api.openweathermap.org/data/2.5/weather"
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")


def get_weather_by_coordinates(
    latitude: float,
    longitude: float,
) -> dict[str, Any]:
    """
    Enlem ve boylam bilgilerine göre OpenWeather API'ye istek atar.

    E88-41 kapsamında OpenWeather'dan gelen ham JSON yanıtını
    değiştirmeden döndürür.
    """

    if not OPENWEATHER_API_KEY:
        raise RuntimeError(
            "OPENWEATHER_API_KEY ortam değişkeni bulunamadı. "
            ".env dosyasını kontrol edin."
        )

    params = {
        "lat": latitude,
        "lon": longitude,
        "appid": OPENWEATHER_API_KEY,
        "units": "metric",
        "lang": "tr",
    }

    try:
        response = requests.get(
            OPENWEATHER_URL,
            params=params,
            timeout=10,
        )
        response.raise_for_status()

    except requests.Timeout as exc:
        raise RuntimeError(
            "OpenWeather API isteği zaman aşımına uğradı."
        ) from exc

    except requests.HTTPError as exc:
        status_code = (
            exc.response.status_code
            if exc.response is not None
            else None
        )

        if status_code == 401:
            raise RuntimeError(
                "OpenWeather API anahtarı geçersiz, aktif değil veya yanlış yazılmış."
            ) from exc

        if status_code == 404:
            raise RuntimeError(
                "Girilen koordinatlar için hava durumu verisi bulunamadı."
            ) from exc

        raise RuntimeError(
            f"OpenWeather API isteği başarısız oldu. Durum kodu: {status_code}"
        ) from exc

    except requests.RequestException as exc:
        raise RuntimeError(
            "OpenWeather servisine bağlanılamadı."
        ) from exc

    try:
        return response.json()
    except ValueError as exc:
        raise RuntimeError(
            "OpenWeather geçerli bir JSON yanıtı döndürmedi."
        ) from exc


def filter_weather_data(raw_data: dict[str, Any]) -> dict[str, Any]:
    """
    OpenWeather API'den gelen ham JSON verisini filtreleyerek
    veritabanına kaydedilebilecek sade bir sözlüğe dönüştürür.
    """

    main_data = raw_data.get("main")
    wind_data = raw_data.get("wind")
    coord_data = raw_data.get("coord")

    if not main_data:
        raise ValueError(
            "API yanıtında sıcaklık ve nem bilgileri bulunamadı."
        )

    if not wind_data:
        raise ValueError(
            "API yanıtında rüzgar bilgisi bulunamadı."
        )

    wind_speed_ms = wind_data.get("speed")

    return {
        "latitude": coord_data.get("lat") if coord_data else None,
        "longitude": coord_data.get("lon") if coord_data else None,
        "temperature_c": main_data.get("temp"),
        "humidity_pct": main_data.get("humidity"),
        "wind_speed_ms": wind_speed_ms,
        "wind_speed_kmh": (
            round(wind_speed_ms * 3.6, 2)
            if wind_speed_ms is not None
            else None
        ),
        "city": raw_data.get("name"),
        "weather_description": (
            raw_data.get("weather", [{}])[0].get("description")
        ),
        "timestamp": raw_data.get("dt"),
    }