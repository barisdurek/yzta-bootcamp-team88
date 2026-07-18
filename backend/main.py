import os
import json
import uuid
from fastapi import FastAPI, File, UploadFile, Query, HTTPException, status, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from datetime import datetime

from model_loader import PlantModelLoader
from weather_service import get_weather_forecast_by_coordinates, get_weather_by_coordinates, filter_weather_data
from irrigation import calculate_optimal_irrigation
from leaching import calculate_npk_leaching
from ai_agent import generate_proactive_recommendation
from sqlalchemy.orm import Session

from database import get_db, test_database_connection
from crud import (
    get_all_risk_logs,
    create_risk_log as create_risk_log_db,
    create_user as create_user_db,
    get_user_by_email,
    create_field as create_field_db,
    get_all_fields,
    create_ai_recommendation,
    get_field_by_id,
    
)

try:
    test_database_connection()
    print("PostgreSQL bağlantısı başarılı.")
except Exception as e:
    print(f"WARNING: PostgreSQL bağlantısı kurulamadı: {e}")

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
    province: str
    district: str
    crop_name: str
    risk_type: str
    detected_disease: str
    risk_level: str
    source: str

class UserCreateSchema(BaseModel):
    full_name: str
    email: str
    password_hash: str
    phone_number: Optional[str] = None
    role: str = "user"
    city: Optional[str] = None
    district: Optional[str] = None 

class FieldCreateSchema(BaseModel):
    user_id: str
    region_id: Optional[str] = None
    field_name: str
    province: Optional[str] = None
    district: Optional[str] = None
    latitude: float
    longitude: float
    area_m2: Optional[float] = None
    soil_type: Optional[str] = None
    irrigation_type: Optional[str] = None  

class AIRecommendationRequest(BaseModel):
    field_id: str
    recommendation_type: str = "general"
    risk_level: Optional[str] = None
    source_data: Dict[str, Any] 

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

@app.post(
    "/ai/recommend",
    summary="AI önerisi üretir ve veritabanına kaydeder"
)
def get_ai_recommendation(
    request: AIRecommendationRequest,
    db: Session = Depends(get_db),
):
    try:
        try:
            field_uuid = uuid.UUID(request.field_id)
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="field_id geçerli bir UUID olmalıdır.",
            ) from e

        field = get_field_by_id(db, field_uuid)

        if field is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Belirtilen field_id ile eşleşen tarla bulunamadı.",
            )

        combined_source_data = {
            **request.source_data,
            "field": {
                "id": str(field.id),
                "user_id": str(field.user_id),
                "region_id": (
                    str(field.region_id)
                    if field.region_id is not None
                    else None
                ),
                "field_name": field.field_name,
                "province": field.province,
                "district": field.district,
                "latitude": float(field.latitude),
                "longitude": float(field.longitude),
                "area_m2": (
                    float(field.area_m2)
                    if field.area_m2 is not None
                    else None
                ),
                "soil_type": field.soil_type,
                "irrigation_type": field.irrigation_type,
            },
        }

        advice = generate_proactive_recommendation(
            combined_source_data
        )

        if isinstance(advice, str):
            recommendation_text = advice
        else:
            recommendation_text = json.dumps(
                advice,
                ensure_ascii=False,
            )

        created_recommendation = create_ai_recommendation(
            db,
            {
                "field_id": field_uuid,
                "recommendation_type": request.recommendation_type,
                "recommendation_text": recommendation_text,
                "risk_level": request.risk_level,
                "source_data": combined_source_data,
            },
        )

        return {
            "message": "AI önerisi üretildi ve veritabanına kaydedildi.",
            "recommendation": {
                "id": created_recommendation.id,
                "field_id": created_recommendation.field_id,
                "recommendation_type": (
                    created_recommendation.recommendation_type
                ),
                "recommendation_text": (
                    created_recommendation.recommendation_text
                ),
                "risk_level": created_recommendation.risk_level,
                "source_data": created_recommendation.source_data,
                "created_at": created_recommendation.created_at,
            },
        }

    except HTTPException:
        raise

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        ) from e

    except Exception as e:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI önerisi oluşturulamadı: {e}",
        ) from e

# Regional Risk Sharing Endpoints (Modül 4)
@app.get("/risk-logs", summary="Bölgesel hastalık risk kayıtlarını listeler")
def list_risk_logs(db: Session = Depends(get_db)):
    try:
        return get_all_risk_logs(db)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Risk kayıtları alınamadı: {e}"
        ) from e


@app.post("/risk-logs", summary="Bölgesel risk haritası için veri paylaşır")
def create_risk_log(
    log: RiskLogSchema,
    db: Session = Depends(get_db)
):
    try:
        created_log = create_risk_log_db(
            db,
            log.model_dump()
        )

        return {
            "message": "Success",
            "risk_log": created_log
        }

    except Exception as e:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Risk kaydı oluşturulamadı: {e}"
        ) from e
    

@app.post("/users", summary="Yeni kullanıcı oluşturur")
def create_user(
    user: UserCreateSchema,
    db: Session = Depends(get_db),
):
    try:
        existing_user = get_user_by_email(db, user.email)

        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Bu e-posta adresiyle kayıtlı bir kullanıcı zaten var.",
            )

        created_user = create_user_db(
            db,
            user.model_dump(),
        )

        return {
            "message": "Kullanıcı başarıyla oluşturuldu.",
            "user": {
                "id": created_user.id,
                "full_name": created_user.full_name,
                "email": created_user.email,
                "phone_number": created_user.phone_number,
                "role": created_user.role,
                "city": created_user.city,
                "district": created_user.district,
                "created_at": created_user.created_at,
            },
        }

    except HTTPException:
        raise

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        ) from e

    except Exception as e:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Kullanıcı oluşturulamadı: {e}",
        ) from e
    
@app.get("/fields", summary="Tüm tarlaları listeler")
def list_fields(db: Session = Depends(get_db)):
    try:
        return get_all_fields(db)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Tarlalar alınamadı: {e}",
        )


@app.post("/fields", summary="Yeni tarla oluşturur")
def create_field(
    field: FieldCreateSchema,
    db: Session = Depends(get_db),
):
    try:
        created_field = create_field_db(
            db,
            field.model_dump(),
        )

        return {
            "message": "Tarla başarıyla oluşturuldu.",
            "field": created_field,
        }

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e),
        )

    except Exception as e:
        db.rollback()

        raise HTTPException(
            status_code=500,
            detail=f"Tarla oluşturulamadı: {e}",
        )
