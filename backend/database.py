import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/tarla_gozcusu")

try:
    if DATABASE_URL.startswith("sqlite"):
        engine = create_engine(
            DATABASE_URL,
            connect_args={"check_same_thread": False},
        )
    else:
        engine = create_engine(
            DATABASE_URL,
            pool_pre_ping=True,
        )
except Exception as e:
    print(f"WARNING: Database engine creation error: {e}")
    engine = None

if engine:
    SessionLocal = sessionmaker(
        bind=engine,
        autocommit=False,
        autoflush=False,
    )
else:
    SessionLocal = None


class Base(DeclarativeBase):
    pass


def get_db():
    if not SessionLocal:
        yield None
        return
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_database_connection():
    if not engine:
        raise Exception("Database engine is not initialized.")
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))