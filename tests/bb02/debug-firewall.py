#!/usr/bin/env python3

# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../scripts-py')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

"""
Diagnóstico del problema de firewall - Herramienta de debug
"""

import os
import sys
from datetime import datetime, timedelta, timezone

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("❌ pip install psycopg2-binary")
    sys.exit(1)

DB_CONFIG = {
    "host": "ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech",
    "port": 5432,
    "database": "neondb",
    "user": "neondb_owner",
    "password": os.getenv("PGPASSWORD", ""),
    "sslmode": "require"
}

class C:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    RESET = '\033[0m'

def main():
    try:
        conn = psycopg2.connect(**DB_CONFIG)
    except Exception as e:
        print(f"{C.RED}❌ Error conectando a PostgreSQL: {e}{C.RESET}")
        return 1
    
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    print(f"\n{C.BOLD}{C.BLUE}{'='*70}")
    print("DIAGNÓSTICO DE FIREWALL".center(70))
    print(f"{'='*70}{C.RESET}")
    
    # 1. Ver todos los usuarios de prueba
    print(f"\n{C.CYAN}📋 Usuarios de prueba en BD:{C.RESET}")
    cur.execute("""
        SELECT id, telegram_id, first_name, role, deleted_at 
        FROM users 
        WHERE telegram_id >= 800800800 AND telegram_id <= 800800899
        ORDER BY telegram_id
    """)
    users = cur.fetchall()
    if users:
        for u in users:
            status = f"{C.RED}[BANNED]{C.RESET}" if u['deleted_at'] else f"{C.GREEN}[ACTIVE]{C.RESET}"
            print(f"  {u['telegram_id']}: {u['first_name']} ({u['role']}) {status}")
    else:
        print(f"  {C.YELLOW}No hay usuarios de prueba{C.RESET}")
    
    # 2. Ver todas las entradas de firewall
    print(f"\n{C.CYAN}📋 Entradas de firewall:{C.RESET}")
    cur.execute("""
        SELECT entity_id, is_blocked, blocked_until, strike_count
        FROM security_firewall 
        WHERE entity_id LIKE 'telegram:800800%'
        ORDER BY entity_id
    """)
    firewall = cur.fetchall()
    if firewall:
        for f in firewall:
            blocked_str = ""
            if f['is_blocked']:
                if f['blocked_until']:
                    if f['blocked_until'] > datetime.now(timezone.utc):
                        blocked_str = f"{C.RED}[BLOCKED until {f['blocked_until']}]{C.RESET}"
                    else:
                        blocked_str = f"{C.YELLOW}[EXPIRED]{C.RESET}"
                else:
                    blocked_str = f"{C.RED}[BLOCKED INDEFINITELY]{C.RESET}"
            else:
                blocked_str = f"{C.GREEN}[NOT BLOCKED]{C.RESET}"
            
            print(f"  {f['entity_id']}: strikes={f['strike_count']} {blocked_str}")
    else:
        print(f"  {C.YELLOW}No hay entradas de firewall{C.RESET}")
    
    # 3. Verificar tiempo del servidor
    print(f"\n{C.CYAN}📋 Tiempo del servidor:{C.RESET}")
    cur.execute("SELECT NOW() as server_time, NOW() AT TIME ZONE 'UTC' as utc_time")
    times = cur.fetchone()
    print(f"  Server time: {times['server_time']}")
    print(f"  UTC time:    {times['utc_time']}")
    print(f"  Local time:  {datetime.now()}")
    print(f"  Local UTC:   {datetime.now(timezone.utc)}")
    
    # 4. Menú de acciones
    print(f"\n{C.BOLD}{C.BLUE}{'='*70}")
    print("ACCIONES DISPONIBLES".center(70))
    print(f"{'='*70}{C.RESET}")
    print("""
    1. Crear usuario bloqueado de prueba
    2. Crear usuario baneado de prueba
    3. Limpiar todos los datos de prueba
    4. Ejecutar query de diagnóstico
    5. Salir
    """)
    
    try:
        choice = input(f"{C.CYAN}Selecciona una opción (1-5): {C.RESET}").strip()
        
        if choice == "1":
            # Crear usuario bloqueado
            tid = 800800899
            cur.execute("DELETE FROM security_firewall WHERE entity_id = %s", (f"telegram:{tid}",))
            cur.execute("DELETE FROM users WHERE telegram_id = %s", (tid,))
            cur.execute("""
                INSERT INTO users (telegram_id, first_name, role)
                VALUES (%s, 'Debug Blocked User', 'user')
            """, (tid,))
            blocked_until = datetime.now(timezone.utc) + timedelta(hours=2)
            cur.execute("""
                INSERT INTO security_firewall (entity_id, is_blocked, blocked_until, strike_count)
                VALUES (%s, true, %s, 5)
            """, (f"telegram:{tid}", blocked_until))
            conn.commit()
            print(f"\n{C.GREEN}✓ Usuario bloqueado creado: telegram_id={tid}{C.RESET}")
            print(f"  Blocked until: {blocked_until}")
            print(f"\n  Prueba con:")
            print(f'  curl -X POST https://n8n.stax.ink/webhook/689841d2-b2a8-4329-b118-4e8675a810be -H "Content-Type: application/json" -d \'{{"user": {{"telegram_id": {tid}}}}}\'')
            
        elif choice == "2":
            # Crear usuario baneado
            tid = 800800898
            cur.execute("DELETE FROM users WHERE telegram_id = %s", (tid,))
            cur.execute("""
                INSERT INTO users (telegram_id, first_name, role, deleted_at)
                VALUES (%s, 'Debug Banned User', 'user', NOW())
            """, (tid,))
            conn.commit()
            print(f"\n{C.GREEN}✓ Usuario baneado creado: telegram_id={tid}{C.RESET}")
            print(f"\n  Prueba con:")
            print(f'  curl -X POST https://n8n.stax.ink/webhook/689841d2-b2a8-4329-b118-4e8675a810be -H "Content-Type: application/json" -d \'{{"user": {{"telegram_id": {tid}}}}}\'')
            
        elif choice == "3":
            # Limpiar todo
            cur.execute("DELETE FROM security_firewall WHERE entity_id LIKE 'telegram:800800%' OR entity_id LIKE 'telegram:999999%'")
            cur.execute("DELETE FROM users WHERE telegram_id >= 800800800 AND telegram_id <= 800800899")
            cur.execute("DELETE FROM users WHERE telegram_id >= 999999900 AND telegram_id <= 999999999")
            conn.commit()
            print(f"\n{C.GREEN}✓ Todos los datos de prueba eliminados{C.RESET}")
            
        elif choice == "4":
            # Query de diagnóstico
            tid = input(f"{C.CYAN}Ingresa telegram_id a consultar: {C.RESET}").strip()
            cur.execute("""
                SELECT 
                  u.id as user_id,
                  u.telegram_id,
                  u.deleted_at,
                  sf.is_blocked,
                  sf.blocked_until,
                  sf.strike_count,
                  NOW() as current_time,
                  CASE 
                    WHEN sf.is_blocked = true THEN 
                      CASE 
                        WHEN sf.blocked_until IS NULL THEN true
                        WHEN sf.blocked_until > NOW() THEN true
                        ELSE false
                      END
                    ELSE false
                  END as is_currently_blocked,
                  CASE WHEN u.deleted_at IS NOT NULL THEN true ELSE false END as is_banned,
                  CASE WHEN u.id IS NOT NULL THEN true ELSE false END as user_exists
                FROM (SELECT %s::text as tid) as input
                LEFT JOIN users u ON u.telegram_id::text = input.tid
                LEFT JOIN security_firewall sf ON sf.entity_id = 'telegram:' || input.tid
            """, (tid,))
            result = cur.fetchone()
            print(f"\n{C.CYAN}Resultado:{C.RESET}")
            for key, value in dict(result).items():
                print(f"  {key}: {value}")
                
        elif choice == "5":
            pass
        else:
            print(f"{C.YELLOW}Opción no válida{C.RESET}")
            
    except KeyboardInterrupt:
        print("\n")
    
    cur.close()
    conn.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())