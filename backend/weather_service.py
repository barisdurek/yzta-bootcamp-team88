import os
from pathlib import Path
from typing import Any, Dict
import requests
from dotenv import load_dotenv

# Load .env file from the current directory
BASE_DIR = Path(__file__).resolve().parent
ENV_PATH = BASE_DIR / ".env"
load_dotenv(dotenv_path=ENV_PATH)

OPENWEATHER_URL = "https://api.openweathermap.org/data/2.5/weather"
OPENWEATHER_FORECAST_URL = "https://api.openweathermap.org/data/2.5/forecast"
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")

def get_weather_by_coordinates(latitude: float, longitude: float) -> dict[str, Any]:
    """
    Fetches raw weather data from OpenWeatherMap API.
    """
    if not OPENWEATHER_API_KEY:
        raise RuntimeError("OPENWEATHER_API_KEY environment variable not found.")

    params = {
        "lat": latitude,
        "lon": longitude,
        "appid": OPENWEATHER_API_KEY,
        "units": "metric",
        "lang": "tr",
    }

    try:
        response = requests.get(OPENWEATHER_URL, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as exc:
        raise RuntimeError(f"OpenWeather API call failed: {exc}")

def filter_weather_data(raw_data: dict[str, Any]) -> dict[str, Any]:
    """
    Filters raw weather JSON into a simplified dictionary.
    """
    main_data = raw_data.get("main", {})
    wind_data = raw_data.get("wind", {})
    coord_data = raw_data.get("coord", {})
    weather_list = raw_data.get("weather", [{}])

    wind_speed_ms = wind_data.get("speed", 0.0)

    return {
        "latitude": coord_data.get("lat") if coord_data else None,
        "longitude": coord_data.get("lon") if coord_data else None,
        "temperature_c": main_data.get("temp", 20.0),
        "humidity_pct": main_data.get("humidity", 60.0),
        "wind_speed_ms": wind_speed_ms,
        "wind_speed_kmh": round(wind_speed_ms * 3.6, 2),
        "city": raw_data.get("name", "Bilinmeyen Bölge"),
        "weather_description": weather_list[0].get("description", "Açık"),
        "timestamp": raw_data.get("dt"),
    }

def get_mock_forecast(latitude: float, longitude: float) -> list[dict[str, Any]]:
    """
    Generates high-quality mock weather data in case live API is not configured or fails.
    """
    # Dynamic values based on coordinates to make it realistic
    import random
    from datetime import datetime, timedelta
    
    random.seed(int(latitude * 100 + longitude * 100))
    base_temp = 25.0 + random.uniform(-5, 5)
    
    forecast = []
    conditions = ["Açık", "Parçalı Bulutlu", "Bulutlu", "Hafif Yağmurlu", "Şiddetli Yağış"]
    
    for i in range(3):
        date_str = (datetime.now() + timedelta(days=i)).strftime("%Y-%m-%d")
        temp = round(base_temp + random.uniform(-2, 2) - i * 1.5, 1)
        humidity = random.randint(40, 95)
        
        # Determine precipitation and condition
        if i == 1 and random.choice([True, False]): # Let's simulate a rain tomorrow for testing irrigation/leaching
            cond = "Şiddetli Yağış"
            precipitation = round(random.uniform(20.0, 40.0), 1)
            humidity = random.randint(85, 95)
        else:
            cond = random.choice(conditions[:4])
            precipitation = round(random.uniform(0.0, 5.0), 1) if "Yağmurlu" in cond else 0.0
            
        forecast.append({
            "date": date_str,
            "temp_c": temp,
            "humidity_pct": humidity,
            "precipitation_mm": precipitation,
            "condition": cond,
            "wind_speed_ms": round(random.uniform(1.5, 6.0), 1)
        })
    return forecast

def get_weather_forecast_by_coordinates(latitude: float, longitude: float) -> list[dict[str, Any]]:
    """
    Calls OpenWeatherMap 5-day forecast API or returns mock forecast if API fails.
    """
    if not OPENWEATHER_API_KEY or OPENWEATHER_API_KEY == "YOUR_API_KEY":
        return get_mock_forecast(latitude, longitude)
        
    params = {
        "lat": latitude,
        "lon": longitude,
        "appid": OPENWEATHER_API_KEY,
        "units": "metric",
        "lang": "tr",
    }
    
    try:
        response = requests.get(OPENWEATHER_FORECAST_URL, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            # Group by day
            daily_forecasts = {}
            for item in data.get("list", []):
                dt_txt = item.get("dt_txt", "")
                date_part = dt_txt.split(" ")[0]
                if not date_part:
                    continue
                if date_part not in daily_forecasts:
                    daily_forecasts[date_part] = []
                daily_forecasts[date_part].append(item)
                
            forecast_list = []
            # Take the next 3 days
            sorted_dates = sorted(list(daily_forecasts.keys()))
            for d in sorted_dates[:3]:
                day_items = daily_forecasts[d]
                # Average calculations
                temps = [x.get("main", {}).get("temp", 20.0) for x in day_items]
                hums = [x.get("main", {}).get("humidity", 60.0) for x in day_items]
                winds = [x.get("wind", {}).get("speed", 2.0) for x in day_items]
                
                # Check for rain
                rain_sum = 0.0
                for x in day_items:
                    rain_sum += x.get("rain", {}).get("3h", 0.0)
                    
                cond = day_items[len(day_items)//2].get("weather", [{}])[0].get("description", "Açık").capitalize()
                
                forecast_list.append({
                    "date": d,
                    "temp_c": round(sum(temps) / len(temps), 1) if temps else 20.0,
                    "humidity_pct": round(sum(hums) / len(hums)) if hums else 60,
                    "precipitation_mm": round(rain_sum, 2),
                    "condition": cond,
                    "wind_speed_ms": round(sum(winds) / len(winds), 1) if winds else 2.0
                })
            return forecast_list
    except Exception as e:
        print(f"Failed to fetch forecast from OpenWeatherMap API, falling back to mock: {e}")
        
    return get_mock_forecast(latitude, longitude)
