import math
from typing import Dict

def calculate_npk_leaching(precipitation_mm: float, net_irrigation_mm: float, soil_type: str) -> Dict[str, float]:
    """
    Toprağa giren su miktarı (yağış + sulama) ve toprak tipine bağlı olarak
    Azot (N), Fosfor (P) ve Potasyum (K) gübre yıkanma (leaching) kayıp yüzdelerini hesaplar.

    Args:
        precipitation_mm (float): Günlük gerçekleşen/tahmin edilen yağış miktarı (mm).
        net_irrigation_mm (float): Günlük uygulanan net sulama miktarı (mm).
        soil_type (str): Toprak tipi. 'sand' (kum), 'loam' (tın) veya 'clay' (kil) olmalıdır.

    Returns:
        Dict[str, float]: N, P, K yıkanma kayıp yüzdelerini içeren sözlük.
            Örn: {'N_loss_pct': 12.50, 'P_loss_pct': 1.20, 'K_loss_pct': 4.50}
    """
    # Varsayılan güvenli geri dönüş sözlüğü (hata veya yıkanma olmaması durumunda)
    default_losses = {'N_loss_pct': 0.0, 'P_loss_pct': 0.0, 'K_loss_pct': 0.0}
    
    try:
        # --- 1. Veri Tiplerinin Doğrulanması ---
        p_val = float(precipitation_mm)
        i_val = float(net_irrigation_mm)
        
        # Negatif değerleri engelleme
        p_val = max(0.0, p_val)
        i_val = max(0.0, i_val)
        
        # Toplam su girdisi (mm)
        total_water = p_val + i_val
        if total_water <= 0.0:
            return default_losses
            
        # Toprak tipini normalize etme (küçük harfe çevirme ve Türkçe karakter uyumluluğu)
        soil = str(soil_type).strip().lower()
        
        # --- 2. Toprak Su Tutma Kapasitesi ve Süzülme Katsayılarının Tanımlanması ---
        # Her toprak tipinin günlük su tutma kapasitesi (S_cap - mm/gün) ve 
        # bu kapasiteyi aşan suyun sızma/süzülme katsayısı (f_perc - 0 ile 1 arası) farklıdır.
        # Kumlu topraklar suyu çok az tutar ve süzülme oranı çok yüksektir.
        # Killi topraklar ise suyu güçlü tutar ve süzülme oranı düşüktür.
        soil_parameters = {
            'sand': {'S_cap': 8.0, 'f_perc': 0.85},
            'kum': {'S_cap': 8.0, 'f_perc': 0.85},
            'kumlu': {'S_cap': 8.0, 'f_perc': 0.85},
            
            'loam': {'S_cap': 20.0, 'f_perc': 0.50},
            'tin': {'S_cap': 20.0, 'f_perc': 0.50},
            'tın': {'S_cap': 20.0, 'f_perc': 0.50},
            'tınlı': {'S_cap': 20.0, 'f_perc': 0.50},
            
            'clay': {'S_cap': 35.0, 'f_perc': 0.20},
            'kil': {'S_cap': 35.0, 'f_perc': 0.20},
            'killi': {'S_cap': 35.0, 'f_perc': 0.20}
        }
        
        # Geçersiz toprak tipi girilirse varsayılan olarak orta kararlı 'loam' (tınlı) seçilir.
        params = soil_parameters.get(soil, soil_parameters['loam'])
        S_cap = params['S_cap']
        f_perc = params['f_perc']
        
        # --- 3. Derine Süzülme (Percolation) Hacminin Hesaplanması ---
        # Toprağa giren su, günlük tutma kapasitesini (S_cap) aştığında sızma başlar.
        excess_water = max(0.0, total_water - S_cap)
        percolated_water = excess_water * f_perc  # Derine süzülen su miktarı (mm)
        
        if percolated_water <= 0.0:
            return default_losses
            
        # --- 4. NPK Hareketliliği ve Yıkanma Katsayı Matrisinin Belirlenmesi ---
        # Elementlerin yıkanma hızı topraktaki anyon/katyon değişim kapasitesine (CEC) ve çözünürlüğe bağlıdır.
        # Kil oranına göre yıkanma katsayıları (alpha) değişir (Kil mineralleri potasyumu ve fosforu tutar).
        # N (Azot): Suda çok hareketli, anyon formunda (NO3-) olduğu için toprak tarafından tutunamaz.
        # K (Potasyum): Orta hareketli, katyon formunda (K+) olduğu için kilde kısmen tutulur.
        # P (Fosfor): Hareketsizdir, toprak partiküllerine (Al, Fe, Ca bağları ile) çok sıkı adsorbe olur.
        if soil in ['sand', 'kum', 'kumlu']:
            alpha_N = 0.080  # Kumlu toprakta azot yıkanması çok hızlıdır
            alpha_K = 0.030
            alpha_P = 0.005  # Düşük organik madde ve kilden ötürü kumda az da olsa yıkanabilir
        elif soil in ['clay', 'kil', 'killi']:
            alpha_N = 0.030  # Kil, su akışını yavaşlattığı için azot yıkanması yavaştır
            alpha_K = 0.008  # Kil mineralleri potasyumu güçlü tutar
            alpha_P = 0.0005 # Kil fosforu neredeyse tamamen sabitler
        else:  # loam / tınlı (varsayılan)
            alpha_N = 0.050
            alpha_K = 0.015
            alpha_P = 0.0015
            
        # --- 5. Asimptotik Yıkanma Kayıp Yüzdesi Hesaplaması ---
        # Kayıp yüzdeleri, süzülen su arttıkça asimptotik olarak %100'e yaklaşan 
        # bir logaritmik-üstel fonksiyon (First-Order Kinetic Leaching Model) ile modellenir.
        N_loss = 100.0 * (1.0 - math.exp(-alpha_N * percolated_water))
        P_loss = 100.0 * (1.0 - math.exp(-alpha_P * percolated_water))
        K_loss = 100.0 * (1.0 - math.exp(-alpha_K * percolated_water))
        
        # Değerlerin sınırlandırılması (%0 - %100)
        return {
            'N_loss_pct': round(max(0.0, min(100.0, N_loss)), 2),
            'P_loss_pct': round(max(0.0, min(100.0, P_loss)), 2),
            'K_loss_pct': round(max(0.0, min(100.0, K_loss)), 2)
        }

    except (ValueError, TypeError, ZeroDivisionError) as e:
        # Hata yönetimi kapsamında hata loglanıp güvenli varsayılan değer döndürülür
        print(f"NPK yıkanma algoritmasında hata oluştu: {str(e)}. Varsayılan 0.0 kayıpları döndürülüyor.")
        return default_losses
