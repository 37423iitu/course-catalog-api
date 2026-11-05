from sqlalchemy import text
from db import engine

if __name__ == "__main__":
    with engine.connect() as conn:
        name, user = conn.execute(text("SELECT current_database(), current_user")).one()
        version = conn.execute(text("SHOW server_version")).scalar_one()
    print(f"connected to {name} as {user}, PostgreSQL {version}")
