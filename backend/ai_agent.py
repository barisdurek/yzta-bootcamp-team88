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

def generate_proactive_recommendation(tarla_data: Dict[str, Any]) -> str:
    """
    Orchestrates the AI Agent report generation.
    If GEMINI_API_KEY is available, calls Gemini. Otherwise, generates a rule-based mock report.
    """
    api_key = os.getenv("GEMINI_API_KEY")
    
    if api_key and api_key != "YOUR_GEMINI_KEY" and len(api_key.strip()) > 10:
        try:
            genai.configure(api_key=api_key)
            system_instruction = load_system_prompt()
            
            # Use gemini-1.5-flash or gemini-2.5-flash
            model = genai.GenerativeModel(
                model_name="gemini-1.5-flash",
                system_instruction=system_instruction,
                generation_config={"response_mime_type": "text/plain", "temperature": 0.2}
            )
            
            response = model.generate_content(json.dumps(tarla_data, ensure_ascii=False))
            return response.text
        except Exception as e:
            print(f"Gemini API call failed, falling back to rule-based generation: {e}")
            
    # Algorithmic Mock Fallback implementing all 6 Prompt Rules:
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
