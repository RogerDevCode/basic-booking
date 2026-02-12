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
Test de Notificaciones Telegram de BB_00
Verifica que BB_00 envía notificaciones a Telegram cuando captura errores
"""

import sys
import time
import os


from workflow_config import BB_00_WORKFLOW_ID, BB_00_WORKFLOW_NAME, TEST_BB00_WORKFLOW_ID, TEST_BB00_WORKFLOW_NAME, N8N_LOCAL_URL
from test_helpers import (
    print_header, print_section, print_step,
    print_success, print_error, print_warning, print_info,
    init_agent, verify_workflow_exists, verify_api_key,
    count_executions, get_latest_execution
)


def verify_telegram_nodes(agent, workflow_id):
    """
    Verifica que el workflow tiene nodos de Telegram configurados
    
    Returns:
        Lista de nodos de Telegram encontrados
    """
    wf = agent.get_workflow_by_id(workflow_id)
    if not wf:
        return []
    
    # Buscar nodos de Telegram
    telegram_nodes = [
        n for n in wf.get('nodes', []) 
        if 'telegram' in n.get('type', '').lower()
    ]
    
    return telegram_nodes


def check_telegram_execution(execution_data):
    """
    Verifica si el nodo de Telegram se ejecutó en una ejecución
    
    Args:
        execution_data: Datos completos de la ejecución
        
    Returns:
        dict con información de la ejecución de Telegram
    """
    result = {
        'telegram_executed': False,
        'telegram_success': False,
        'telegram_node_name': None,
        'error_message': None
    }
    
    # Obtener datos de ejecución de nodos
    execution_data_nodes = execution_data.get('data', {})
    
    if not execution_data_nodes:
        return result
    
    # Buscar nodos de Telegram en los datos de ejecución
    for node_name, node_runs in execution_data_nodes.items():
        # Verificar si es un nodo de Telegram (por nombre o tipo)
        if 'telegram' in node_name.lower():
            result['telegram_executed'] = True
            result['telegram_node_name'] = node_name
            
            # Verificar si se ejecutó exitosamente
            if isinstance(node_runs, list) and len(node_runs) > 0:
                last_run = node_runs[0]
                
                # Verificar si hay error
                if isinstance(last_run, dict):
                    if last_run.get('error'):
                        result['error_message'] = str(last_run.get('error'))
                    else:
                        result['telegram_success'] = True
            
            break
    
    return result


def run_telegram_notification_test():
    """
    Ejecuta test completo de notificaciones Telegram
    """
    
    print_header("Test: Notificaciones Telegram de BB_00")
    
    # ============================================
    # Step 1: Verificar configuración
    # ============================================
    print_step(1, 7, "Verificando configuración")
    
    if not verify_api_key():
        return False
    
    # ============================================
    # Step 2: Inicializar Agente
    # ============================================
    print()
    print_step(2, 7, "Conectando a n8n")
    
    agent = init_agent(N8N_LOCAL_URL)
    if not agent:
        return False
    
    # ============================================
    # Step 3: Verificar BB_00
    # ============================================
    print()
    print_step(3, 7, "Verificando BB_00_Global_Error_Handler")
    
    bb00 = verify_workflow_exists(agent, BB_00_WORKFLOW_ID, BB_00_WORKFLOW_NAME)
    if not bb00:
        return False
    
    # Verificar nodos de Telegram
    telegram_nodes = verify_telegram_nodes(agent, BB_00_WORKFLOW_ID)
    
    if not telegram_nodes:
        print_error("BB_00 no tiene nodos de Telegram configurados", indent=1)
        return False
    
    print_success(f"Encontrados {len(telegram_nodes)} nodo(s) de Telegram", indent=1)
    for node in telegram_nodes:
        print_info(f"- {node.get('name', 'Sin nombre')} (tipo: {node.get('type')})", indent=2)
    
    # ============================================
    # Step 4: Verificar Test_BB00
    # ============================================
    print()
    print_step(4, 7, "Verificando workflow de test")
    
    test_wf = verify_workflow_exists(agent, TEST_BB00_WORKFLOW_ID, TEST_BB00_WORKFLOW_NAME)
    if not test_wf:
        print_warning("Workflow de test no encontrado", indent=1)
        print_info("Puedes disparar un error manualmente desde cualquier workflow", indent=1)
        return False
    
    # ============================================
    # Step 5: Contar ejecuciones actuales
    # ============================================
    print()
    print_step(5, 7, "Contando ejecuciones actuales de BB_00")
    
    initial_count = count_executions(agent, BB_00_WORKFLOW_ID, limit=50)
    print_info(f"Ejecuciones actuales: {initial_count}", indent=1)
    
    # ============================================
    # Step 6: Instrucciones para disparar error
    # ============================================
    print()
    print_step(6, 7, "Disparar error para test")
    
    print()
    print_section("INSTRUCCIONES")
    print("Para probar las notificaciones de Telegram:")
    print()
    print(f"   1. Abre: {N8N_LOCAL_URL}/workflow/{TEST_BB00_WORKFLOW_ID}")
    print("   2. Haz clic en 'Execute Workflow'")
    print("   3. El workflow disparará un error")
    print("   4. BB_00 capturará el error y enviará notificación a Telegram")
    print()
    print("Presiona ENTER cuando hayas ejecutado el workflow...")
    
    try:
        input()
    except KeyboardInterrupt:
        print()
        print_warning("Test cancelado")
        return False
    
    # ============================================
    # Step 7: Verificar notificación
    # ============================================
    print()
    print_step(7, 7, "Verificando envío de notificación Telegram")
    
    print_info("Esperando 5 segundos para que BB_00 procese...", indent=1)
    time.sleep(5)
    
    # Obtener última ejecución
    latest_exec = get_latest_execution(agent, BB_00_WORKFLOW_ID, limit=20)
    
    if not latest_exec:
        print_error("No se encontró ejecución de BB_00", indent=1)
        return False
    
    # Verificar si es nueva
    final_count = count_executions(agent, BB_00_WORKFLOW_ID, limit=50)
    new_executions = final_count - initial_count
    
    if new_executions == 0:
        print_error("BB_00 no registró nuevas ejecuciones", indent=1)
        print_info("El error puede no haberse disparado correctamente", indent=2)
        return False
    
    print_success(f"Nueva ejecución de BB_00 detectada (ID: {latest_exec.get('id')})", indent=1)
    
    # Obtener datos completos de la ejecución
    exec_id = latest_exec.get('id')
    full_exec = agent.get_execution_by_id(exec_id)
    
    if not full_exec:
        print_warning("No se pudieron obtener detalles de la ejecución", indent=1)
        print_info("Verifica manualmente en n8n UI", indent=2)
        return False
    
    # Verificar ejecución de Telegram
    telegram_result = check_telegram_execution(full_exec)
    
    # ============================================
    # Resultado final
    # ============================================
    print()
    print_section("RESULTADO")
    
    if telegram_result['telegram_executed']:
        print_success("✅ Nodo de Telegram fue ejecutado")
        print_info(f"Nodo: {telegram_result['telegram_node_name']}", indent=1)
        
        if telegram_result['telegram_success']:
            print_success("✅ Notificación enviada exitosamente", indent=1)
            print()
            print_success("🎉 ¡TEST EXITOSO! BB_00 envió notificación a Telegram")
            print()
            print_info("Verifica tu chat de Telegram para confirmar que recibiste el mensaje")
            return True
        else:
            print_error("❌ Error al enviar notificación", indent=1)
            if telegram_result['error_message']:
                print_info(f"Error: {telegram_result['error_message']}", indent=2)
            print()
            print_warning("BB_00 intentó enviar pero falló")
            print_info("Verifica la configuración de Telegram en n8n", indent=1)
            return False
    else:
        print_error("❌ Nodo de Telegram NO fue ejecutado")
        print()
        print_info("Posibles causas:")
        print_info("1. El flujo de BB_00 no llegó al nodo de Telegram", indent=1)
        print_info("2. Hay una condición que previene la ejecución", indent=1)
        print_info("3. El workflow tiene un error antes del nodo de Telegram", indent=1)
        print()
        print_info(f"Revisa la ejecución manualmente: {N8N_LOCAL_URL}/execution/{exec_id}")
        return False


if __name__ == "__main__":
    try:
        success = run_telegram_notification_test()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print()
        print_warning("Test interrumpido")
        sys.exit(130)
    except Exception as e:
        print()
        print_error(f"Error inesperado: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
