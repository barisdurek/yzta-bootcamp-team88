from fastapi import FastAPI, HTTPException, Query

from app.weather_service import (
    filter_weather_data,
    get_weather_by_coordinates,
)

app = FastAPI(
    title="Weather API",
    description="Tarla Gözcüsü Hava Durumu Servisi",
    version="1.0.0",
)


@app.get("/")
def root():
    return {
        "message": "Weather API çalışıyor."
    }


@app.get(
    "/weather/raw",
    summary="Koordinata göre OpenWeather ham JSON verisi getirir",
    tags=["Weather"],
)
def get_raw_weather(
    latitude: float = Query(
        ...,
        ge=-90,
        le=90,
        description="Enlem bilgisi",
    ),
    longitude: float = Query(
        ...,
        ge=-180,
        le=180,
        description="Boylam bilgisi",
    ),
):
    """
    E88-41

    OpenWeather API'ye koordinat bilgileri ile istek atar ve
    gelen ham JSON yanıtını döndürür.
    """

    try:
        return get_weather_by_coordinates(
            latitude=latitude,
            longitude=longitude,
        )

    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=str(exc),
        ) from exc


@app.get(
    "/weather/current",
    summary="Filtrelenmiş güncel hava durumu verisi getirir",
    tags=["Weather"],
)
def get_current_weather(
    latitude: float = Query(
        ...,
        ge=-90,
        le=90,
        description="Enlem bilgisi",
    ),
    longitude: float = Query(
        ...,
        ge=-180,
        le=180,
        description="Boylam bilgisi",
    ),
):
    """
    E88-42

    OpenWeather API'den alınan ham JSON verisini filtreleyerek
    veritabanına işlenebilir sade bir çıktı döndürür.
    """

    try:
        raw_data = get_weather_by_coordinates(
            latitude=latitude,
            longitude=longitude,
        )

        return filter_weather_data(raw_data)

    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail=str(exc),
        ) from exc

    except RuntimeError as exc:
        raise HTTPException(
            status_code=503,
            detail=str(exc),
        ) from exc