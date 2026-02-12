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
Test Live de BB_00_Global_Error_Handler
Verifica que BB_00 captura errores correctamente usando el workflow Test_BB00 existente
"""

import sys
import time
import os


from workflow_config import BB_00_WORKFLOW_ID, BB_00_WORKFLOW_NAME, TEST_BB00_WORKFLOW_ID, TEST_BB00_WORKFLOW_NAME, N8N_LOCAL_URL
from test_helpers import (
    print_header, print_section, print_step,
    print_success, print_error, print_warning, print_info,
    init_agent, verify_workflow_exists, verify_api_key,
    count_executions, get_latest_execution, format_execution_info
)


def run_bb00_test():
    """
    Ejecuta test completo de BB_00
    
    Pasos:
    1. Verificar conexión y API key
    2. Verificar que BB_00 existe y está activo
    3. Verificar que Test_BB00 existe
    4. Contar ejecuciones actuales de BB_00
    5. Ejecutar Test_BB00 desde n8n UI (manual)
    6. Verificar que BB_00 capturó el error
    """
    
    print_header("Test Live: BB_00_Global_Error_Handler")
    
    # ============================================
    # Step 1: Verificar API Key
    # ============================================
    print_step(1, 6, "Verificando configuración")
    
    if not verify_api_key():
        return False
    
    print_info(f"URL de n8n: {N8N_LOCAL_URL}", indent=1)
    
    # ============================================
    # Step 2: Inicializar Agente
    # ============================================
    print()
    print_step(2, 6, "Conectando a n8n")
    
    agent = init_agent(N8N_LOCAL_URL)
    if not agent:
        return False
    
    # ============================================
    # Step 3: Verificar BB_00
    # ============================================
    print()
    print_step(3, 6, "Verificando BB_00_Global_Error_Handler")
    
    bb00 = verify_workflow_exists(agent, BB_00_WORKFLOW_ID, BB_00_WORKFLOW_NAME)
    if not bb00:
        print_error("No se puede continuar sin BB_00")
        return False
    
    # ============================================
    # Step 4: Verificar Test_BB00
    # ============================================
    print()
    print_step(4, 6, "Verificando workflow de test")
    
    test_wf = verify_workflow_exists(agent, TEST_BB00_WORKFLOW_ID, TEST_BB00_WORKFLOW_NAME)
    if not test_wf:
        print_error("Workflow de test no encontrado")
        print_info("Puedes importar Test_BB00_Enhanced.json desde workflows/", indent=1)
        print_info("O crear un workflow que dispare un error intencional", indent=1)
        return False
    
    # Activar si está inactivo
    if not test_wf.get('active'):
        print()
        print_info("Activando workflow de test...", indent=1)
        if agent.activate_workflow(TEST_BB00_WORKFLOW_ID):
            print_success("Workflow activado", indent=1)
        else:
            print_error("No se pudo activar el workflow", indent=1)
            return False
    
    # ============================================
    # Step 5: Contar ejecuciones actuales
    # ============================================
    print()
    print_step(5, 6, "Contando ejecuciones actuales de BB_00")
    
    initial_count = count_executions(agent, BB_00_WORKFLOW_ID, limit=50)
    print_info(f"Ejecuciones actuales: {initial_count}", indent=1)
    
    # ============================================
    # Step 6: Instrucciones para ejecutar test
    # ============================================
    print()
    print_step(6, 6, "Ejecutar test manualmente")
    
    print()
    print_section("INSTRUCCIONES")
    print("Para completar el test, ejecuta el workflow Test_BB00 desde n8n UI:")
    print()
    print(f"   1. Abre: {N8N_LOCAL_URL}/workflow/{TEST_BB00_WORKFLOW_ID}")
    print("   2. Haz clic en 'Execute Workflow'")
    print("   3. El workflow disparará un error intencional")
    print("   4. BB_00 debería capturar el error automáticamente")
    print()
    print("Presiona ENTER cuando hayas ejecutado el workflow...")
    
    try:
        input()
    except KeyboardInterrupt:
        print()
        print_warning("Test cancelado por el usuario")
        return False
    
    # ============================================
    # Verificar resultados
    # ============================================
    print()
    print_section("VERIFICANDO RESULTADOS")
    
    print_info("Esperando 3 segundos para que BB_00 procese...")
    time.sleep(3)
    
    # Contar nuevas ejecuciones
    final_count = count_executions(agent, BB_00_WORKFLOW_ID, limit=50)
    new_executions = final_count - initial_count
    
    print()
    print_info(f"Ejecuciones antes: {initial_count}")
    print_info(f"Ejecuciones después: {final_count}")
    print_info(f"Nuevas ejecuciones: {new_executions}")
    
    # ============================================
    # Resultado final
    # ============================================
    print()
    print_section("RESULTADO")
    
    if new_executions > 0:
        print_success("¡BB_00 capturó el error!")
        print()
        
        # Mostrar detalles de la última ejecución
        latest = get_latest_execution(agent, BB_00_WORKFLOW_ID)
        if latest:
            print_info("Detalles de la última ejecución:")
            print()
            print(format_execution_info(latest, indent=1))
            print()
            
            if latest.get('status') == 'success':
                print_success("¡PERFECTO! BB_00 procesó el error exitosamente")
                return True
            else:
                print_warning(f"BB_00 fue disparado pero terminó con status: {latest.get('status')}")
                return False
        else:
            print_warning("No se pudo obtener detalles de la ejecución")
            return True
    else:
        print_error("BB_00 NO registró nuevas ejecuciones")
        print()
        print_info("Posibles causas:")
        print_info("1. BB_00 está inactivo", indent=1)
        print_info("2. El workflow de test no tiene errorWorkflow configurado", indent=1)
        print_info("3. El error no se disparó correctamente", indent=1)
        print()
        print_info(f"Verifica manualmente: {N8N_LOCAL_URL}/workflow/{BB_00_WORKFLOW_ID}")
        return False


if __name__ == "__main__":
    try:
        success = run_bb00_test()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print()
        print_warning("Test interrumpido por el usuario")
        sys.exit(130)
    except Exception as e:
        print()
        print_error(f"Error inesperado: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
