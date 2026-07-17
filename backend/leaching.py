import math
from typing import Dict

def calculate_npk_leaching(precipitation_mm: float, net_irrigation_mm: float, soil_type: str) -> Dict[str, float]:
    """
    Simulates N, P, K fertilizer leaching percentages based on soil type and water volume.
    """
    default_losses = {'N_loss_pct': 0.0, 'P_loss_pct': 0.0, 'K_loss_pct': 0.0}
    
    try:
        p_val = float(precipitation_mm)
        i_val = float(net_irrigation_mm)
        
        p_val = max(0.0, p_val)
        i_val = max(0.0, i_val)
        
        total_water = p_val + i_val
        if total_water <= 0.0:
            return default_losses
            
        soil = str(soil_type).strip().lower()
        
        # Soil parameters: S_cap (water holding capacity in mm), f_perc (percolation rate)
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
        
        params = soil_parameters.get(soil, soil_parameters['loam'])
        S_cap = params['S_cap']
        f_perc = params['f_perc']
        
        excess_water = max(0.0, total_water - S_cap)
        percolated_water = excess_water * f_perc
        
        if percolated_water <= 0.0:
            return default_losses
            
        # Element mobility coefficients based on clay content
        if soil in ['sand', 'kum', 'kumlu']:
            alpha_N = 0.080
            alpha_K = 0.030
            alpha_P = 0.005
        elif soil in ['clay', 'kil', 'killi']:
            alpha_N = 0.030
            alpha_K = 0.008
            alpha_P = 0.0005
        else: # loam
            alpha_N = 0.050
            alpha_K = 0.015
            alpha_P = 0.0015
            
        N_loss = 100.0 * (1.0 - math.exp(-alpha_N * percolated_water))
        P_loss = 100.0 * (1.0 - math.exp(-alpha_P * percolated_water))
        K_loss = 100.0 * (1.0 - math.exp(-alpha_K * percolated_water))
        
        return {
            'N_loss_pct': round(max(0.0, min(100.0, N_loss)), 2),
            'P_loss_pct': round(max(0.0, min(100.0, P_loss)), 2),
            'K_loss_pct': round(max(0.0, min(100.0, K_loss)), 2)
        }

    except Exception as e:
        print(f"NPK leaching calculation error: {e}")
        return default_losses
