
# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

# Configuración de IDs de Workflows
# Este archivo centraliza los IDs de workflows para facilitar actualizaciones

# BB_00: Global Error Handler (HANDLER REAL)
BB_00_WORKFLOW_ID = "_Za9GzqB2cS9HVwBglt43"
BB_00_WORKFLOW_NAME = "BB_00_Global_Error_Handler"

# Test_BB00: Workflow de prueba para BB_00
TEST_BB00_WORKFLOW_ID = "HzI1o1ZSBLrCType"
TEST_BB00_WORKFLOW_NAME = "Test_BB00"

# BB_02: Security Firewall
BB_02_WORKFLOW_ID = "Rhn_gioVdn3Q3AeiyNPYg"
BB_02_WORKFLOW_NAME = "BB_02_Security_Firewall"
BB_02_WEBHOOK_PATH = "689841d2-b2a8-4329-b118-4e8675a810be"

# URLs de n8n
N8N_LOCAL_URL = "http://localhost:5678"
N8N_PUBLIC_URL = "https://n8n.stax.ink"

# Usar URL pública por defecto, local como fallback
N8N_BASE_URL = N8N_PUBLIC_URL
