#!/usr/bin/env python3
"""
Seed Data Runner - Ejecuta scripts SQL en orden en Neon DB
Uso: python run_seeds.py

Variables de entorno requeridas:
  DATABASE_URL=postgresql://user:pass@host/db?sslmode=require
"""

import os
import sys
import psycopg2
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent / "database" / "seeds"

SEED_SCRIPTS = [
    "01_users.sql",
    "02_providers.sql",
    "03_services.sql",
    "04_schedules.sql",
    "05_bookings.sql",
    "06_firewall.sql",
    "07_notifications.sql",
    "08_circuit_breaker.sql",
    "09_system_errors.sql",
    "10_audit_logs.sql",
    "11_verify.sql",
]


def get_connection():
    db_url = (
        os.getenv("DATABASE_URL") or os.getenv("DB_URL") or os.getenv("NEON_DB_URL")
    )

    if not db_url:
        print("Error: No se encontró DATABASE_URL")
        print("\nOpciones:")
        print("  export DATABASE_URL='postgresql://user:pass@host/db?sslmode=require'")
        print("\nEjemplo Neon:")
        print(
            "  export DATABASE_URL='postgresql://user:pass@ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require'"
        )
        sys.exit(1)

    return psycopg2.connect(db_url)


def run_script(conn, script_name):
    script_path = SCRIPTS_DIR / script_name

    if not script_path.exists():
        print(f"  [SKIP] {script_name} - archivo no encontrado")
        return False

    sql = script_path.read_text()

    try:
        with conn.cursor() as cur:
            cur.execute(sql)
        conn.commit()
        print(f"  [OK] {script_name}")
        return True
    except Exception as e:
        conn.rollback()
        print(f"  [ERROR] {script_name}")
        print(f"         {str(e)[:200]}")
        return False


def main():
    print("=" * 60)
    print("SEED DATA RUNNER - BasicBooking")
    print("=" * 60)

    print("\nConectando a la base de datos...")
    try:
        conn = get_connection()
        print("  [OK] Conexión exitosa\n")
    except Exception as e:
        print(f"  [ERROR] {e}")
        sys.exit(1)

    print("Ejecutando scripts de seed data:\n")

    success_count = 0
    for script in SEED_SCRIPTS:
        if run_script(conn, script):
            success_count += 1

    conn.close()

    print("\n" + "=" * 60)
    print(f"Completado: {success_count}/{len(SEED_SCRIPTS)} scripts exitosos")
    print("=" * 60)


if __name__ == "__main__":
    main()
