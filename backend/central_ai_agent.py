import uuid
from leaching import calculate_npk_leaching
from datetime import datetime, timezone
from typing import Any, Dict

from sqlalchemy.orm import Session

import crud
from ai_agent import generate_proactive_recommendation
from crop_service import get_crop_info
from weather_service import get_weather_forecast_by_coordinates
from irrigation import calculate_optimal_irrigation


class CentralAIAgent:
    """
    Tarla Gözcüsü Merkezi AI Agent.

    Sorumlulukları
    ----------------
    - PostgreSQL'den tarla bilgisini almak
    - PostgreSQL'den en güncel sensör kaydını almak
    - Weather API'den hava tahminini almak
    - Crop Service'den mahsul bilgilerini almak
    - Tüm verileri tek AI context'i altında toplamak
    - Gemini'ye göndermek
    """

    def __init__(self, db: Session):
        self.db = db

    def run(
        self,
        field_id: str,
        source_data: Dict[str, Any] | None = None,
    ) -> Dict[str, Any]:
        """
        Merkezi AI Agent akışını çalıştırır.
        """

        source_data = source_data or {}

        try:
            field_uuid = uuid.UUID(str(field_id))

        except ValueError as exc:
            raise ValueError(
                "field_id geçerli bir UUID olmalıdır."
            ) from exc

        field = crud.get_field_by_id(
            db=self.db,
            field_id=field_uuid,
        )

        if field is None:
            raise ValueError(
                "Belirtilen field_id için tarla bulunamadı."
            )

        context = self.build_context(
            field=field,
            source_data=source_data,
        )

        print("\n===== AI CONTEXT =====")
        print(context)
        print("======================\n")

        irrigation = context.get("irrigation_analysis", {})
        leaching = context.get("leaching_analysis", {})

        context["ai_summary"] = {
            "irrigation": {
                "daily_water_need_mm": irrigation.get("daily_water_need_mm"),
                "daily_water_need_l_per_m2": irrigation.get("daily_water_need_l_per_m2"),
                "field_area_m2": irrigation.get("field_area_m2"),
                "total_water_need_liters": irrigation.get("total_water_need_liters"),
                "irrigation_required": irrigation.get("irrigation_required"),
            },
            "leaching": {
                "N_loss_pct": leaching.get("N_loss_pct"),
                "P_loss_pct": leaching.get("P_loss_pct"),
                "K_loss_pct": leaching.get("K_loss_pct"),
         }
        }

        recommendation_text = (
            generate_proactive_recommendation(
                context
            )
        )

        return {
            "context": context,
            "recommendation_text": recommendation_text,
        }

    def build_context(
        self,
        field: Any,
        source_data: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        AI modeline gönderilecek merkezi context'i oluşturur.
        """

        weather_forecast = self._get_weather_forecast(
            field=field,
            source_data=source_data,
        )

        crop_db_info = self._get_crop_db_info(
            source_data=source_data,
        )

        sensor_records = (
            self._get_latest_sensor_record(
                field=field,
            )
        )
        irrigation_analysis = self._calculate_irrigation_analysis(
            field=field,
            weather_forecast=weather_forecast,
            crop_db_info=crop_db_info,
            sensor_records=sensor_records,
        )

        leaching_analysis = self._calculate_leaching_analysis(
            field=field,
            weather_forecast=weather_forecast,
            irrigation_analysis=irrigation_analysis,
        )

        return {
            "current_time": datetime.now(
                timezone.utc
            ).isoformat(),

            "user_info": source_data.get(
                "user_info",
                {},
            ),

            "field_info": self._build_field_info(
                field
            ),

            "crop_db_info": crop_db_info,

            "farmer_history": source_data.get(
                "farmer_history",
                [],
            ),

            # Sensör verisi artık request'ten değil,
            # doğrudan PostgreSQL'den alınır.
            "sensor_records": sensor_records,

            "weather_forecast": weather_forecast,

            "irrigation_analysis": irrigation_analysis,

            "leaching_analysis": leaching_analysis,

            "cnn_disease_result": source_data.get(
                "cnn_disease_result",
                {},
            ),
        }

    def _get_crop_db_info(
        self,
        source_data: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Crop Service üzerinden mahsul bilgilerini getirir.
        """

        crop_name = source_data.get(
            "crop_name"
        )

        # Eski istek formatıyla geriye dönük uyumluluk
        if not crop_name:
            request_crop = source_data.get(
                "crop_db_info",
                {},
            )

            if isinstance(request_crop, dict):
                crop_name = request_crop.get(
                    "crop_name"
                )

        crop_info = get_crop_info(
            crop_name
        )

        if crop_info:
            return crop_info

        if crop_name:
            return {
                "crop_name": crop_name,
                "data_status": "not_found",
                "message": (
                    "Bu mahsul için kayıtlı "
                    "bilgi bulunamadı."
                ),
            }

        return {
            "data_status": "missing",
            "message": (
                "Mahsul bilgisi gönderilmedi."
            ),
        }

    def _get_weather_forecast(
        self,
        field: Any,
        source_data: Dict[str, Any],
    ) -> Any:
        """
        Tarla koordinatlarından hava tahmini alır.
        """

        try:
            latitude = float(
                field.latitude
            )

            longitude = float(
                field.longitude
            )

            return (
                get_weather_forecast_by_coordinates(
                    latitude,
                    longitude,
                )
            )

        except Exception as exc:
            print(
                "WARNING: Weather API başarısız. "
                f"({exc})"
            )

            # Weather API başarısız olursa eski request
            # formatından gelen veri kullanılabilir.
            return source_data.get(
                "weather_forecast",
                [],
            )

    def _calculate_irrigation_analysis(
        self,
        field: Any,
        weather_forecast: Any,
        crop_db_info: Dict[str, Any],
        sensor_records: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Hava durumu, mahsul ve sensör verilerine göre
        günlük sulama ihtiyacını hesaplar.
       """

        if not weather_forecast:
            return {
                "data_status": "missing",
                "message": "Sulama hesabı için hava tahmini bulunamadı.",
            }

        first_day_weather = (
            weather_forecast[0]
            if isinstance(weather_forecast, list)
            else weather_forecast
       )

        if not isinstance(first_day_weather, dict):
            return {
                "data_status": "invalid",
                "message": "Hava tahmini beklenen formatta değil.",
           }

        irrigation_mm = calculate_optimal_irrigation(
            weather_data=first_day_weather,
            crop_data=crop_db_info,
        )

        area_m2 = (
            float(field.area_m2)
            if field.area_m2 is not None
            else None
       )

        total_water_liters = (
            round(irrigation_mm * area_m2, 2)
            if area_m2 is not None
            else None
       )

        soil_moisture = sensor_records.get(
            "soil_moisture_pct"
       )

        irrigation_required = irrigation_mm > 0

        if soil_moisture is not None:
            optimum_range = crop_db_info.get(
                "optimum_moisture_range_pct"
           )

            if isinstance(optimum_range, str) and "-" in optimum_range:
                try:
                    minimum_moisture = float(
                        optimum_range.split("-")[0]
                   )

                    irrigation_required = (
                        irrigation_mm > 0
                        and soil_moisture < minimum_moisture
                   )

                except ValueError:
                    pass

        return {
            "daily_water_need_mm": irrigation_mm,
            "daily_water_need_l_per_m2": irrigation_mm,
            "field_area_m2": area_m2,
            "total_water_need_liters": total_water_liters,
            "irrigation_required": irrigation_required,
            "soil_moisture_pct": soil_moisture,
        }
    
    def _calculate_leaching_analysis(
        self,
        field: Any,
        weather_forecast: Any,
        irrigation_analysis: Dict[str, Any],
    ) -> Dict[str, Any]:

        if not weather_forecast:
            return {}

        first_day = (
             weather_forecast[0]
            if isinstance(weather_forecast, list)
            else weather_forecast
       )

        precipitation = first_day.get("precipitation_mm", 0)

        irrigation_mm = irrigation_analysis.get(
            "daily_water_need_mm",
            0,
       )

        soil_type = field.soil_type or "Loam"

        return calculate_npk_leaching(
            precipitation_mm=precipitation,
            net_irrigation_mm=irrigation_mm,
            soil_type=soil_type,
      )

    def _get_latest_sensor_record(
        self,
        field: Any,
    ) -> Dict[str, Any]:
        """
        PostgreSQL'den tarlaya ait en güncel
        sensör kaydını getirir.
        """

        sensor = crud.get_latest_sensor_record(
            db=self.db,
            field_id=field.id,
        )

        if sensor is None:
            return {
                "data_status": "missing",
                "message": (
                    "Bu tarlaya ait sensör "
                    "kaydı bulunamadı."
                ),
            }

        return {
            "sensor_record_id": str(
                sensor.id
            ),

            "field_id": str(
                sensor.field_id
            ),

            "soil_moisture_pct": (
                float(sensor.soil_moisture_pct)
                if sensor.soil_moisture_pct
                is not None
                else None
            ),

            "soil_temp_c": (
                float(sensor.soil_temp_c)
                if sensor.soil_temp_c
                is not None
                else None
            ),

            "air_temp_c": (
                float(sensor.air_temp_c)
                if sensor.air_temp_c
                is not None
                else None
            ),

            "air_humidity_pct": (
                float(sensor.air_humidity_pct)
                if sensor.air_humidity_pct
                is not None
                else None
            ),

            "ph": (
                float(sensor.ph)
                if sensor.ph is not None
                else None
            ),

            "ec": (
                float(sensor.ec)
                if sensor.ec is not None
                else None
            ),

            "recorded_at": (
                sensor.recorded_at.isoformat()
                if sensor.recorded_at
                is not None
                else None
            ),

            "created_at": (
                sensor.created_at.isoformat()
                if sensor.created_at
                is not None
                else None
            ),
        }

    @staticmethod
    def _build_field_info(
        field: Any,
    ) -> Dict[str, Any]:
        """
        SQLAlchemy Field nesnesini JSON uyumlu
        dictionary formatına dönüştürür.
        """

        return {
            "field_id": str(
                field.id
            ),

            "user_id": str(
                field.user_id
            ),

            "region_id": (
                str(field.region_id)
                if field.region_id
                else None
            ),

            "field_name": field.field_name,

            "province": field.province,

            "district": field.district,

            "latitude": (
                float(field.latitude)
                if field.latitude
                is not None
                else None
            ),

            "longitude": (
                float(field.longitude)
                if field.longitude
                is not None
                else None
            ),

            "area_m2": (
                float(field.area_m2)
                if field.area_m2
                is not None
                else None
            ),

            "soil_type": field.soil_type,

            "irrigation_type": (
                field.irrigation_type
            ),
        }