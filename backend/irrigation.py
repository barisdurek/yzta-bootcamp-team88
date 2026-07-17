import math
from typing import Any, Dict

def calculate_optimal_irrigation(weather_data: Dict[str, Any], crop_data: Dict[str, Any]) -> float:
    """
    FAO-56 Penman-Monteith approach simplified to calculate daily crop water requirement (mm or L/m2).
    """
    try:
        T = float(weather_data.get('temperature_c', 
                  weather_data.get('temp_c', 
                  weather_data.get('temp', 20.0))))
        
        RH = float(weather_data.get('humidity_pct', 
                    weather_data.get('humidity', 60.0)))
        RH = max(0.0, min(100.0, RH))
        
        wind = weather_data.get('wind_speed_ms', 
                               weather_data.get('wind_speed', 
                               weather_data.get('wind_kph', None)))
        if wind is None:
            u2 = 2.0
        else:
            wind = float(wind)
            if 'kph' in weather_data or 'kmh' in weather_data or wind > 15.0:
                u2 = wind / 3.6
            else:
                u2 = wind
        u2 = max(0.1, u2)
        
        P = float(weather_data.get('precipitation_mm', 
                   weather_data.get('rain_mm', 
                   weather_data.get('precipitation', 0.0))))
        P = max(0.0, P)
        
        RD = float(crop_data.get('root_depth_m', 
                    crop_data.get('root_depth', 0.5)))
        RD = max(0.1, RD)
        
        Kc = float(crop_data.get('kc', 
                    crop_data.get('crop_coefficient', 0.85)))
        Kc = max(0.1, Kc)

        # Tetens saturation vapor pressure formula (e_s) in kPa
        e_s = 0.6108 * math.exp((17.27 * T) / (T + 237.3))
        
        # Actual vapor pressure (e_a) in kPa
        e_a = e_s * (RH / 100.0)
        
        # Vapor pressure deficit (VPD)
        VPD = max(0.0, e_s - e_a)
        
        # Slope of saturation vapor pressure curve (Delta)
        delta = (4098.0 * e_s) / ((T + 237.3) ** 2)
        
        # Psychrometric constant (gamma)
        gamma = 0.067
        
        # Net Radiation (Rn) estimation
        Rn = 13.5 * (1.0 - (RH / 200.0)) + 0.1 * T
        Rn = max(0.5, Rn)
        
        # FAO-56 Penman-Monteith
        numerator = 0.408 * delta * Rn + gamma * (900.0 / (T + 273.15)) * u2 * VPD
        denominator = delta + gamma * (1.0 + 0.34 * u2)
        ET0 = numerator / denominator
        ET0 = max(0.0, ET0)
        
        # Root Depth efficiency
        lambda_coeff = 3.5
        K_root = 1.0 - math.exp(-lambda_coeff * RD)
        
        ET_crop = ET0 * Kc * K_root
        
        # Effective Precipitation (80% efficiency)
        P_eff = P * 0.80
        
        net_irrigation = ET_crop - P_eff
        return round(max(0.0, net_irrigation), 2)

    except Exception as e:
        print(f"Irrigation calculation error: {e}")
        return 0.0
