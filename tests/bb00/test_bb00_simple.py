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
Test Simple de BB_00 - Versión Python
Verifica el estado de BB_00 sin ejecutar tests (equivalente al script bash)
"""

import sys
import os

# Agregar directorio scripts-py al path
scripts_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../scripts-py'))
if scripts_dir not in sys.path:
    sys.path.append(scripts_dir)

from workflow_config import BB_00_WORKFLOW_ID, BB_00_WORKFLOW_NAME, N8N_LOCAL_URL
from test_helpers import (
    print_header, print_step,
    print_success, print_error, print_info,
    init_agent, verify_workflow_exists, count_executions
)


def run_simple_test():
    """
    Test simple que verifica el estado de BB_00
    No ejecuta ningún test, solo verifica configuración
    """
    
    print_header("Test Simple: BB_00 Status Check")
    
    # Step 1: Conectar
    print_step(1, 3, "Conectando a n8n")
    agent = init_agent(N8N_LOCAL_URL)
    if not agent:
        return False
    
    # Step 2: Verificar BB_00
    print()
    print_step(2, 3, "Verificando BB_00_Global_Error_Handler")
    bb00 = verify_workflow_exists(agent, BB_00_WORKFLOW_ID, BB_00_WORKFLOW_NAME)
    if not bb00:
        return False
    
    # Step 3: Contar ejecuciones
    print()
    print_step(3, 3, "Contando ejecuciones")
    exec_count = count_executions(agent, BB_00_WORKFLOW_ID, limit=50)
    print_info(f"Total de ejecuciones encontradas: {exec_count}", indent=1)
    
    # Resultado
    print()
    if bb00.get('active'):
        print_success("✅ BB_00 está configurado correctamente y activo")
        return True
    else:
        print_error("⚠️  BB_00 existe pero está INACTIVO")
        print_info("Actívalo desde n8n UI o con: python3 -c \"from n8n_crud_agent import N8NCrudAgent; N8NCrudAgent('http://localhost:5678').activate_workflow('_Za9GzqB2cS9HVwBglt43')\"", indent=1)
        return False


if __name__ == "__main__":
    try:
        success = run_simple_test()
        sys.exit(0 if success else 1)
    except Exception as e:
        print()
        print_error(f"Error: {str(e)}")
        sys.exit(1)
