import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import google.generativeai as genai


# ---------------------------------------------------------
# Prompt dosyası
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent

PROMPT_PATH = (
    BASE_DIR.parent
    / "Tarla Gözcüsü AI Agent Sistem Promptu.txt"
)


def load_system_prompt() -> str:
    """
    Sistem promptunu metin dosyasından yükler.

    Dosya bulunamazsa varsayılan sistem promptunu döndürür.
    """

    if PROMPT_PATH.exists():
        with open(
            PROMPT_PATH,
            "r",
            encoding="utf-8",
        ) as file:
            return file.read()

    return (
        "Sen, Tarla Gözcüsü proaktif tarımsal karar destek "
        "sisteminin Merkezi AI Ajanı ve çiftçinin en güvenilir, "
        "bilgili ve pratik Ziraat Mühendisi asistanısın."
    )


# ---------------------------------------------------------
# Gemini / ana öneri üretim fonksiyonu
# ---------------------------------------------------------

def generate_proactive_recommendation(
    tarla_data: Dict[str, Any],
) -> str:
    """
    Tarla verilerini analiz ederek öneri raporu üretir.

    Geçerli bir GEMINI_API_KEY varsa Gemini kullanılır.
    Gemini çağrısı başarısız olursa kural tabanlı rapor üretilir.
    """

    api_key = os.getenv("GEMINI_API_KEY")

    api_key_is_valid = (
        api_key
        and api_key != "YOUR_GEMINI_KEY"
        and len(api_key.strip()) > 10
    )

    if api_key_is_valid:
        try:
            genai.configure(api_key=api_key.strip())
            system_instruction = load_system_prompt()
            
            # Prioritize standard gemini-2.5-flash and gemini-1.5-flash models
            candidate_models = [
                "gemini-2.5-flash",
                "models/gemini-2.5-flash",
                "gemini-2.0-flash",
                "models/gemini-2.0-flash",
                "gemini-1.5-flash",
                "models/gemini-1.5-flash",
                "gemini-1.5-pro",
            ]
            
            try:
                for m in genai.list_models():
                    if "generateContent" in m.supported_generation_methods:
                        name_lower = m.name.lower()
                        # Strictly EXCLUDE audio, tts, gemma, or zero-quota lite models
                        if not any(excluded in name_lower for excluded in ["tts", "embed", "audio", "imagen", "bison", "gemma", "lite"]):
                            if m.name not in candidate_models:
                                candidate_models.append(m.name)
            except Exception as list_err:
                print(f"Could not list models: {list_err}")
            
            # Extract user query if present in history
            user_query = ""
            history = tarla_data.get("farmer_history", [])
            if history and isinstance(history, list) and len(history) > 0:
                last_item = history[-1]
                if isinstance(last_item, dict):
                    user_query = str(last_item.get("details", ""))

            prompt = f"""
            YALNIZCA TÜRKÇE YANIT VER.
            Çiftçimizi selamla ("Merhaba [İsim]"), sorusunu yanıtla, tarlanın canlı nem/sıcaklık verisiyle ilişkilendir ve pratik tavsiyeler ver.
            İngilizce not, 'Structure:', 'Analysis:', 'Greeting:' veya taslak ekleme!

            ÇİFTÇİ SORUSU: "{user_query}"
            TARLA CANLI VERİLERİ: {json.dumps(tarla_data, ensure_ascii=False)}
            """

            for model_name in candidate_models:
                try:
                    model = genai.GenerativeModel(
                        model_name=model_name,
                        system_instruction=system_instruction,
                        generation_config={"temperature": 0.2}
                    )
                    response = model.generate_content(prompt)
                    if response and response.text and len(response.text.strip()) > 10:
                        cleaned = response.text.strip()
                        print(f"Gemini API SUCCESS using model: {model_name}")
                        return cleaned
                except Exception as e:
                    print(f"Gemini model '{model_name}' skipped: {e}")
        except Exception as top_err:
            print(f"Gemini initialization error: {top_err}")

    print("Gemini API call bypassed or failed on all models, using expert fallback rule engine.")
    return generate_mock_expert_advice(tarla_data)

            # Gemini'nin context içindeki gerçek alanları kullanmasını
            # sağlayan ek ve kesin talimatlar.
            
# ---------------------------------------------------------
# Yardımcı fonksiyonlar
# ---------------------------------------------------------

def _to_float(
    value: Any,
) -> Optional[float]:
    """
    Verilen değeri float'a dönüştürür.

    Dönüştürülemeyen veya boş değerlerde None döndürür.
    """

    if value is None:
        return None

    try:
        return float(value)

    except (TypeError, ValueError):
        return None


def _format_number(
    value: Any,
) -> str:
    """
    Sayısal değerleri okunabilir biçimde formatlar.

    Örnek:
    38.0 -> 38
    38.5 -> 38.5
    """

    number = _to_float(value)

    if number is None:
        return "Bilinmiyor"

    if number.is_integer():
        return str(int(number))

    return str(round(number, 2))


def _parse_range(
    value: Any,
    default_min: float,
    default_max: float,
) -> Tuple[float, float]:
    """
    '40-60', '40-60 %' veya '20-30 C' biçimindeki
    aralık metnini iki float değere dönüştürür.
    """

    if value is None:
        return default_min, default_max

    try:
        clean_value = (
            str(value)
            .replace("%", "")
            .replace("°C", "")
            .replace("C", "")
            .strip()
        )

        parts = clean_value.split("-")

        if len(parts) != 2:
            return default_min, default_max

        minimum = float(parts[0].strip())
        maximum = float(parts[1].strip())

        return minimum, maximum

    except (TypeError, ValueError):
        return default_min, default_max


def _get_heavy_rain_status(
    forecast: List[Dict[str, Any]],
) -> bool:
    """
    Tahmin verisinde şiddetli yağış olup olmadığını kontrol eder.
    """

    for day in forecast:
        precipitation = _to_float(
            day.get("precipitation_mm")
        )

        condition = str(
            day.get("condition", "")
        ).lower()

        if (
            precipitation is not None
            and precipitation >= 15.0
        ):
            return True

        heavy_rain_keywords = (
            "şiddetli",
            "yoğun",
            "sağanak",
            "fırtına",
        )

        if any(
            keyword in condition
            for keyword in heavy_rain_keywords
        ):
            return True

    return False


# ---------------------------------------------------------
# Kural tabanlı yedek rapor
# ---------------------------------------------------------

def generate_mock_expert_advice(
    data: Dict[str, Any],
) -> str:
    """
    Gemini kullanılamadığında, sistemde bulunan gerçek verilerle
    kural tabanlı tarımsal durum raporu oluşturur.

    Context içinde olmayan değerler tahmin edilmez.
    """

    user_info = data.get(
        "user_info",
        {},
    ) or {}

    field_info = data.get(
        "field_info",
        {},
    ) or {}

    crop_db = data.get(
        "crop_db_info",
        {},
    ) or {}

    history = data.get(
        "farmer_history",
        [],
    ) or []

    sensors = data.get(
        "sensor_records",
        {},
    ) or {}

    forecast = data.get(
        "weather_forecast",
        [],
    ) or []

    cnn_result = data.get(
        "cnn_disease_result",
        {},
    ) or {}

    irrigation = data.get(
        "irrigation_analysis",
        {},
    ) or {}

    leaching = data.get(
        "leaching_analysis",
        {},
    ) or {}

    farmer_name = (
        user_info.get("name")
        or "Çiftçimiz"
    )

    field_name = (
        field_info.get("field_name")
        or "Tarlanız"
    )

    # Mahsul adı field_info'dan değil,
    # Crop Service verisinden alınır.
    crop_name = crop_db.get(
        "crop_name"
    )

    crop_text = (
        str(crop_name).lower()
        if crop_name
        else "bitki"
    )

    disease_detected = bool(
        cnn_result.get("detected", False)
    )

    disease_name = cnn_result.get(
        "disease_name"
    )

    confidence = _to_float(
        cnn_result.get("confidence_pct")
    )

    has_heavy_rain = (
        _get_heavy_rain_status(
            forecast
        )
    )

    report: List[str] = []

    # -----------------------------------------------------
    # 1. Ana uyarı veya rapor başlığı
    # -----------------------------------------------------

    if disease_detected and disease_name:
        report.append(
            f"🔴 **ACİL UYARI: "
            f"{disease_name} Hastalığı Tespit Edildi!**\n"
        )

        confidence_text = (
            f"%{_format_number(confidence)} güven oranıyla "
            if confidence is not None
            else ""
        )

        report.append(
            "Yapılan görsel analiz sonucunda, "
            f"{crop_text} yapraklarında "
            f"**{confidence_text}{disease_name}** "
            "hastalığı tespit edilmiştir. "
            "Hastalığın yayılımını sınırlamak için "
            "arazi kontrolü yapılmalıdır.\n"
        )

    elif has_heavy_rain:
        report.append(
            "⚠️ **KRİTİK HAVA UYARISI: "
            "Şiddetli Yağış Bekleniyor!**\n"
        )

        report.append(
            "**Sulama yapmayın ve gübre yıkanması riskine "
            "karşı dikkatli olun.** Tahmin verilerinde yoğun "
            "yağış riski görülmektedir.\n"
        )

    else:
        report.append(
            "🌾 **Tarla Gözcüsü Proaktif Durum Raporu**\n"
        )

        report.append(
            f"Merhaba {farmer_name}, "
            f"{field_name} tarlanızdaki güncel koşulları "
            "analiz ettim.\n"
        )

    # -----------------------------------------------------
    # 2. Durum değerlendirmesi
    # -----------------------------------------------------

    report.append(
        "🌾 **Durum Değerlendirmesi:**"
    )

    if crop_name:
        report.append(
            f"*   **Tarla:** "
            f"{field_name} ({crop_name})"
        )
    else:
        report.append(
            f"*   **Tarla:** {field_name}"
        )

    # -----------------------------------------------------
    # Sensör verileri
    # -----------------------------------------------------

    soil_moisture = _to_float(
        sensors.get("soil_moisture_pct")
    )

    soil_temperature = _to_float(
        sensors.get("soil_temp_c")
    )

    air_temperature = _to_float(
        sensors.get("air_temp_c")
    )

    air_humidity = _to_float(
        sensors.get("air_humidity_pct")
    )

    ph_value = _to_float(
        sensors.get("ph")
    )

    ec_value = _to_float(
        sensors.get("ec")
    )

    optimum_moisture_text = crop_db.get(
        "optimum_moisture_range_pct"
    )

    optimum_temperature_text = crop_db.get(
        "optimum_temp_range"
    )

    moisture_min, moisture_max = _parse_range(
        optimum_moisture_text,
        default_min=40.0,
        default_max=60.0,
    )

    temperature_min, temperature_max = _parse_range(
        optimum_temperature_text,
        default_min=20.0,
        default_max=30.0,
    )

    moisture_status: Optional[str] = None

    if soil_moisture is not None:
        if soil_moisture < moisture_min:
            moisture_status = (
                "Düşük"
            )

        elif soil_moisture > moisture_max:
            moisture_status = (
                "Yüksek"
            )

        else:
            moisture_status = (
                "Optimum seviyede"
            )

        if optimum_moisture_text:
            moisture_status += (
                f" (Optimum aralık: "
                f"{optimum_moisture_text})"
            )

        report.append(
            "*   **Toprak Nemi:** "
            f"%{_format_number(soil_moisture)} "
            f"({moisture_status})"
        )

    else:
        report.append(
            "*   **Toprak Nemi:** "
            "Sensör verisi bulunamadı."
        )

    if soil_temperature is not None:
        if (
            soil_temperature < temperature_min
            or soil_temperature > temperature_max
        ):
            temperature_status = (
                "Optimum aralık dışında"
            )
        else:
            temperature_status = (
                "Optimum aralıkta"
            )

        if optimum_temperature_text:
            temperature_status += (
                f" (Optimum aralık: "
                f"{optimum_temperature_text})"
            )

        report.append(
            "*   **Toprak Sıcaklığı:** "
            f"{_format_number(soil_temperature)}°C "
            f"({temperature_status})"
        )

    else:
        report.append(
            "*   **Toprak Sıcaklığı:** "
            "Sensör verisi bulunamadı."
        )

    if air_temperature is not None:
        report.append(
            "*   **Sensör Hava Sıcaklığı:** "
            f"{_format_number(air_temperature)}°C"
        )

    if air_humidity is not None:
        report.append(
            "*   **Sensör Hava Nemi:** "
            f"%{_format_number(air_humidity)}"
        )

    if ph_value is not None:
        report.append(
            "*   **Toprak pH:** "
            f"{_format_number(ph_value)}"
        )

    if ec_value is not None:
        report.append(
            "*   **Toprak EC:** "
            f"{_format_number(ec_value)}"
        )

    # -----------------------------------------------------
    # Hava durumu
    # -----------------------------------------------------

    if forecast:
        today_weather = forecast[0]

        weather_temp = today_weather.get(
            "temp_c"
        )

        weather_humidity = today_weather.get(
            "humidity_pct"
        )

        weather_condition = today_weather.get(
            "condition"
        )

        weather_parts: List[str] = []

        if weather_temp is not None:
            weather_parts.append(
                f"sıcaklık "
                f"{_format_number(weather_temp)}°C"
            )

        if weather_humidity is not None:
            weather_parts.append(
                f"nem "
                f"%{_format_number(weather_humidity)}"
            )

        if weather_condition:
            weather_parts.append(
                f"durum '{weather_condition}'"
            )

        if weather_parts:
            report.append(
                "*   **Hava Durumu:** Bugün "
                + ", ".join(weather_parts)
                + "."
            )

    else:
        report.append(
            "*   **Hava Durumu:** "
            "Tahmin verisi alınamadı."
        )

    # -----------------------------------------------------
    # Geçmiş işlem kontrolü
    # -----------------------------------------------------

    irrigation_found = any(
        str(item.get("action", "")).lower()
        == "sulama"
        for item in history
        if isinstance(item, dict)
    )

    if irrigation_found:
        report.append(
            "*   **Geçmiş İşlemler:** "
            "Sulama kaydı bulunuyor. Yeni sulama kararı "
            "verilirken son işlem zamanı kontrol edilmelidir."
        )

    report.append("")

    # -----------------------------------------------------
    # 3. Hastalık tedavisi
    # -----------------------------------------------------

    if disease_detected and disease_name:
        report.append(
            "🧪 **Tedavi ve Önlem Önerileri:**"
        )

        disease_lower = str(
            disease_name
        ).lower()

        if (
            "mildiyö" in disease_lower
            or "blight" in disease_lower
        ):
            report.append(
                "*   **Kültürel Önlem:** Hastalıklı yaprakları "
                "ayırın, tarladan uzaklaştırın ve bitkiler "
                "arasındaki hava dolaşımını artırın."
            )

            report.append(
                "*   **Uygulama:** Mahsul ve hastalık için "
                "ruhsatlı ürün seçimi konusunda ziraat "
                "mühendisine danışın."
            )

        elif (
            "leke" in disease_lower
            or "spot" in disease_lower
            or "virus" in disease_lower
            or "virüs" in disease_lower
        ):
            report.append(
                "*   **Kültürel Önlem:** Belirti gösteren "
                "yaprak veya bitkileri ayırın ve olası zararlı "
                "vektörlerini kontrol edin."
            )

            report.append(
                "*   **Uygulama:** Kesin hastalık teşhisi "
                "yapılmadan kimyasal uygulamaya başlamayın."
            )

        else:
            report.append(
                "*   **Kültürel Önlem:** Hastalıklı kısımları "
                "ayırın ve tarla havalandırmasını iyileştirin."
            )

            report.append(
                "*   **Uygulama:** Hastalık doğrulaması ve "
                "ruhsatlı ürün seçimi için uzman görüşü alın."
            )

        report.append(
            "\n📌 **Aksiyon Planı:**"
        )

        report.append(
            "1.  **Hastalık belirtisi gösteren yaprakları "
            "işaretleyin ve yayılım durumunu kontrol edin.**"
        )

        report.append(
            "2.  **Kesin teşhis ve uygun uygulama için "
            "ziraat mühendisine veya yetkili uzmana danışın.**"
        )

    # -----------------------------------------------------
    # 4. Şiddetli yağış önlemleri
    # -----------------------------------------------------

    elif has_heavy_rain:
        report.append(
            "💧 **Koruma Önlemleri:**"
        )

        report.append(
            "*   **Sulama:** Yağış öncesinde sulama "
            "sistemini kapatın."
        )

        report.append(
            "*   **Toprak Yönetimi:** Drenaj kanallarını "
            "kontrol ederek su göllenmesini önleyin."
        )

        report.append(
            "*   **Gübreleme:** Yoğun yağış öncesinde yeni "
            "gübreleme yapmayın."
        )

        report.append(
            "\n📌 **Aksiyon Planı:**"
        )

        report.append(
            "1.  **Tarladaki drenaj kanallarını kontrol edin.**"
        )

        report.append(
            "2.  **Sulama sistemini kapatın ve yağış "
            "tamamlanana kadar gübreleme yapmayın.**"
        )

    # -----------------------------------------------------
    # 5. Normal sulama ve besleme önerisi
    # -----------------------------------------------------

    else:
        report.append(
            "💧 **Sulama ve Besleme Önerisi:**"
        )
        
        if irrigation:
            report.append("")
            report.append("💧 **Sulama Analizi:**")

            report.append(
                f"* Günlük su ihtiyacı: "
                f"{_format_number(irrigation.get('daily_water_need_mm'))} mm"
            )

            report.append(
                f"* Metrekare başına su ihtiyacı: "
                f"{_format_number(irrigation.get('daily_water_need_l_per_m2'))} L"
           )

            report.append(
                f"* Tarla alanı: "
                f"{_format_number(irrigation.get('field_area_m2'))} m²"
           )

            report.append(
                f"* Toplam su ihtiyacı: "
                f"{_format_number(irrigation.get('total_water_need_liters'))} litre"
           )

            if irrigation.get("irrigation_required"):
                report.append("* Bugün sulama önerilmektedir.")
            else:
                report.append("* Bugün ek sulama önerilmemektedir.")

        if leaching:
            report.append("")
            report.append("🧪 **NPK Yıkanma Analizi:**")

            report.append(
                f"* Azot kaybı: "
                f"%{_format_number(leaching.get('N_loss_pct'))}"
            )

            report.append(
                f"* Fosfor kaybı: "
                f"%{_format_number(leaching.get('P_loss_pct'))}"
            )

            report.append(
                f"* Potasyum kaybı: "
                f"%{_format_number(leaching.get('K_loss_pct'))}"
            )

        if soil_moisture is None:
            report.append(
                "*   Toprak nemi ölçümü bulunmadığı için "
                "kesin bir sulama kararı verilemedi. "
                "Sensör ölçümünü kontrol edin."
            )

        elif soil_moisture < moisture_min:
            report.append(
                "*   Toprak nemi optimum seviyenin altındadır. "
                "Yağış beklenmiyorsa akşam saatlerinde kontrollü "
                "sulama yapılması önerilir."
            )

        elif soil_moisture > moisture_max:
            report.append(
                "*   Toprak nemi optimum seviyenin üzerindedir. "
                "Aşırı sulamadan kaçınılmalıdır."
            )

        else:
            report.append(
                "*   Toprak nemi optimum aralıktadır. "
                "Şu anda ek sulama yapılmasına gerek yoktur."
            )

        general_notes = crop_db.get(
            "general_notes"
        )

        irrigation_notes = crop_db.get(
            "irrigation_notes"
        )

        if irrigation_notes:
            report.append(
                "*   **Mahsul Sulama Notu:** "
                f"{irrigation_notes}"
            )

        if general_notes:
            report.append(
                "*   **Mahsul Genel Notu:** "
                f"{general_notes}"
            )

        report.append(
            "\n📌 **Aksiyon Planı:**"
        )

        if soil_moisture is None:
            report.append(
                "1.  **Sensör bağlantısını ve son ölçüm "
                "zamanını kontrol edin.**"
            )

            report.append(
                "2.  **Yeni ölçüm alınmadan sulama miktarı "
                "hakkında kesin karar vermeyin.**"
            )

        elif soil_moisture < moisture_min:
            report.append(
                "1.  **Yağış tahminini kontrol ederek akşam "
                "saatlerinde kontrollü sulama yapın.**"
            )

            report.append(
                "2.  **Mahsulün gübreleme programını takip edin "
                "ve gerekirse NPK uygulamasını planlayın.**"
            )

        elif soil_moisture > moisture_max:
            report.append(
                "1.  **Sulamayı durdurun ve toprakta su "
                "birikmesi olup olmadığını kontrol edin.**"
            )

            report.append(
                "2.  **Drenaj ve kök bölgesi havalanmasını "
                "gözlemleyin.**"
            )

        else:
            report.append(
                "1.  **Mevcut nem seviyesini koruyun ve "
                "gereksiz sulama yapmayın.**"
            )

            report.append(
                "2.  **Bitki gelişimini ve sonraki sensör "
                "ölçümlerini takip edin.**"
            )

    return "\n".join(report)