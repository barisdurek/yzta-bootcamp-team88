import uuid

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from models import (
    AIRecommendation,
    AnonymousRiskLog,
    Field,
    SensorRecord,
    User,
)


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

    except IntegrityError as exc:
        db.rollback()

        raise ValueError(
            "Tarla oluşturulamadı. "
            "user_id veya region_id geçersiz olabilir."
        ) from exc


def create_sensor_record(
    db: Session,
    data: dict,
):
    """
    Yeni sensör ölçümünü PostgreSQL'e kaydeder.
    """

    field_id = data.get("field_id")

    if not field_id:
        raise ValueError(
            "Sensör kaydı için field_id zorunludur."
        )

    try:
        field_uuid = (
            field_id
            if isinstance(field_id, uuid.UUID)
            else uuid.UUID(str(field_id))
        )
    except ValueError as exc:
        raise ValueError(
            "field_id geçerli bir UUID olmalıdır."
        ) from exc

    field = get_field_by_id(
        db=db,
        field_id=field_uuid,
    )

    if field is None:
        raise ValueError(
            "Sensör kaydı oluşturulamadı. "
            "Belirtilen field_id için tarla bulunamadı."
        )

    sensor_data = {
        **data,
        "field_id": field_uuid,
    }

    sensor_record = SensorRecord(**sensor_data)

    try:
        db.add(sensor_record)
        db.commit()
        db.refresh(sensor_record)

        return sensor_record

    except IntegrityError as exc:
        db.rollback()

        raise ValueError(
            "Sensör kaydı oluşturulamadı. "
            "Gönderilen değerleri kontrol edin."
        ) from exc


def get_latest_sensor_record(
    db: Session,
    field_id: uuid.UUID,
):
    return (
        db.query(SensorRecord)
        .filter(SensorRecord.field_id == field_id)
        .order_by(
            SensorRecord.recorded_at.desc().nullslast(),
            SensorRecord.created_at.desc(),
        )
        .first()
    )


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

    except IntegrityError as exc:
        db.rollback()

        raise ValueError(
            "AI önerisi kaydedilemedi. field_id, recommendation_type "
            "veya risk_level değeri geçersiz olabilir."
        ) from exc


def get_recommendations_by_field_id(
    db: Session,
    field_id: uuid.UUID,
):
    return (
        db.query(AIRecommendation)
        .filter(
            AIRecommendation.field_id == field_id
        )
        .order_by(
            AIRecommendation.created_at.desc()
        )
        .all()
    )