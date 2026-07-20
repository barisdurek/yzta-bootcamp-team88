import uuid
from datetime import datetime, timedelta, timezone
from collections import Counter
from typing import Optional

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from models import AIRecommendation, AnonymousRiskLog, Field, User


def get_all_risk_logs(db: Session):
    return (
        db.query(AnonymousRiskLog)
        .order_by(AnonymousRiskLog.detected_at.desc())
        .all()
    )


def create_risk_log(db: Session, data: dict):
    risk_log = AnonymousRiskLog(**data)

    db.add(risk_log)
    db.commit()
    db.refresh(risk_log)

    return risk_log


def get_regional_risk_summary(
    db: Session,
    province: Optional[str] = None,
    district: Optional[str] = None,
    crop_name: Optional[str] = None,
    days: int = 14,
) -> dict:
    """
    Belirtilen filtreler ve gün sayısı için bölgesel hastalık risk seviyesini hesaplar.
    """
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=days)

    query = db.query(AnonymousRiskLog).filter(
        AnonymousRiskLog.detected_at >= cutoff_date
    )

    if province:
        query = query.filter(AnonymousRiskLog.province.ilike(f"%{province}%"))
    if district:
        query = query.filter(AnonymousRiskLog.district.ilike(f"%{district}%"))
    if crop_name:
        query = query.filter(AnonymousRiskLog.crop_name.ilike(f"%{crop_name}%"))

    logs = query.all()
    total_cases = len(logs)

    # Vaka sayısına göre risk seviyesi belirleme
    if total_cases == 0:
        risk_level = "Düşük"
    elif total_cases <= 5:
        risk_level = "Orta"
    elif total_cases <= 15:
        risk_level = "Yüksek"
    else:
        risk_level = "Kritik"

    # En çok görülen 3 hastalık ve sayıları
    disease_counts = Counter(
        log.detected_disease for log in logs if log.detected_disease
    )
    top_diseases = [
        {"disease": disease, "count": count}
        for disease, count in disease_counts.most_common(3)
    ]

    return {
        "province": province or "Tüm İller",
        "district": district or "Tüm İlçeler",
        "crop_name": crop_name or "Tüm Ürünler",
        "days_analyzed": days,
        "total_cases": total_cases,
        "risk_level": risk_level,
        "top_diseases": top_diseases,
        "last_updated": datetime.now(timezone.utc).isoformat(),
    }



def get_user_by_email(db: Session, email: str):
    return (
        db.query(User)
        .filter(User.email == email)
        .first()
    )


def create_user(db: Session, data: dict):
    user = User(**data)

    try:
        db.add(user)
        db.commit()
        db.refresh(user)
        return user

    except IntegrityError:
        db.rollback()
        raise ValueError(
            "Bu e-posta adresiyle kayıtlı bir kullanıcı zaten var."
        )


def get_all_fields(db: Session):
    return (
        db.query(Field)
        .order_by(Field.created_at.desc())
        .all()
    )


def get_field_by_id(
    db: Session,
    field_id: uuid.UUID,
):
    return (
        db.query(Field)
        .filter(Field.id == field_id)
        .first()
    )


def create_field(db: Session, data: dict):
    field = Field(**data)

    try:
        db.add(field)
        db.commit()
        db.refresh(field)
        return field

    except IntegrityError as e:
        db.rollback()
        raise ValueError(
            "Tarla oluşturulamadı. user_id veya region_id geçersiz olabilir."
        ) from e


def create_ai_recommendation(
    db: Session,
    data: dict,
):
    recommendation = AIRecommendation(**data)

    try:
        db.add(recommendation)
        db.commit()
        db.refresh(recommendation)
        return recommendation

    except IntegrityError as e:
        db.rollback()
        raise ValueError(
            "AI önerisi kaydedilemedi. field_id, recommendation_type "
            "veya risk_level değeri geçersiz olabilir."
        ) from e


def get_recommendations_by_field_id(
    db: Session,
    field_id: uuid.UUID,
):
    return (
        db.query(AIRecommendation)
        .filter(AIRecommendation.field_id == field_id)
        .order_by(AIRecommendation.created_at.desc())
        .all()
    )