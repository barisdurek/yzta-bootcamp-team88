from copy import deepcopy
from typing import Any, Dict


CROP_DATABASE: Dict[str, Dict[str, Any]] = {
    "domates": {
        "crop_name": "Domates",
        "optimum_temp_range": "20-30",
        "optimum_moisture_range_pct": "40-60",
        "preferred_soil_types": [
            "Tınlı",
            "Kumlu tınlı",
        ],
        "irrigation_notes": (
            "Toprak nemi dengeli tutulmalı, "
            "aşırı sulamadan kaçınılmalıdır."
        ),
        "general_notes": (
            "Yüksek sıcaklık ve düşük nem koşullarında "
            "bitki su stresi açısından takip edilmelidir."
        ),
    },

    "biber": {
        "crop_name": "Biber",
        "optimum_temp_range": "20-30",
        "optimum_moisture_range_pct": "45-65",
        "preferred_soil_types": [
            "Tınlı",
            "Kumlu tınlı",
        ],
        "irrigation_notes": (
            "Düzenli ve kontrollü sulama yapılmalı, "
            "ani nem değişimlerinden kaçınılmalıdır."
        ),
        "general_notes": (
            "Çiçeklenme ve meyve tutumu döneminde "
            "su stresi verimi azaltabilir."
        ),
    },

    "buğday": {
        "crop_name": "Buğday",
        "optimum_temp_range": "15-25",
        "optimum_moisture_range_pct": "35-55",
        "preferred_soil_types": [
            "Tınlı",
            "Killi tınlı",
        ],
        "irrigation_notes": (
            "Sulama miktarı gelişim evresine ve "
            "yağış durumuna göre ayarlanmalıdır."
        ),
        "general_notes": (
            "Kardeşlenme, sapa kalkma ve başaklanma "
            "dönemleri yakından takip edilmelidir."
        ),
    },

    "mısır": {
        "crop_name": "Mısır",
        "optimum_temp_range": "20-32",
        "optimum_moisture_range_pct": "45-65",
        "preferred_soil_types": [
            "Tınlı",
            "Killi tınlı",
        ],
        "irrigation_notes": (
            "Özellikle püsküllenme ve dane doldurma "
            "döneminde su eksikliği önlenmelidir."
        ),
        "general_notes": (
            "Yüksek sıcaklık dönemlerinde toprak nemi "
            "daha sık kontrol edilmelidir."
        ),
    },
}


def normalize_crop_name(crop_name: str) -> str:
    """
    Mahsul adını arama için standart formata dönüştürür.

    Örnek:
    " Domates " -> "domates"
    """
    return crop_name.strip().casefold()


def get_crop_info(
    crop_name: str | None,
) -> Dict[str, Any]:
    """
    Mahsul adına göre tarımsal referans bilgisini getirir.

    Mahsul adı yoksa veya kayıt bulunamazsa boş sözlük döndürür.
    Bilinmeyen mahsuller için veri üretmez.
    """
    if not crop_name:
        return {}

    normalized_name = normalize_crop_name(crop_name)

    crop_info = CROP_DATABASE.get(normalized_name)

    if crop_info is None:
        return {}

    return deepcopy(crop_info)