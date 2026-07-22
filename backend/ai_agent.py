import os
import json
from pathlib import Path
from typing import Any, Dict
import google.generativeai as genai
from datetime import datetime

# Load prompt text
BASE_DIR = Path(__file__).resolve().parent
PROMPT_PATH = BASE_DIR.parent / "Tarla Gözcüsü AI Agent Sistem Promptu.txt"

def load_system_prompt() -> str:
    if PROMPT_PATH.exists():
        with open(PROMPT_PATH, "r", encoding="utf-8") as f:
            return f.read()
    return """Sen, Tarla Gözcüsü proaktif tarımsal karar destek sisteminin Merkezi AI Ajanı ve çiftçinin en güvenilir, bilgili ve pratik Ziraat Mühendisi asistanısın."""

def clean_agent_output(text: str) -> str:
    """
    Strips internal thinking, metadata echo, backticks, English outline headers, or Gemma reasoning trees.
    Returns only the clean, final Turkish response for the farmer.
    """
    if not text:
        return ""

    lines = text.split("\n")
    cleaned_lines = []
    
    # English outline/reasoning keywords to skip
    skip_keywords = [
        "structure:", "greeting:", "cnn check:", "analysis:", "explanation:",
        "persona:", "tone:", "language level:", "input data analysis:", 
        "farmer's question:", "symptom:", "common causes:", "directly address",
        "no internal thoughts", "use the provided system prompt", "greeting.", "action plan."
    ]

    for line in lines:
        stripped = line.strip()
        lower_line = stripped.lower()

        # Skip backticks or raw metadata keys
        if stripped.startswith("`") or stripped.startswith("* `") or stripped.startswith("- `"):
            continue

        # Skip numbered outline items like "1. Greeting.", "2. Status Assessment", etc.
        if any(lower_line.startswith(p) for p in ["1. greeting", "2. status assessment", "3. possible causes", "4. action plan"]):
            continue

        # Skip bullet points starting with English reasoning labels
        if any(marker in lower_line for marker in skip_keywords):
            continue

        cleaned_lines.append(line)

    result = "\n".join(cleaned_lines).strip()
    
    # Strip stray trailing quotes after greeting.
    result = result.replace('".', '.').replace('"', '')

    # Ensure result starts cleanly with greeting or icon
    lower_res = result.lower()
    turkish_triggers = ["merhaba", "selam", "🌾", "🍃", "🔴", "⚠️", "değerli çiftçimiz", "tarla gözcüsü"]
    first_idx = -1
    for trigger in turkish_triggers:
        idx = lower_res.find(trigger)
        if idx != -1:
            if first_idx == -1 or idx < first_idx:
                first_idx = idx

    if first_idx > 0:
        result = result[first_idx:].strip()

    return result if len(result) > 10 else text

def generate_proactive_recommendation(tarla_data: Dict[str, Any]) -> str:
    """
    Orchestrates the AI Agent report generation using standard Gemini models.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    
    if api_key and api_key != "YOUR_GEMINI_KEY" and len(api_key.strip()) > 10:
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
                        cleaned = clean_agent_output(response.text)
                        print(f"Gemini API SUCCESS using model: {model_name}")
                        return cleaned
                except Exception as e:
                    print(f"Gemini model '{model_name}' skipped: {e}")
        except Exception as top_err:
            print(f"Gemini initialization error: {top_err}")

    print("Gemini API call bypassed or failed on all models, using expert fallback rule engine.")
    return generate_mock_expert_advice(tarla_data)

def generate_mock_expert_advice(data: Dict[str, Any]) -> str:
    """
    Algorithmic agent report matching the persona, tone, rules, and format of the system prompt.
    """
    user_info = data.get("user_info", {})
    field_info = data.get("field_info", {})
    crop_db = data.get("crop_db_info", {})
    history = data.get("farmer_history", [])
    sensors = data.get("sensor_records", {})
    forecast = data.get("weather_forecast", [])
    cnn_result = data.get("cnn_disease_result", {})

    user_query = ""
    if history and isinstance(history, list) and len(history) > 0:
        last_item = history[-1]
        if isinstance(last_item, dict):
            user_query = str(last_item.get("details", "")).lower()

    farmer_name = user_info.get("name", "Çiftçimiz")
    location = user_info.get("location", "Ege Bölgesi")
    field_name = field_info.get("field_name", "Tarlanız")
    crop_name = field_info.get("crop_name", "Mahsul")
    growth_stage = field_info.get("growth_stage", "Gelişim")
    
    report = []
    
    # 1. Rule 3: CNN Disease Detection Alarm
    disease_detected = cnn_result.get("detected", False)
    disease_name = cnn_result.get("disease_name")
    confidence = cnn_result.get("confidence_pct", 0)
    
    if disease_detected and disease_name:
        report.append(f"🔴 **ACİL UYARI: {disease_name} Hastalığı Tespit Edildi!**\n")
        report.append(f"Yapılan görsel analiz sonucunda, {crop_name.lower()} yapraklarında **%{confidence} güven oranıyla {disease_name}** hastalığı tespit edilmiştir. Nem oranının yüksek olması hastalığın yayılmasını hızlandırabilir. Vakit kaybetmeden müdahale etmeliyiz.\n")
    else:
        # Check heavy rain rule
        has_heavy_rain = False
        rain_days = 0
        for day in forecast:
            precip = float(day.get("precipitation_mm", 0.0) or 0.0)
            cond = day.get("condition", "")
            if precip >= 15.0 or "Şiddetli" in cond or "Yoğun" in cond:
                rain_days += 1
        if rain_days >= 1:
            has_heavy_rain = True
            
        if has_heavy_rain:
            report.append(f"⚠️ **KRİTİK HAVA UYARISI: Şiddetli Yağış Geliyor!**\n")
            report.append(f"**Sulama yapma ve gübre yıkanmasına (NPK kaybına) karşı dikkatli ol.** Önümüzdeki günlerde bölgede yoğun yağışlar tahmin edilmektedir.\n")
        elif "yeşil" in user_query or "sarı" in user_query or "renk" in user_query or "yaprak" in user_query:
            report.append(f"🍃 **Ziraat Mühendisi Teşhisi (Yaprak Renk Değişimi & Kloroz):**\n")
            report.append(f"Merhaba {farmer_name}, {field_name} tarlanızdaki {crop_name} yapraklarında gözlemlediğiniz açık yeşil/sarı renk değişimi (kloroz) 2 ana sebepten kaynaklanır:\n")
            report.append(f"1. **Azot (N) Noksanlığı:** Bitki gelişim döneminde yeterli azotu alamadığında klorofil sentezi yavaşlar ve yapraklar açık yeşile/sarıya döner.")
            report.append(f"2. **Aşırı Sulama / Kök Oksijensizliği:** Toprak neminin yüksek kalması kök solunumunu ve besin emilimini engeller.\n")
            report.append(f"💡 **Tavsiye:** Damlama sulama ile azot takviyesi yapın ve toprak havalanmasını sağlayın.\n")
        else:
            report.append(f"🌾 **Tarla Gözcüsü Proaktif Durum Raporu**\n")
            report.append(f"Merhaba {farmer_name}, {field_name} tarlanızdaki güncel koşulları analiz ettim. Genel durum stabil görünüyor.\n")
            
    # 2. Durum Değerlendirmesi
    report.append(f"🌾 **Durum Değerlendirmesi:**")
    report.append(f"*   **Tarla:** {field_name} ({crop_name} - {growth_stage} Evresi)")
    
    # Sensor vs Crop DB comparison (Rule 6)
    soil_moist = sensors.get("soil_moisture_pct", 50)
    soil_temp = sensors.get("soil_temp_c", 22)
    
    opt_moist_str = crop_db.get("optimum_moisture_range_pct", "40-60 %")
    opt_temp_str = crop_db.get("optimum_temp_range", "20-30 C")
    
    # Try to parse ranges
    try:
        m_min, m_max = [float(x.strip().replace('%','')) for x in opt_moist_str.split('-')]
    except:
        m_min, m_max = 40.0, 60.0
        
    moist_status = "Optimum seviyede"
    if soil_moist < m_min:
        moist_status = f"Düşük (Optimum aralık: {opt_moist_str})"
    elif soil_moist > m_max:
        moist_status = f"Yüksek (Optimum aralık: {opt_moist_str})"
        
    report.append(f"*   **Toprak Nemi:** %{soil_moist} ({moist_status})")
    report.append(f"*   **Toprak Sıcaklığı:** {soil_temp}°C (Optimum aralık: {opt_temp_str})")
    
    # Weather summary
    if forecast:
        today_weather = forecast[0]
        report.append(f"*   **Hava Durumu:** Bugün sıcaklık {today_weather.get('temp_c')}°C, nem %{today_weather.get('humidity_pct')} ve durum '{today_weather.get('condition')}'.")
        
    # History check (Rule 5)
    last_irrigation_hours = None
    for hist in reversed(history):
        if hist.get("action") == "sulama":
            # Let's say it was recent for representation
            last_irrigation_hours = 24
            break
            
    if last_irrigation_hours is not None:
        report.append(f"*   **Geçmiş İşlemler:** Yakın zamanda sulama yapılmış. Toprakta aşırı su birikmesini önlemek adına ek sulama yapılmamalıdır.")
        
    report.append("") # newline
    
    # 3. Action plan and treatment (Rule 3 remedies)
    if disease_detected:
        report.append(f"🧪 **Tedavi ve Önlem Reçetesi:**")
        # Custom advice based on disease
        if "Mildiyö" in disease_name or "blight" in disease_name.lower():
            report.append(f"*   **Organik Çözüm:** Bakırlı fungusitler (organik tarıma uygun bakır hidroksit veya bakır oksi klorür içerikli) kullanarak bitki yüzeyini kaplayın. Hastalıklı yaprakları budayıp tarladan uzaklaştırarak yakın.")
            report.append(f"*   **Kimyasal Çözüm:** Hastalığın hızlı yayılmasını önlemek için sistemik etkili *Metalaxyl* veya *Cymoxanil* aktif maddeli ruhsatlı ilaçlar tercih edilmelidir.")
        elif "Leke" in disease_name or "spot" in disease_name.lower() or "Virus" in disease_name or "virus" in disease_name.lower():
            report.append(f"*   **Organik Çözüm:** Neem yağı spreyi uygulayarak böcek vektörleri kontrol altına alın. Hastalıklı bitkileri söküp imha edin.")
            report.append(f"*   **Kimyasal Çözüm:** Bakır sülfat bazlı preparatlar veya sistemik antiviral/antifungal koruyucular kullanın.")
        else:
            report.append(f"*   **Organik Çözüm:** Kükürtlü organik toz püskürtmesi yapın. Tarladaki havalandırmayı artırmak için budama yapın.")
            report.append(f"*   **Kimyasal Çözüm:** Sınıfına uygun tescilli geniş spektrumlu bir fungisit uygulayın.")
            
        report.append("\n📌 **Aksiyon Planı:**")
        report.append(f"1.  **Hemen hastalıklı yaprakları budayın ve tarladan uzaklaştırıp imha edin.**")
        report.append(f"2.  **Rüzgarsız bir saatte uygun organik bakırlı ilaç veya sistemik ilaç uygulaması yapın.**")
        
    elif has_heavy_rain:
        report.append(f"💧 **Koruma Önlemleri:**")
        report.append(f"*   **Sulama:** Kesinlikle sulama sistemlerini kapatın.")
        report.append(f"*   **Toprak Yönetimi:** Drenaj kanallarını açık tutarak tarlada su göllenmesini engelleyin. Yağış sonrası oluşabilecek azot kaybını (gübre yıkanması) yaprak gübrelemesi ile telafi edeceğiz.")
        
        report.append("\n📌 **Aksiyon Planı:**")
        report.append(f"1.  **Tarladaki drenaj kanallarını kontrol ederek su birikintisi oluşmasını engelleyin.**")
        report.append(f"2.  **Sulama sistemini tamamen kapatın ve yağış bitene kadar yeni gübreleme yapmayın.**")
        
    else:
        report.append(f"💧 **Sulama ve Besleme Önerisi:**")
        if soil_moist < m_min:
            report.append(f"*   Toprak nemi seviyesi düşüktür. Bugün akşam saatlerinde hafif bir sulama yapılması önerilir.")
        else:
            report.append(f"*   Toprak nemi yeterlidir. Su tasarrufu sağlamak için sulama yapmaya gerek yoktur.")
            
        report.append("\n📌 **Aksiyon Planı:**")
        if soil_moist < m_min:
            report.append(f"1.  **Toprak nemini dengede tutmak için akşam rüzgarsız havada sulamayı başlatın.**")
            report.append(f"2.  **Mahsulün büyüme evresi gereksinimi olan NPK gübrelemesini takip edin.**")
        else:
            report.append(f"1.  **Sulama yapmayarak su kaynaklarını koruyun ve toprak havalanmasını sağlayın.**")
            report.append(f"2.  **Tarladaki bitki gelişimini gözlemlemeye devam edin.**")
            
    return "\n".join(report)
