import math
from typing import Any, Dict

def calculate_optimal_irrigation(weather_data: Dict[str, Any], crop_data: Dict[str, Any]) -> float:
    """
    Hassas tarım ve su yönetimi optimizasyonu kapsamında bitkinin günlük optimum
    sulama ihtiyacını (net sulama miktarı - mm veya L/m²) hesaplayan analitik fonksiyon.
    
    FAO-56 Penman-Monteith yaklaşımını basitleştirerek evapotranspirasyonu (ET) 
    ve bitki kök derinliğine (RD) bağlı su alım kapasitesini modeller.
    
    Args:
        weather_data (Dict[str, Any]): Günlük hava durumu tahmin verileri.
            Beklenen anahtar kelimeler:
            - 'temperature_c' veya 'temp_c': Ortalama hava sıcaklığı (°C)
            - 'humidity_pct' veya 'humidity': Bağıl nem (%)
            - 'wind_speed_ms' veya 'wind_speed' veya 'wind_kph': Rüzgar hızı (m/s veya km/h)
            - 'precipitation_mm' veya 'rain_mm' veya 'precipitation': Günlük yağış miktarı (mm)
        crop_data (Dict[str, Any]): Mahsul ve tarla bilgileri.
            Beklenen anahtar kelimeler:
            - 'root_depth_m' veya 'root_depth': Kök derinliği (metre)
            - 'kc' veya 'crop_coefficient': Mahsul katsayısı (float, varsayılan: 0.85)

    Returns:
        float: Net sulama ihtiyacı (mm veya L/m²). Negatif olamaz, minimum 0.0 döner.
    """
    try:
        # --- 1. Veri Okuma ve Normalizasyon ---
        # Sıcaklık verisinin alınması (varsayılan: 20 °C)
        T = float(weather_data.get('temperature_c', 
                  weather_data.get('temp_c', 
                  weather_data.get('temp', 20.0))))
        
        # Bağıl nem verisinin alınması (varsayılan: %60)
        RH = float(weather_data.get('humidity_pct', 
                    weather_data.get('humidity', 60.0)))
        # Nem sınırlandırılması (%0 - %100 arası)
        RH = max(0.0, min(100.0, RH))
        
        # Rüzgar hızı verisinin alınması ve m/s cinsine çevrilmesi
        wind = weather_data.get('wind_speed_ms', 
                               weather_data.get('wind_speed', 
                               weather_data.get('wind_kph', None)))
        if wind is None:
            u2 = 2.0  # Varsayılan rüzgar hızı (m/s)
        else:
            wind = float(wind)
            # Eğer rüzgar hızı 20'den büyükse ve anahtar 'kph' veya 'kmh' içeriyorsa km/h kabul edelim
            if 'kph' in weather_data or 'kmh' in weather_data or wind > 15.0:
                u2 = wind / 3.6  # km/h -> m/s dönüşümü
            else:
                u2 = wind
        # Negatif rüzgar hızlarını engelleme
        u2 = max(0.1, u2)
        
        # Yağış verisinin alınması (varsayılan: 0.0 mm)
        P = float(weather_data.get('precipitation_mm', 
                   weather_data.get('rain_mm', 
                   weather_data.get('precipitation', 0.0))))
        P = max(0.0, P)
        
        # Kök derinliği verisinin alınması (varsayılan: 0.5 metre)
        RD = float(crop_data.get('root_depth_m', 
                    crop_data.get('root_depth', 0.5)))
        RD = max(0.1, RD)  # Minimum kök derinliği 10 cm olarak sınırlandırılır
        
        # Crop Coefficient (Kc) değerinin alınması (varsayılan: 0.85)
        Kc = float(crop_data.get('kc', 
                    crop_data.get('crop_coefficient', 0.85)))
        Kc = max(0.1, Kc)

        # --- 2. Evapotranspirasyon (ET0) Hesaplaması (Basitleştirilmiş FAO-56 Penman-Monteith) ---
        # Doymuş buhar basıncı (e_s) hesaplama (kPa) - Tetens Formülü
        e_s = 0.6108 * math.exp((17.27 * T) / (T + 237.3))
        
        # Gerçek buhar basıncı (e_a) hesaplama (kPa)
        e_a = e_s * (RH / 100.0)
        
        # Buhar basıncı açığı (VPD) (kPa)
        VPD = max(0.0, e_s - e_a)
        
        # Sıcaklığa bağlı doymuş buhar basıncı eğrisinin eğimi (Delta) (kPa/°C)
        delta = (4098.0 * e_s) / ((T + 237.3) ** 2)
        
        # Psikrometrik sabit (gamma) (kPa/°C) - Deniz seviyesi için yaklaşıklık
        gamma = 0.067
        
        # Net Radyasyon (Rn) tahmini (MJ/m²/gün)
        # Sıcaklık arttıkça artan, bağıl nem arttıkça bulutluluktan ötürü azalan ampirik radyasyon modeli
        Rn = 13.5 * (1.0 - (RH / 200.0)) + 0.1 * T
        Rn = max(0.5, Rn)
        
        # FAO-56 Penman-Monteith Referans Evapotranspirasyon Formülü (ET0 - mm/gün)
        numerator = 0.408 * delta * Rn + gamma * (900.0 / (T + 273.15)) * u2 * VPD
        denominator = delta + gamma * (1.0 + 0.34 * u2)
        ET0 = numerator / denominator
        ET0 = max(0.0, ET0)
        
        # --- 3. Kök Derinliği Etkisinin Modellenmesi ---
        # Bitkinin kök derinliği (RD), topraktaki aktif su alma yüzey alanını ve su çekme kapasitesini belirler.
        # Sığ köklü bitkilerin transpirasyon kapasitesi fiziksel olarak kısıtlıdır.
        # Bu kısıt, lambda = 3.5 katsayısına sahip asimptotik bir kök verimlilik fonksiyonuyla (K_root) modele dahil edilir.
        lambda_coeff = 3.5
        K_root = 1.0 - math.exp(-lambda_coeff * RD)
        
        # Bitki Su İhtiyacı (ET_crop) (mm/gün)
        ET_crop = ET0 * Kc * K_root
        
        # --- 4. Yağış Optimizasyonu (Net Sulama İhtiyacı) ---
        # Yağan yağmurun tamamı toprakta tutulamaz (yüzey akışı ve derine süzülme kayıpları).
        # Bu nedenle etkin yağış (P_eff) oranı %80 (0.80) olarak modele dahil edilir.
        P_eff = P * 0.80
        
        # Net sulama ihtiyacı hesaplanır (mm veya L/m²)
        net_irrigation = ET_crop - P_eff
        
        # Eğer yağış ihtiyacı tamamen veya fazlasıyla karşılıyorsa net sulama 0 olmalıdır.
        return round(max(0.0, net_irrigation), 2)

    except (ValueError, TypeError, ZeroDivisionError) as e:
        # Eksik veya hatalı veri gelmesi durumunda güvenli varsayılan değer döndürülür
        # Hata yönetimi (Error Handling) ve loglama dostu yapı
        print(f"Sulama optimizasyon algoritmasında hata oluştu: {str(e)}. Varsayılan 0.0 döndürülüyor.")
        return 0.0
