# 🖥️ Tarla Gözcüsü API Gateway & AI Engine

Bu dizin, **Tarla Gözcüsü** projesinin tüm yapay zeka, makine öğrenmesi tahmin modelleri, karar destek algoritmaları, harici hava durumu entegrasyonları ve veritabanı persistence işlemlerini yürüten merkezi **FastAPI** backend servisidir.

---

## ⚡ Teknolojik Altyapı
* **Framework:** FastAPI (Python 3.10+)
* **Database & ORM:** PostgreSQL & SQLAlchemy
* **AI & Machine Learning:** TensorFlow Lite (EfficientNet-B2 yaprak hastalık sınıflandırma modeli)
* **LLM Orchestration:** Google Gemini API (`gemini-1.5-flash`)
* **External Integration:** OpenWeatherMap API

---

## ⚙️ Kurulum ve Çalıştırma

### 1. Gereksinimlerin Yüklenmesi
Sanal ortamınızı (venv) aktif hale getirdikten sonra bağımlılıkları yükleyin:
```bash
pip install -r requirements.txt
```

### 2. Çevre Değişkenlerinin Yapılandırılması
`.env` dosyasını oluşturun veya mevcut `.env` dosyasını kendi anahtarlarınızla güncelleyin:
```env
DATABASE_URL=postgresql://kullanici:sifre@localhost:5432/tarla_gozcusu
OPENWEATHER_API_KEY=YOUR_OPENWEATHER_API_KEY
GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

### 3. Servisin Başlatılması
Sunucuyu uvicorn ile çalıştırmak için:
```bash
python run.py
```
Sunucu varsayılan olarak **`http://localhost:8000`** adresinde ayağa kalkacaktır. Etkileşimli Swagger dokümantasyonuna **`http://localhost:8000/docs`** adresinden erişebilirsiniz.

---

## 🔌 API Endpoints & Kullanım Rehberi

Aşağıda backend sunucumuzda tanımlanmış uç noktalar ve örnek girdi/çıktı (Request/Response) yapıları yer almaktadır:

<details>
<summary><b>1. Sağlık Kontrolü & Durum (GET /)</b></summary>

API'nin çalışıp çalışmadığını ve CNN modelinin sunucuya yüklenme durumunu sorgular.

* **Endpoint:** `/`
* **Method:** `GET`
* **Response Example (200 OK):**
```json
{
  "status": "online",
  "message": "Tarla Gözcüsü API Gateway & AI Engine çalışıyor.",
  "model_loaded": true
}
```
</details>

<details>
<summary><b>2. Yaprak Hastalığı Teşhisi (POST /predict)</b></summary>

Bitki yaprak resminden hastalık tespiti yapar ve güven skorunu döndürür.

* **Endpoint:** `/predict`
* **Method:** `POST`
* **Content-Type:** `multipart/form-data`
* **Query Parameters:** 
  * `threshold` (float, opsiyonel, varsayılan: `0.25`) - Eşik değer (0.0 - 1.0)
  * `latitude` (float, opsiyonel) - Tarla enlemi (Sağlandığında otomatik anonim risk kaydı atar)
  * `longitude` (float, opsiyonel) - Tarla boylamı (Sağlandığında otomatik anonim risk kaydı atar)
  * `province` (str, opsiyonel, varsayılan: `"Bilinmiyor"`) - İl
  * `district` (str, opsiyonel, varsayılan: `"Bilinmiyor"`) - İlçe
  * `crop_name` (str, opsiyonel, varsayılan: `"Genel"`) - Ürün adı
* **Request Body:**
  * `file`: `[Dosya (image/jpeg, image/png)]`

* **Response Example - Başarılı Teşhis & Risk Kaydı Entegrasyonu (200 OK):**
```json
{
  "prediction": "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
  "confidence": 0.924,
  "is_confident": true,
  "threshold_used": 0.25,
  "all_predictions": [
    { "class_name": "Tomato___Tomato_Yellow_Leaf_Curl_Virus", "confidence": 0.924 },
    { "class_name": "Tomato___healthy", "confidence": 0.041 },
    { "class_name": "Tomato___Late_blight", "confidence": 0.015 }
  ],
  "risk_log": {
    "id": "c9a12b45-6789-4def-a123-456789abcdef",
    "grid_code": "GRID_38.46_27.09",
    "risk_level": "Yüksek",
    "province": "Manisa",
    "district": "Salihli"
  }
}
```

* **Response Example - Düşük Güven Skoru Uyarısı (200 OK):**
```json
{
  "prediction": "Pepper__bell___Bacterial_spot",
  "confidence": 0.18,
  "is_confident": false,
  "threshold_used": 0.25,
  "all_predictions": [
    { "class_name": "Pepper__bell___Bacterial_spot", "confidence": 0.18 },
    { "class_name": "healthy", "confidence": 0.12 }
  ],
  "warning": "Tahmin güven skoru (18.00%), belirlenen eşik değerin (25.00%) altındadır. Görüntü net olmayabilir veya model bu tahminden emin olamamıştır. Lütfen daha net veya farklı bir açıdan çekilmiş bir fotoğraf yükleyin."
}
```
</details>

<details>
<summary><b>3. Güncel Hava Durumu (GET /weather/current)</b></summary>

Girilen koordinatlara göre OpenWeatherMap API aracılığıyla güncel hava durumunu döner. (API anahtarı eksikse simüle edilmiş veri döndürür).

* **Endpoint:** `/weather/current`
* **Method:** `GET`
* **Query Parameters:**
  * `latitude` (float, zorunlu) - Enlem
  * `longitude` (float, zorunlu) - Boylam

* **Response Example (200 OK):**
```json
{
  "latitude": 38.4622,
  "longitude": 27.0923,
  "temperature_c": 26.8,
  "humidity_pct": 52,
  "wind_speed_ms": 3.5,
  "wind_speed_kmh": 12.6,
  "city": "İzmir",
  "weather_description": "Parçalı Bulutlu",
  "timestamp": 1783515430
}
```
</details>

<details>
<summary><b>4. 3 Günlük Hava Tahmini (GET /weather/forecast)</b></summary>

Koordinatlara göre 3 günlük detaylı meteorolojik tahmini listeler.

* **Endpoint:** `/weather/forecast`
* **Method:** `GET`
* **Query Parameters:**
  * `latitude` (float, zorunlu) - Enlem
  * `longitude` (float, zorunlu) - Boylam

* **Response Example (200 OK):**
```json
[
  {
    "date": "2026-07-18",
    "temp_c": 28.5,
    "humidity_pct": 50,
    "precipitation_mm": 0.0,
    "condition": "Açık",
    "wind_speed_ms": 2.8
  },
  {
    "date": "2026-07-19",
    "temp_c": 25.1,
    "humidity_pct": 92,
    "precipitation_mm": 25.4,
    "condition": "Şiddetli Yağış",
    "wind_speed_ms": 5.2
  },
  {
    "date": "2026-07-20",
    "temp_c": 26.0,
    "humidity_pct": 60,
    "precipitation_mm": 1.2,
    "condition": "Hafif Yağmurlu",
    "wind_speed_ms": 3.1
  }
]
```
</details>

<details>
<summary><b>5. Sulama Karar Desteği (POST /irrigation)</b></summary>

FAO-56 Penman-Monteith denklemini kullanarak günlük net bitki su ihtiyacını hesaplar.

* **Endpoint:** `/irrigation`
* **Method:** `POST`
* **Content-Type:** `application/json`

* **Request Body Example:**
```json
{
  "weather_data": {
    "temperature_c": 31.2,
    "humidity_pct": 42.0,
    "wind_speed_ms": 3.8,
    "precipitation_mm": 0.0
  },
  "crop_data": {
    "kc": 0.85,
    "root_depth_m": 0.45
  }
}
```

* **Response Example (200 OK):**
```json
{
  "optimal_irrigation_mm": 5.68
}
```
</details>

<details>
<summary><b>6. Gübre Yıkanma Analizi (POST /leaching)</b></summary>

Su girdisi, yağış miktarı ve toprak dokusuna göre Azot (N), Fosfor (P), Potasyum (K) besin kaybı oranlarını hesaplar.

* **Endpoint:** `/leaching`
* **Method:** `POST`
* **Content-Type:** `application/json`

* **Request Body Example:**
```json
{
  "precipitation_mm": 20.0,
  "net_irrigation_mm": 10.0,
  "soil_type": "kumlu"
}
```

* **Response Example (200 OK):**
```json
{
  "N_loss_pct": 82.76,
  "P_loss_pct": 8.79,
  "K_loss_pct": 47.96
}
```
</details>

<details>
<summary><b>7. Proaktif AI Önerisi (POST /ai/recommend)</b></summary>

Tüm sensör, hava durumu, sulama verilerini ve CNN sonuçlarını agronomist uzman sistem promptuna besleyerek Gemini API ile proaktif ve kişiselleştirilmiş bir tarım tavsiyesi üretir.

* **Endpoint:** `/ai/recommend`
* **Method:** `POST`
* **Content-Type:** `application/json`

* **Request Body Example:**
```json
{
  "field_id": "8fa250c6-3023-455b-80df-8929944f331b",
  "recommendation_type": "proactive_report",
  "risk_level": "High",
  "source_data": {
    "user_info": { "name": "Ahmet Yılmaz" },
    "field_info": { "field_name": "Kuzey Kirazlığı", "crop_name": "Kiraz", "growth_stage": "Meyve Gelişimi" },
    "crop_db_info": { "optimum_moisture_range_pct": "50-70 %", "optimum_temp_range": "15-28 C" },
    "sensor_records": { "soil_moisture_pct": 42.0, "soil_temp_c": 29.5 },
    "weather_forecast": [
      { "date": "2026-07-19", "temp_c": 31.0, "humidity_pct": 40, "precipitation_mm": 0.0, "condition": "Açık" }
    ],
    "cnn_disease_result": { "detected": false },
    "farmer_history": [
      { "date": "2026-07-17T09:00:00", "action": "gübreleme" }
    ]
  }
}
```

* **Response Example (200 OK):**
```json
{
  "message": "AI önerisi üretildi ve veritabanına kaydedildi.",
  "recommendation": {
    "id": "e9ef6928-1b2c-473d-88b9-873b88981f21",
    "field_id": "8fa250c6-3023-455b-80df-8929944f331b",
    "recommendation_type": "proactive_report",
    "recommendation_text": "🌾 **Tarla Gözcüsü Proaktif Durum Raporu**\n\nMerhaba Ahmet Bey, Kuzey Kirazlığı tarlanızın anlık koşullarını inceledim.\n\n🌾 **Durum Değerlendirmesi:**\n*   **Tarla:** Kuzey Kirazlığı (Kiraz - Meyve Gelişimi Evresi)\n*   ⚠️ **Toprak Nem Uyarısı:** Toprak nem seviyeniz (%42), kiraz için optimum nem aralığının (%50-70) altına düşmüştür.\n*   ⚠️ **Sıcaklık Uyarısı:** Toprak sıcaklığı (29.5°C), mahsulün konfor sınırını (28°C) aşmış durumda. Bu durum köklerde stres yaratabilir.\n\n💧 **Sulama ve NPK Yönetimi:**\n*   Önümüzdeki günlerde yağış beklenmiyor. Toprak sıcaklığını düşürmek ve nemi ideal seviyeye getirmek için acil sulama planlamalısınız.\n*   17 Temmuz'da yaptığınız gübreleme sonrasında herhangi bir yıkıcı yağış gelmediği için NPK kayıp riskiniz sıfırdır; gübreler toprağınızda korunuyor.\n\n⏱️ **Aksiyon Planı:**\n1. En geç yarın sabah erken saatlerde damlama sulama sisteminizi açarak **en az 3 saat sulama yapın**.\n2. Aşırı sıcaklarda yaprak yanıklıklarına karşı bitki gelişimini izleyin.\n",
    "risk_level": "High",
    "created_at": "2026-07-18T23:44:00.123456"
  }
}
```
</details>

<details>
<summary><b>8. Bölgesel Risk Paylaşımı (POST & GET /risk-logs)</b></summary>

Salgın hastalıkların bölgesel haritasını çıkarmak amacıyla hastalık bulgularını listeler veya yeni risk kaydı ekler.

* **Endpoint:** `/risk-logs`
* **Method:** `POST`
* **Content-Type:** `application/json`

* **Request Body Example (POST):**
```json
{
  "grid_code": "GRID-45-A",
  "region_name": "Ege",
  "province": "Manisa",
  "district": "Salihli",
  "crop_name": "Üzüm",
  "risk_type": "Hastalık Salgını",
  "detected_disease": "Grape Black Rot",
  "risk_level": "High",
  "source": "CNN Teşhis"
}
```

* **Response Example (POST 200 OK):**
```json
{
  "message": "Success",
  "risk_log": {
    "id": 12,
    "grid_code": "GRID-45-A",
    "region_name": "Ege",
    "province": "Manisa",
    "district": "Salihli",
    "crop_name": "Üzüm",
    "risk_type": "Hastalık Salgını",
    "detected_disease": "Grape Black Rot",
    "risk_level": "High",
    "source": "CNN Teşhis",
    "created_at": "2026-07-18T23:45:00.567890"
  }
}
```

* **Method:** `GET` (Tüm risk kayıtlarını döner)
* **Response Example (GET 200 OK):**
```json
[
  {
    "id": 12,
    "grid_code": "GRID-45-A",
    "province": "Manisa",
    "detected_disease": "Grape Black Rot",
    "risk_level": "High",
    "created_at": "2026-07-18T23:45:00"
  }
]
```

* **Bölgesel Risk Seviyesi Hesabı Uç Noktası:**
  * **Endpoint:** `/risk/regional-summary`
  * **Method:** `GET`
  * **Query Parameters:**
    * `province` (str, opsiyonel) - İl filtresi (Örn: "Konya")
    * `district` (str, opsiyonel) - İlçe filtresi (Örn: "Karatay")
    * `crop_name` (str, opsiyonel) - Ürün filtresi (Örn: "Buğday")
    * `days` (int, opsiyonel, varsayılan: `14`) - Analiz edilecek geçmiş gün sayısı
  * **Response Example (GET 200 OK):**
  ```json
  {
    "province": "Konya",
    "district": "Karatay",
    "crop_name": "Buğday",
    "days_analyzed": 14,
    "total_cases": 8,
    "risk_level": "Yüksek",
    "top_diseases": [
      { "disease": "Wheat___Yellow_Rust", "count": 5 },
      { "disease": "Wheat___Septoria", "count": 3 }
    ],
    "last_updated": "2026-07-20T14:45:55.123456+00:00"
  }
  ```
</details>

<details>
<summary><b>9. Kullanıcı ve Tarla Yönetimi (POST /users & POST /fields)</b></summary>

Sisteme yeni kullanıcı kaydeder veya tarla tanımlar.

* **Yeni Kullanıcı Ekleme (`POST /users`):**
  * Request Body:
  ```json
  {
    "full_name": "Veli Yılmaz",
    "email": "veli@tarla.com",
    "password_hash": "$2b$12$ExampleHash...",
    "phone_number": "5551234567",
    "role": "user",
    "city": "Tekirdağ",
    "district": "Süleymanpaşa"
  }
  ```
  * Response Example (200 OK):
  ```json
  {
    "message": "Kullanıcı başarıyla oluşturuldu.",
    "user": { "id": "user-uuid-1234", "email": "veli@tarla.com", ... }
  }
  ```

* **Yeni Tarla Ekleme (`POST /fields`):**
  * Request Body:
  ```json
  {
    "user_id": "user-uuid-1234",
    "field_name": "Göl Kenarı Buğday",
    "province": "Konya",
    "district": "Kulu",
    "latitude": 39.02,
    "longitude": 32.84,
    "area_m2": 15000.0,
    "soil_type": "tınlı",
    "irrigation_type": "Damlama"
  }
  ```
  * Response Example (200 OK):
  ```json
  {
    "message": "Tarla başarıyla oluşturuldu.",
    "field": { "id": "field-uuid-5678", "field_name": "Göl Kenarı Buğday", ... }
  }
  ```
</details>
