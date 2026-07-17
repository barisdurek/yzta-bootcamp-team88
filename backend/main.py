import os
from fastapi import FastAPI, File, UploadFile, Query, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime

from model_loader import PlantModelLoader
from weather_service import get_weather_forecast_by_coordinates, get_weather_by_coordinates, filter_weather_data
from irrigation import calculate_optimal_irrigation
from leaching import calculate_npk_leaching
from ai_agent import generate_proactive_recommendation

app = FastAPI(
    title="Tarla Gözcüsü Unified AI & Analytics API",
    description="Tarla Gözcüsü projesinin tüm yapay zeka, makine öğrenmesi ve harici API orkestrasyonunu üstlenen merkezi backend servisi.",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Reference files in the model-cnn directory
MODEL_PATH = os.path.join(BASE_DIR, "..", "model-cnn", "outputs_effnetb2", "efficientnetb2_final_float32.tflite")
LABELS_PATH = os.path.join(BASE_DIR, "..", "model-cnn", "outputs_effnetb2", "class_indices.json")

# Initialize CNN Model
try:
    model_loader = PlantModelLoader(model_path=MODEL_PATH, labels_path=LABELS_PATH)
    print("TFLite Model successfully loaded.")
except Exception as e:
    print(f"WARNING: Model could not be loaded: {e}")
    model_loader = None

# InMemory Database for Regional Risk logs (collective protect module)
in_memory_risk_logs = [
    {
        "id": 1,
        "grid_code": "Grid_Konya_Karatay_3",
        "region_name": "Karatay Bölgesi",
        "city": "Konya",
        "district": "Karatay",
        "crop_name": "Mısır",
        "risk_type": "Zararlı Alarmi",
        "detected_disease": "Kırmızı Örümcek",
        "risk_level": "Yüksek",
        "source": "Saha Raporu",
        "detected_at": "2026-07-16T10:00:00"
    },
    {
        "id": 2,
        "grid_code": "Grid_Manisa_Alasehir_2",
        "region_name": "Alaşehir Bağlık",
        "city": "Manisa",
        "district": "Alaşehir",
        "crop_name": "Üzüm",
        "risk_type": "Mantar Riski",
        "detected_disease": "Külleme",
        "risk_level": "Orta",
        "source": "Nem Alarmı",
        "detected_at": "2026-07-17T09:30:00"
    }
]

# Request Models
class IrrigationRequest(BaseModel):
    weather_data: Dict[str, Any]
    crop_data: Dict[str, Any]

class LeachingRequest(BaseModel):
    precipitation_mm: float
    net_irrigation_mm: float
    soil_type: str

class RiskLogSchema(BaseModel):
    grid_code: str
    region_name: str
    city: str
    district: str
    crop_name: str
    risk_type: str
    detected_disease: str
    risk_level: str
    source: str

@app.get("/")
def root():
    return {
        "status": "online",
        "message": "Tarla Gözcüsü API Gateway & AI Engine çalışıyor.",
        "model_loaded": model_loader is not None
    }

@app.post("/predict", summary="Resimden yaprak hastalığı teşhisi yapar")
async def predict(
    file: UploadFile = File(...),
    threshold: float = Query(0.25, ge=0.0, le=1.0)
):
    if model_loader is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model is not loaded on the server."
        )
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file must be an image."
        )
    try:
        image_bytes = await file.read()
        return model_loader.predict(image_bytes, confidence_threshold=threshold)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error running inference: {e}"
        )

@app.get("/weather/current", summary="Koordinata göre güncel hava durumunu döner")
def get_current_weather(latitude: float, longitude: float):
    try:
        raw_data = get_weather_by_coordinates(latitude, longitude)
        return filter_weather_data(raw_data)
    except Exception as e:
        # Fallback to simulated current weather
        import random
        return {
            "latitude": latitude,
            "longitude": longitude,
            "temperature_c": round(25.0 + random.uniform(-4, 4), 1),
            "humidity_pct": random.randint(45, 75),
            "wind_speed_ms": 3.2,
            "wind_speed_kmh": 11.5,
            "city": "Konya Karatay (Simüle)",
            "weather_description": random.choice(["Açık", "Parçalı Bulutlu", "Hafif Rüzgarlı"]),
            "timestamp": int(datetime.now().timestamp()),
        }

@app.get("/weather/forecast", summary="Koordinata göre 3 günlük tahmini hava durumunu döner")
def get_weather_forecast(latitude: float, longitude: float):
    try:
        return get_weather_forecast_by_coordinates(latitude, longitude)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/irrigation", summary="Penman-Monteith günlük sulama ihtiyacını hesaplar")
def do_irrigation_calc(req: IrrigationRequest):
    val = calculate_optimal_irrigation(req.weather_data, req.crop_data)
    return {"optimal_irrigation_mm": val}

@app.post("/leaching", summary="NPK gübre yıkanma kayıp yüzdesini hesaplar")
def do_leaching_calc(req: LeachingRequest):
    val = calculate_npk_leaching(req.precipitation_mm, req.net_irrigation_mm, req.soil_type)
    return val

@app.post("/ai/recommend", summary="Merkezi AI Agent önerisi üretir")
def get_ai_recommendation(tarla_data: Dict[str, Any]):
    try:
        advice = generate_proactive_recommendation(tarla_data)
        return {"recommendation": advice}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate AI advice: {e}")

# Regional Risk Sharing Endpoints (Modül 4)
@app.get("/risk-logs", summary="Bölgesel hastalık risk kayıtlarını listeler")
def list_risk_logs():
    return in_memory_risk_logs

@app.post("/risk-logs", summary="Bölgesel risk haritası için veri paylaşır")
def create_risk_log(log: RiskLogSchema):
    new_id = len(in_memory_risk_logs) + 1
    log_dict = log.model_dump()
    log_dict["id"] = new_id
    log_dict["detected_at"] = datetime.now().isoformat()
    in_memory_risk_logs.append(log_dict)
    return {"message": "Success", "risk_log": log_dict}
