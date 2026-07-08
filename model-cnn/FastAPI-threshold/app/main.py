import os
from fastapi import FastAPI, File, UploadFile, Query, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional

from app.model_loader import PlantModelLoader

# FastAPI uygulamasını oluşturma
app = FastAPI(
    title="Plant Disease Classification API",
    description="EfficientNet-B2 tabanlı, PlantVillage veri kümesiyle eğitilmiş bitki hastalığı sınıflandırma ve teşhis REST API'si.",
    version="1.0.0"
)

# CORS ayarları (mobil uygulamalar ve tarayıcılar için)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Yolların tanımlanması
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, "outputs_effnetb2", "efficientnetb2_final_float32.tflite")
LABELS_PATH = os.path.join(BASE_DIR, "outputs_effnetb2", "class_indices.json")

# Model yükleyicisinin başlatılması
try:
    model_loader = PlantModelLoader(model_path=MODEL_PATH, labels_path=LABELS_PATH)
except Exception as e:
    # Model bulunamazsa veya yükleme hatası olursa API'yi kapatmıyoruz ama log basıyoruz
    print(f"HATA: Model yüklenirken hata oluştu: {e}")
    model_loader = None

# Varsayılan güven skoru eşiği (Kullanıcının isteği üzerine %25)
DEFAULT_THRESHOLD = 0.25

# Pydantic Şemaları
class ConfigUpdateSchema(BaseModel):
    confidence_threshold: float = Field(
        ..., 
        ge=0.0, 
        le=1.0, 
        description="0.0 ile 1.0 arasında yeni güven skoru eşik değeri."
    )

class PredictionResponseSchema(BaseModel):
    prediction: str = Field(..., description="En yüksek olasılıklı tahmin edilen sınıf.")
    confidence: float = Field(..., description="Tahminin güven skoru (olasılık).")
    is_confident: bool = Field(..., description="Tahminin güven eşiğini aşıp aşmadığı bilgisi.")
    threshold_used: float = Field(..., description="Tahminde kullanılan güven eşik değeri.")
    all_predictions: List[Dict[str, Any]] = Field(..., description="En iyi 5 tahmin olasılığı.")
    warning: Optional[str] = Field(None, description="Güven eşiğinin altında kalması durumunda uyarı mesajı.")

@app.get("/", response_class=HTMLResponse, tags=["Sistem"])
def read_root():
    template_path = os.path.join(BASE_DIR, "app", "templates", "index.html")
    if os.path.exists(template_path):
        with open(template_path, "r", encoding="utf-8") as f:
            return HTMLResponse(content=f.read(), status_code=200)
    return HTMLResponse(content="<h1>HTML Template Not Found</h1>", status_code=404)

@app.post(
    "/predict", 
    response_model=PredictionResponseSchema,
    summary="Bitki yaprak resminden hastalık teşhisi yapar",
    tags=["Tahmin"]
)
async def predict(
    file: UploadFile = File(..., description="Bitki yaprağı resmi (JPEG, PNG vb.)"),
    threshold: Optional[float] = Query(
        None, 
        ge=0.0, 
        le=1.0, 
        description="Bu istek için kullanılacak özel güven skoru eşiği. Belirtilmezse varsayılan eşik kullanılır."
    )
):
    if model_loader is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Model şu anda yüklü değil veya sunucuda bir yükleme hatası oluştu."
        )

    # Dosya tipi kontrolü
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Yüklenen dosya geçerli bir resim formatında olmalıdır."
        )

    try:
        # Resim baytlarını oku
        image_bytes = await file.read()
        
        # İstek bazlı eşik değerini belirle
        threshold_to_use = threshold if threshold is not None else DEFAULT_THRESHOLD
        
        # Çıkarım yap
        result = model_loader.predict(image_bytes, confidence_threshold=threshold_to_use)
        return result
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Resim işlenirken veya çıkarım yapılırken bir hata oluştu: {str(e)}"
        )

@app.get("/config", tags=["Ayarlar"])
def get_config():
    """
    Sunucu konfigürasyonunu, yüklü sınıfları ve güven eşiğini döner.
    """
    classes = list(model_loader.labels.values()) if model_loader else []
    return {
        "default_confidence_threshold": DEFAULT_THRESHOLD,
        "model_loaded": MODEL_PATH if model_loader else None,
        "class_count": len(classes),
        "classes": classes
    }

@app.post("/config", tags=["Ayarlar"])
def update_config(config: ConfigUpdateSchema):
    """
    Varsayılan güven skoru eşiğini dinamik olarak günceller.
    """
    global DEFAULT_THRESHOLD
    DEFAULT_THRESHOLD = config.confidence_threshold
    return {
        "message": f"Varsayılan güven eşiği başarıyla güncellendi.",
        "new_confidence_threshold": DEFAULT_THRESHOLD
    }
