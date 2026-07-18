import uuid

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