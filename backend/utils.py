import math
from typing import Optional
from sqlalchemy.orm import Session
from models import AnonymousRiskLog
from crud import create_risk_log

def mask_coordinates_and_log_risk(
    db: Session,
    latitude: float,
    longitude: float,
    province: str = "Bilinmiyor",
    district: str = "Bilinmiyor",
    crop_name: str = "Genel",
    detected_disease: str = "Bilinmiyor",
    confidence: float = 0.0,
    region_name: Optional[str] = None,
    risk_type: str = "Hastalık Tespit",
    source: str = "AI Detection"
) -> AnonymousRiskLog:
    """
    Tarla koordinatlarını 2 ondalık basamağa yuvarlayarak maskeler/anonimleştirir
    ve anonymous_risk_logs tablosuna veritabanı kaydı atar.
    """
    # 2 ondalık basamağa yuvarlayarak grid kodu oluştur (Örn: GRID_37.87_32.48)
    masked_lat = round(latitude, 2)
    masked_lon = round(longitude, 2)
    grid_code = f"GRID_{masked_lat:.2f}_{masked_lon:.2f}"
    
    # Confidence skoru 0-100 aralığındaysa 0-1 aralığına normalize et
    norm_confidence = confidence / 100.0 if confidence > 1.0 else confidence
    
    # Hastalık adında sağlıklı ifadesi varsa Düşük risk, yoksa güven oranına göre Yüksek/Orta risk belirle
    disease_lower = detected_disease.lower()
    if "healthy" in disease_lower or "sağlıklı" in disease_lower:
        risk_level = "Düşük"
    elif norm_confidence >= 0.70:
        risk_level = "Yüksek"
    else:
        risk_level = "Orta"

    # Region name belirtilmemişse varsayılan bölge adını il - ilçe yap
    if not region_name:
        region_name = f"{province} - {district}" if province != "Bilinmiyor" else "Genel Bölge"
        
    log_data = {
        "grid_code": grid_code,
        "region_name": region_name,
        "province": province,
        "district": district,
        "crop_name": crop_name,
        "risk_type": risk_type,
        "detected_disease": detected_disease,
        "risk_level": risk_level,
        "source": source
    }
    
    return create_risk_log(db, log_data)
