import os
import sys
import requests

def test_backend_resilience():
    print("=== TARLA GOZCUSU DAYANIKLILIK VE HATA YONETIMI TESTLERI ===")
    backend_url = "http://127.0.0.1:8000"
    
    # 1. OpenWeatherMap Rate-Limit / Fallback Test
    print("\n[TEST 1] OpenWeatherMap Rate-Limit ve Kesinti Fallback Testi...")
    try:
        res = requests.get(f"{backend_url}/weather/current?latitude=37.87&longitude=32.49", timeout=5)
        print(f"Status Code: {res.status_code}")
        if res.status_code == 200:
            data = res.json()
            print(f"[OK] HAVA DURUMU BASARILI: Sicaklik={data.get('temperature_c')}C, Sehir={data.get('city')}, Durum={data.get('weather_description')}")
        else:
            print(f"[FAIL] Basarisiz Durum Code: {res.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"[OFFLINE] Backend sunucusu kapali veya baglanti kurulamadi: {e}")

    # 2. AI Recommendation Endpoint Error Handling Test
    print("\n[TEST 2] AI Recommendation Endpoint & Veritabanı Kesintisi Testi...")
    payload = {
        "current_time": "2026-07-26T15:00:00",
        "user_info": {"name": "Test Ciftci", "location": "Konya"},
        "field_info": {"field_name": "Test Tarla", "crop_name": "Domates", "growth_stage": "Fide Donemi"},
        "crop_db_info": {"optimum_temp_range": "20-30 C"},
        "sensor_records": {"soil_moisture_pct": 52.0, "soil_temp_c": 23.0},
        "weather_forecast": [{"date": "2026-07-26", "temp_c": 28.0, "condition": "Acik"}]
    }
    try:
        res = requests.post(f"{backend_url}/ai/recommend", json=payload, timeout=10)
        print(f"Status Code: {res.status_code}")
        if res.status_code == 200:
            data = res.json()
            rec = data.get("recommendation", {})
            text = rec.get("recommendation_text", "")
            print(f"[OK] AI ONERISI ALINDI ({len(text)} karakter).")
            print(f"Ornek Cikti: {text[:100]}...")
        else:
            print(f"[FAIL] AI Onerisi Hata: {res.status_code} - {res.text}")
    except requests.exceptions.RequestException as e:
        print(f"[OFFLINE] AI Endpoint baglantisi kurulamadi (Sunucu kapali): {e}")

    # 3. Regional Risk Logs Fallback Test
    print("\n[TEST 3] Bolgesel Risk Loglari & DB Fallback Testi...")
    try:
        res = requests.get(f"{backend_url}/risk-logs", timeout=5)
        print(f"Status Code: {res.status_code}")
        if res.status_code == 200:
            data = res.json()
            print(f"[OK] RISK LOGLARI ALINDI ({len(data)} adet kayit).")
        else:
            print(f"[FAIL] Risk Log Hata: {res.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"[OFFLINE] Risk logs baglantisi kurulamadi (Sunucu kapali): {e}")

    print("\n=== TUM TESTLER TAMAMLANDI ===")

if __name__ == "__main__":
    test_backend_resilience()
