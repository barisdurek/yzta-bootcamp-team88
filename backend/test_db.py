from database import engine
from sqlalchemy import text

with engine.connect() as conn:
    result = conn.execute(text("""
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_name = 'anonymous_risk_logs'
        ORDER BY ordinal_position;
    """))

    print("anonymous_risk_logs tablosu:")
    print("-" * 40)

    for row in result:
        print(row)