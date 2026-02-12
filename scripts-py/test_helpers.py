#!/usr/bin/env python3

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

"""
Test Helpers - Funciones compartidas para scripts de testing
Proporciona utilidades comunes para logging, verificación y manejo de errores
"""

import sys
import os
from typing import Optional, Dict, Any, Callable

# Agregar directorio actual al path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

from n8n_crud_agent import N8NCrudAgent


# ============================================
# Funciones de Logging
# ============================================

def print_section(title: str):
    """Imprime una sección con formato consistente"""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}\n")


def print_step(step_num: int, total: int, description: str):
    """Imprime un paso con formato"""
    print(f"📋 Step {step_num}/{total}: {description}")


def print_success(message: str, indent: int = 0):
    """Imprime mensaje de éxito"""
    prefix = "   " * indent
    print(f"{prefix}✅ {message}")


def print_error(message: str, indent: int = 0):
    """Imprime mensaje de error"""
    prefix = "   " * indent
    print(f"{prefix}❌ {message}")


def print_warning(message: str, indent: int = 0):
    """Imprime mensaje de advertencia"""
    prefix = "   " * indent
    print(f"{prefix}⚠️  {message}")


def print_info(message: str, indent: int = 0):
    """Imprime mensaje informativo"""
    prefix = "   " * indent
    print(f"{prefix}ℹ️  {message}")


def print_header(title: str):
    """Imprime header principal del test"""
    print("\n" + "╔" + "="*58 + "╗")
    print(f"║  {title:54s}  ║")
    print("╚" + "="*58 + "╝\n")


# ============================================
# Funciones de Inicialización
# ============================================

def init_agent(api_url: str = "http://localhost:5678") -> Optional[N8NCrudAgent]:
    """
    Inicializa el agente N8N con manejo de errores
    
    Args:
        api_url: URL de la instancia de n8n
        
    Returns:
        Instancia de N8NCrudAgent o None si falla
    """
    try:
        agent = N8NCrudAgent(api_url)
        
        # Verificar conexión
        workflows = agent.list_workflows()
        if workflows is None:
            print_error("No se pudo conectar a n8n")
            print_info(f"URL: {api_url}", indent=1)
            print_info("Verifica que n8n esté corriendo y N8N_API_KEY esté configurada", indent=1)
            return None
            
        print_success(f"Conectado a n8n ({len(workflows)} workflows encontrados)")
        return agent
        
    except Exception as e:
        print_error(f"Error inicializando agente: {str(e)}")
        return None


# ============================================
# Funciones de Verificación
# ============================================

def verify_workflow_exists(
    agent: N8NCrudAgent, 
    workflow_id: str, 
    workflow_name: str
) -> Optional[Dict]:
    """
    Verifica que un workflow existe y retorna su información
    
    Args:
        agent: Instancia del agente
        workflow_id: ID del workflow
        workflow_name: Nombre del workflow (para mensajes)
        
    Returns:
        Datos del workflow o None si no existe
    """
    wf = agent.get_workflow_by_id(workflow_id)
    
    if not wf:
        print_error(f"Workflow {workflow_name} no encontrado")
        print_info(f"ID buscado: {workflow_id}", indent=1)
        return None
    
    print_success(f"{workflow_name} encontrado: {wf.get('name', 'Sin nombre')}")
    
    # Mostrar estado
    is_active = wf.get('active', False)
    status_icon = "🟢" if is_active else "🔴"
    status_text = "Activo" if is_active else "Inactivo"
    print_info(f"Estado: {status_icon} {status_text}", indent=1)
    
    # Advertir si está inactivo
    if not is_active:
        print_warning(f"{workflow_name} está inactivo, puede no funcionar correctamente", indent=1)
    
    return wf


def verify_api_key() -> bool:
    """
    Verifica que la API key esté configurada
    
    Returns:
        True si está configurada, False si no
    """
    api_key = os.environ.get('N8N_API_KEY') or os.environ.get('N8N_ACCESS_TOKEN')
    
    if not api_key:
        print_error("N8N_API_KEY no está configurada")
        print_info("Ejecuta: export N8N_API_KEY=tu_api_key", indent=1)
        return False
    
    print_success("N8N_API_KEY configurada")
    return True


# ============================================
# Funciones de Ejecución Segura
# ============================================

def safe_execute(
    func: Callable,
    error_msg: str,
    *args,
    **kwargs
) -> Optional[Any]:
    """
    Ejecuta una función con manejo de errores
    
    Args:
        func: Función a ejecutar
        error_msg: Mensaje de error si falla
        *args: Argumentos posicionales para la función
        **kwargs: Argumentos nombrados para la función
        
    Returns:
        Resultado de la función o None si falla
    """
    try:
        result = func(*args, **kwargs)
        if result is None:
            print_error(error_msg)
        return result
    except Exception as e:
        print_error(f"{error_msg}: {str(e)}")
        return None


# ============================================
# Funciones de Comparación
# ============================================

def count_executions(
    agent: N8NCrudAgent,
    workflow_id: str,
    limit: int = 50
) -> int:
    """
    Cuenta ejecuciones de un workflow específico
    
    Args:
        agent: Instancia del agente
        workflow_id: ID del workflow
        limit: Límite de ejecuciones a obtener
        
    Returns:
        Número de ejecuciones encontradas
    """
    executions = agent.get_executions(workflow_id=workflow_id, limit=limit)
    if not executions:
        return 0
    
    return len(executions)


def get_latest_execution(
    agent: N8NCrudAgent,
    workflow_id: str,
    limit: int = 5
) -> Optional[Dict]:
    """
    Obtiene la ejecución más reciente de un workflow
    
    Args:
        agent: Instancia del agente
        workflow_id: ID del workflow
        limit: Límite de ejecuciones a buscar
        
    Returns:
        Datos de la última ejecución o None
    """
    executions = agent.get_executions(workflow_id=workflow_id, limit=limit)
    if not executions:
        return None
    
    return executions[0]


# ============================================
# Funciones de Formato
# ============================================

def format_execution_info(execution: Dict, indent: int = 1) -> str:
    """
    Formatea información de una ejecución para mostrar
    
    Args:
        execution: Datos de la ejecución
        indent: Nivel de indentación
        
    Returns:
        String formateado
    """
    prefix = "   " * indent
    status = execution.get('status', 'unknown')
    status_icon = {
        'success': '✅',
        'error': '❌',
        'running': '⏳',
        'waiting': '⏸️'
    }.get(status, '❓')
    
    lines = [
        f"{prefix}ID: {execution.get('id', 'N/A')}",
        f"{prefix}Status: {status_icon} {status}",
        f"{prefix}Inicio: {execution.get('startedAt', 'N/A')[:19]}"
    ]
    
    if execution.get('finishedAt'):
        lines.append(f"{prefix}Fin: {execution.get('finishedAt', 'N/A')[:19]}")
    
    return '\n'.join(lines)


# ============================================
# Funciones de Test
# ============================================

def wait_for_execution(
    agent: N8NCrudAgent,
    workflow_id: str,
    initial_count: int,
    timeout: int = 10,
    check_interval: int = 1
) -> bool:
    """
    Espera a que aparezca una nueva ejecución
    
    Args:
        agent: Instancia del agente
        workflow_id: ID del workflow
        initial_count: Número inicial de ejecuciones
        timeout: Tiempo máximo de espera en segundos
        check_interval: Intervalo entre verificaciones
        
    Returns:
        True si apareció nueva ejecución, False si timeout
    """
    import time
    
    elapsed = 0
    while elapsed < timeout:
        time.sleep(check_interval)
        elapsed += check_interval
        
        current_count = count_executions(agent, workflow_id)
        if current_count > initial_count:
            return True
    
    return False
