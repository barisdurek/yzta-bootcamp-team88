import sys
from irrigation import calculate_optimal_irrigation

def test_irrigation():
    # Test case 1: Sıcak ve kuru hava (Sulama ihtiyacı yüksek olmalı)
    weather_1 = {
        "temperature_c": 32.0,
        "humidity_pct": 30.0,
        "wind_speed_ms": 3.0,
        "precipitation_mm": 0.0
    }
    crop_1 = {
        "root_depth_m": 0.6,
        "kc": 1.15  # Gelişme dönemi domates
    }
    
    # Test case 2: Yağışlı hava (Sulama ihtiyacı 0 olmalı)
    weather_2 = {
        "temperature_c": 22.0,
        "humidity_pct": 85.0,
        "wind_speed_ms": 2.5,
        "precipitation_mm": 15.0
    }
    crop_2 = {
        "root_depth_m": 0.6,
        "kc": 1.15
    }
    
    # Test case 3: Sığ köklü bitki vs. Derin köklü bitki (Sığ köklü bitkinin günlük transpirasyon kapasitesi daha azdır)
    weather_3 = {
        "temperature_c": 28.0,
        "humidity_pct": 50.0,
        "wind_speed_ms": 2.0,
        "precipitation_mm": 0.0
    }
    crop_3_shallow = {
        "root_depth_m": 0.15,
        "kc": 0.85
    }
    crop_3_deep = {
        "root_depth_m": 0.8,
        "kc": 0.85
    }
    
    # Test case 4: Hatalı veya eksik veri (Güvenli şekilde 0.0 dönmeli)
    weather_corrupt = {
        "temperature_c": "invalid_value",
        "humidity_pct": None
    }
    crop_corrupt = {
        "root_depth_m": 0.5
    }

    result_1 = calculate_optimal_irrigation(weather_1, crop_1)
    result_2 = calculate_optimal_irrigation(weather_2, crop_2)
    result_3_shallow = calculate_optimal_irrigation(weather_3, crop_3_shallow)
    result_3_deep = calculate_optimal_irrigation(weather_3, crop_3_deep)
    result_corrupt = calculate_optimal_irrigation(weather_corrupt, crop_corrupt)

    print(f"Test 1 (Sıcak/Kuru, Yağışsız) Net Sulama: {result_1} mm")
    print(f"Test 2 (Yağışlı) Net Sulama: {result_2} mm")
    print(f"Test 3 (Sığ Kök, RD=0.15m) Net Sulama: {result_3_shallow} mm")
    print(f"Test 3 (Derin Kök, RD=0.80m) Net Sulama: {result_3_deep} mm")
    print(f"Test 4 (Bozuk Veri) Net Sulama: {result_corrupt} mm")

    assert result_1 > 0, "Sıcak ve kuru havada sulama ihtiyacı çıkmalıydı!"
    assert result_2 == 0.0, "Yüksek yağışlı havada sulama ihtiyacı 0 olmalıydı!"
    assert result_3_shallow < result_3_deep, "Sığ köklü bitkinin günlük transpirasyon su kaybı daha az olmalıydı!"
    assert result_corrupt == 0.0, "Hatalı veride güvenli varsayılan olarak 0.0 dönmeliydi!"
    
    # --- NPK Leaching Testleri ---
    from leaching import calculate_npk_leaching
    
    # Test case 5: Kum toprakta yüksek su girişi (Yüksek süzülme ve yıkanma)
    leach_sand = calculate_npk_leaching(precipitation_mm=25.0, net_irrigation_mm=15.0, soil_type="sand")
    print(f"Test 5 (Kum, 40mm Su Girişi) NPK Kayıpları: {leach_sand}")
    assert leach_sand['N_loss_pct'] > leach_sand['K_loss_pct'], "Azot yıkanması potasyumdan fazla olmalı!"
    assert leach_sand['K_loss_pct'] > leach_sand['P_loss_pct'], "Potasyum yıkanması fosfordan fazla olmalı!"
    
    # Test case 6: Kil toprakta aynı su girişi (Daha düşük süzülme ve yıkanma)
    leach_clay = calculate_npk_leaching(precipitation_mm=25.0, net_irrigation_mm=15.0, soil_type="clay")
    print(f"Test 6 (Kil, 40mm Su Girişi) NPK Kayıpları: {leach_clay}")
    assert leach_sand['N_loss_pct'] > leach_clay['N_loss_pct'], "Kumlu toprakta yıkanma killi topraktan fazla olmalı!"
    
    # Test case 7: Su girişi sınır değerinin altında (Yıkanma 0 olmalı)
    leach_dry = calculate_npk_leaching(precipitation_mm=2.0, net_irrigation_mm=0.0, soil_type="loam")
    print(f"Test 7 (Tınlı, 2mm Su Girişi) NPK Kayıpları: {leach_dry}")
    assert leach_dry['N_loss_pct'] == 0.0, "Kapasite altındaki su girişinde yıkanma olmamalı!"
    
    # Test case 8: Hatalı toprak tipi veya bozuk veriler (Güvenli varsayılan tınlı olmalı)
    leach_invalid = calculate_npk_leaching(precipitation_mm="invalid", net_irrigation_mm=20.0, soil_type="unknown_soil")
    print(f"Test 8 (Bozuk/Bilinmeyen Veri) NPK Kayıpları: {leach_invalid}")
    # Hata durumunda default_losses (0.0 değerleri) döner.
    assert leach_invalid['N_loss_pct'] == 0.0, "Hatalı veride yıkanma kaybı 0.0 dönmeli!"
    
    print("Tüm sulama ve NPK yıkanma testleri başarıyla geçildi!")

if __name__ == "__main__":
    test_irrigation()

