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
Health Check de Workflows Críticos
Verifica el estado de todos los workflows importantes del sistema AutoAgenda
"""

import sys
import os


from workflow_config import (
    BB_00_WORKFLOW_ID, BB_00_WORKFLOW_NAME,
    BB_02_WORKFLOW_ID, BB_02_WORKFLOW_NAME,
    TEST_BB00_WORKFLOW_ID, TEST_BB00_WORKFLOW_NAME,
    N8N_LOCAL_URL
)
from test_helpers import (
    print_header, print_section, print_success, print_error, print_warning, print_info,
    init_agent, count_executions
)


# Workflows críticos a verificar
CRITICAL_WORKFLOWS = [
    {
        'id': BB_00_WORKFLOW_ID,
        'name': BB_00_WORKFLOW_NAME,
        'description': 'Global Error Handler',
        'must_be_active': True
    },
    {
        'id': BB_02_WORKFLOW_ID,
        'name': BB_02_WORKFLOW_NAME,
        'description': 'Security Firewall',
        'must_be_active': True
    }
]

# Workflows opcionales
OPTIONAL_WORKFLOWS = [
    {
        'id': TEST_BB00_WORKFLOW_ID,
        'name': TEST_BB00_WORKFLOW_NAME,
        'description': 'Test workflow para BB_00',
        'must_be_active': False
    }
]


def check_workflow_health(agent, workflow_info):
    """
    Verifica el estado de un workflow
    
    Returns:
        dict con status del workflow
    """
    wf_id = workflow_info['id']
    wf_name = workflow_info['name']
    must_be_active = workflow_info.get('must_be_active', False)
    
    # Obtener workflow
    wf = agent.get_workflow_by_id(wf_id)
    
    if not wf:
        return {
            'exists': False,
            'active': False,
            'healthy': False,
            'message': f"❌ {wf_name} NO ENCONTRADO"
        }
    
    is_active = wf.get('active', False)
    is_healthy = is_active if must_be_active else True
    
    # Contar ejecuciones
    exec_count = count_executions(agent, wf_id, limit=50)
    
    # Determinar mensaje
    if not is_active and must_be_active:
        status_msg = f"⚠️  {wf_name} existe pero está INACTIVO (debe estar activo)"
    elif is_active:
        status_msg = f"✅ {wf_name} está ACTIVO ({exec_count} ejecuciones)"
    else:
        status_msg = f"ℹ️  {wf_name} está inactivo ({exec_count} ejecuciones)"
    
    return {
        'exists': True,
        'active': is_active,
        'healthy': is_healthy,
        'executions': exec_count,
        'message': status_msg,
        'workflow': wf
    }


def run_health_check():
    """
    Ejecuta health check completo del sistema
    """
    print_header("Health Check: Workflows Críticos")
    
    # Inicializar agente
    agent = init_agent(N8N_LOCAL_URL)
    if not agent:
        print_error("No se pudo conectar a n8n")
        return False
    
    print()
    
    # Verificar workflows críticos
    print_section("WORKFLOWS CRÍTICOS")
    
    critical_results = []
    all_critical_healthy = True
    
    for wf_info in CRITICAL_WORKFLOWS:
        result = check_workflow_health(agent, wf_info)
        critical_results.append(result)
        
        print(result['message'])
        if result['exists']:
            print_info(f"ID: {wf_info['id']}", indent=1)
            print_info(f"Descripción: {wf_info['description']}", indent=1)
        print()
        
        if not result['healthy']:
            all_critical_healthy = False
    
    # Verificar workflows opcionales
    print_section("WORKFLOWS OPCIONALES")
    
    optional_results = []
    for wf_info in OPTIONAL_WORKFLOWS:
        result = check_workflow_health(agent, wf_info)
        optional_results.append(result)
        
        print(result['message'])
        if result['exists']:
            print_info(f"ID: {wf_info['id']}", indent=1)
        print()
    
    # Resumen general
    print_section("RESUMEN")
    
    total_workflows = len(CRITICAL_WORKFLOWS) + len(OPTIONAL_WORKFLOWS)
    total_exists = sum(1 for r in critical_results + optional_results if r['exists'])
    total_active = sum(1 for r in critical_results + optional_results if r['active'])
    total_executions = sum(r.get('executions', 0) for r in critical_results + optional_results)
    
    print_info(f"Total workflows verificados: {total_workflows}")
    print_info(f"Workflows encontrados: {total_exists}/{total_workflows}")
    print_info(f"Workflows activos: {total_active}/{total_exists}")
    print_info(f"Total de ejecuciones: {total_executions}")
    print()
    
    # Estado final
    if all_critical_healthy:
        print_success("✅ SISTEMA SALUDABLE - Todos los workflows críticos están operativos")
        return True
    else:
        print_error("⚠️  ATENCIÓN REQUERIDA - Algunos workflows críticos tienen problemas")
        print()
        print_info("Acciones recomendadas:")
        for wf_info, result in zip(CRITICAL_WORKFLOWS, critical_results):
            if not result['healthy']:
                if not result['exists']:
                    print_info(f"- Importar workflow {wf_info['name']}", indent=1)
                elif not result['active']:
                    print_info(f"- Activar workflow {wf_info['name']} (ID: {wf_info['id']})", indent=1)
        return False


if __name__ == "__main__":
    try:
        success = run_health_check()
        sys.exit(0 if success else 1)
    except Exception as e:
        print()
        print_error(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
