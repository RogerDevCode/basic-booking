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
Diagnóstico completo de notificaciones BB_00
"""

import os
import sys
import json

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("❌ pip install psycopg2-binary")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("❌ pip install requests")
    sys.exit(1)

DB_CONFIG = {
    "host": "ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech",
    "port": 5432,
    "database": "neondb",
    "user": "neondb_owner",
    "password": os.getenv("PGPASSWORD", ""),
    "sslmode": "require"
}

N8N_BASE_URL = "https://n8n.stax.ink"

class C:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    RESET = '\033[0m'

def header(t):
    print(f"\n{C.BOLD}{C.BLUE}{'='*70}\n{t.center(70)}\n{'='*70}{C.RESET}\n")

def ok(m): print(f"  {C.GREEN}✓ {m}{C.RESET}")
def fail(m): print(f"  {C.RED}✗ {m}{C.RESET}")
def warn(m): print(f"  {C.YELLOW}⚠ {m}{C.RESET}")
def info(m): print(f"  {C.CYAN}ℹ {m}{C.RESET}")

def main():
    header("DIAGNÓSTICO DE NOTIFICACIONES BB_00")
    
    # Conectar a BD
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        cur = conn.cursor(cursor_factory=RealDictCursor)
        ok("Conectado a PostgreSQL")
    except Exception as e:
        fail(f"No se pudo conectar a PostgreSQL: {e}")
        return 1
    
    issues = []
    
    # ============================================
    # 1. Verificar app_config
    # ============================================
    print(f"\n{C.CYAN}📋 1. Configuración en app_config:{C.RESET}")
    
    cur.execute("""
        SELECT key, value, category, type 
        FROM app_config 
        WHERE key IN (
            'ADMIN_TELEGRAM_CHAT_ID',
            'BB_00_WORKFLOW_ID',
            'TELEGRAM_BOT_TOKEN',
            'BB_DEFAULT_ADMIN_CHAT_ID'
        )
    """)
    configs = cur.fetchall()
    
    config_map = {c['key']: c['value'] for c in configs}
    
    # Verificar ADMIN_TELEGRAM_CHAT_ID
    if 'ADMIN_TELEGRAM_CHAT_ID' in config_map:
        ok(f"ADMIN_TELEGRAM_CHAT_ID: {config_map['ADMIN_TELEGRAM_CHAT_ID']}")
    else:
        fail("ADMIN_TELEGRAM_CHAT_ID no configurado!")
        issues.append("ADMIN_TELEGRAM_CHAT_ID")
    
    # Verificar BB_00_WORKFLOW_ID
    if 'BB_00_WORKFLOW_ID' in config_map:
        ok(f"BB_00_WORKFLOW_ID: {config_map['BB_00_WORKFLOW_ID']}")
    else:
        warn("BB_00_WORKFLOW_ID no configurado (BB_02 no podrá llamar a BB_00)")
        warn("ID correcto de BB_00_Global_Error_Handler: _Za9GzqB2cS9HVwBglt43")
        warn("ID de Test_BB00 (workflow de prueba): HzI1o1ZSBLrCType")
        issues.append("BB_00_WORKFLOW_ID")
    
    # ============================================
    # 2. Verificar tabla system_errors
    # ============================================
    print(f"\n{C.CYAN}📋 2. Tabla system_errors:{C.RESET}")
    
    cur.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_name = 'system_errors'
        ) as exists
    """)
    table_exists = cur.fetchone()['exists']
    
    if table_exists:
        ok("Tabla system_errors existe")
        
        # Ver últimos errores
        cur.execute("""
            SELECT workflow_name, severity, error_type, 
                   LEFT(error_message, 50) as message_preview,
                   created_at
            FROM system_errors 
            ORDER BY created_at DESC 
            LIMIT 5
        """)
        errors = cur.fetchall()
        
        if errors:
            info(f"Últimos {len(errors)} errores registrados:")
            for e in errors:
                print(f"      {e['created_at']} | {e['severity']} | {e['workflow_name']} | {e['message_preview']}...")
        else:
            info("No hay errores registrados aún")
    else:
        fail("Tabla system_errors NO existe!")
        issues.append("system_errors table")
        print(f"\n  {C.YELLOW}Ejecuta esto para crearla:{C.RESET}")
        print("""
    CREATE TABLE public.system_errors (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      workflow_name VARCHAR(255),
      workflow_execution_id VARCHAR(255),
      error_type VARCHAR(100),
      severity VARCHAR(20),
      error_message TEXT,
      error_stack JSONB,
      error_context JSONB,
      user_id UUID,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
        """)
    
    # ============================================
    # 3. Verificar credenciales de Telegram en N8N
    # ============================================
    print(f"\n{C.CYAN}📋 3. Credenciales de Telegram:{C.RESET}")
    info("Las credenciales están en N8N (Telegram Booking)")
    info("Verifica que el Bot Token sea válido")
    
    # ============================================
    # 4. Verificar variables de entorno en N8N
    # ============================================
    print(f"\n{C.CYAN}📋 4. Variables de entorno requeridas:{C.RESET}")
    print("""
    En N8N, verifica que estén configuradas:
    - BB_DEFAULT_ADMIN_CHAT_ID (tu chat ID de Telegram)
    - BB_ERROR_RATE_LIMIT (default: 10)
    - N8N_BASE_URL (URL de tu instancia N8N)
    """)
    
    # ============================================
    # 5. Obtener ID del workflow BB_00
    # ============================================
    print(f"\n{C.CYAN}📋 5. ID del Workflow BB_00:{C.RESET}")
    info("Abre BB_00 en N8N y copia el ID de la URL")
    info("URL format: https://n8n.stax.ink/workflow/XXXXX")
    
    # ============================================
    # 6. Test de notificación
    # ============================================
    print(f"\n{C.CYAN}📋 6. ¿Quieres hacer un test de notificación?{C.RESET}")
    
    try:
        choice = input(f"\n  {C.YELLOW}Presiona 'y' para probar o cualquier otra tecla para salir: {C.RESET}").strip().lower()
        
        if choice == 'y':
            # Primero necesitamos el ID del workflow BB_00
            bb00_id = config_map.get('BB_00_WORKFLOW_ID', '')
            
            if not bb00_id:
                bb00_id = input(f"  {C.YELLOW}Ingresa el ID del workflow BB_00: {C.RESET}").strip()
            
            if bb00_id:
                print(f"\n  {C.CYAN}Enviando test a BB_00...{C.RESET}")
                
                # Llamar a BB_00 directamente via webhook o execute workflow
                # Opción 1: Si BB_00 tiene un webhook (no lo tiene por defecto)
                # Opción 2: Llamar via BB_02 que dispara un error
                
                print(f"\n  Para probar, ejecuta este comando:")
                print(f"""
  curl -X POST {N8N_BASE_URL}/webhook/689841d2-b2a8-4329-b118-4e8675a810be \\
    -H "Content-Type: application/json" \\
    -d '{{"user": {{"telegram_id": "invalid_to_trigger_error"}}}}'
                """)
                
                print(f"\n  O dispara un error manualmente en cualquier workflow configurado con BB_00")
            else:
                warn("No se proporcionó ID de BB_00")
                
    except KeyboardInterrupt:
        print("\n")
    
    # ============================================
    # RESUMEN
    # ============================================
    header("RESUMEN")
    
    if issues:
        print(f"  {C.RED}Problemas encontrados:{C.RESET}")
        for issue in issues:
            print(f"    ❌ {issue}")
        
        print(f"\n  {C.YELLOW}Soluciones:{C.RESET}")
        
        if "ADMIN_TELEGRAM_CHAT_ID" in issues:
            print("""
    -- Configurar ADMIN_TELEGRAM_CHAT_ID:
    INSERT INTO app_config (key, value, type, category, is_public)
    VALUES ('ADMIN_TELEGRAM_CHAT_ID', 'TU_CHAT_ID', 'string', 'notifications', false)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
            """)
        
        if "BB_00_WORKFLOW_ID" in issues:
            print("""
    -- Configurar BB_00_WORKFLOW_ID:
    -- 1. Abre BB_00 en N8N
    -- 2. Copia el ID de la URL
    -- 3. Ejecuta:
    INSERT INTO app_config (key, value, type, category, is_public)
    VALUES ('BB_00_WORKFLOW_ID', 'ID_DEL_WORKFLOW', 'string', 'workflows', true)
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
            """)
    else:
        print(f"  {C.GREEN}✅ Configuración básica parece correcta{C.RESET}")
        print(f"\n  Si aún no recibes notificaciones, verifica:")
        print("    1. El Bot Token de Telegram es válido")
        print("    2. El Bot tiene permisos para enviar mensajes")
        print("    3. Has iniciado una conversación con el bot")
        print("    4. El workflow BB_00 está ACTIVO")
    
    cur.close()
    conn.close()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())