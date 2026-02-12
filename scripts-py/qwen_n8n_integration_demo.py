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
Ejemplo de cómo Qwen podría usar el plugin de n8n
"""

import json
import sys
import os

# Agregar el directorio scripts-py al path para importar el módulo
sys.path.append(os.path.join(os.path.dirname(__file__)))
from qwen_n8n_plugin import qwen_n8n_plugin


def simulate_qwen_interaction():
    """
    Simula cómo Qwen podría interpretar comandos del usuario y usar el plugin de n8n
    """
    print("=== Simulación de Interacción Qwen-n8n ===\n")

    # Simular diferentes comandos que Qwen podría recibir

    # 1. Comando: "Lista todos los workflows"
    print("Usuario: 'Lista todos los workflows'")
    result = qwen_n8n_plugin("list_workflows")
    parsed_result = json.loads(result)
    print(f"Respuesta: Encontrados {parsed_result.get('count', 0)} workflows\n")

    # 2. Comando: "Lista workflows activos"
    print("Usuario: 'Lista workflows activos'")
    result = qwen_n8n_plugin("list_active_workflows")
    parsed_result = json.loads(result)
    print(f"Respuesta: Encontrados {parsed_result.get('count', 0)} workflows activos\n")

    # 3. Comando: "Activa el workflow con ID leO4EqWL0nWqUhcJ"
    print("Usuario: 'Activa el workflow con ID leO4EqWL0nWqUhcJ'")
    result = qwen_n8n_plugin("activate_workflow", workflow_id="leO4EqWL0nWqUhcJ")
    parsed_result = json.loads(result)
    print(f"Respuesta: Activación exitosa: {parsed_result.get('success', False)}\n")

    # 4. Comando: "Obtén información del workflow leO4EqWL0nWqUhcJ"
    print("Usuario: 'Obtén información del workflow leO4EqWL0nWqUhcJ'")
    result = qwen_n8n_plugin("get_workflow_by_id", workflow_id="leO4EqWL0nWqUhcJ")
    parsed_result = json.loads(result)
    if parsed_result.get('success'):
        workflow = parsed_result.get('data', {})
        print(f"Respuesta: Workflow '{workflow.get('name', 'Desconocido')}' - Estado: {'ACTIVO' if workflow.get('active', False) else 'INACTIVO'}\n")
    else:
        print(f"Respuesta: Error obteniendo workflow\n")

    # 5. Comando: "Desactiva el workflow con ID leO4EqWL0nWqUhcJ"
    print("Usuario: 'Desactiva el workflow con ID leO4EqWL0nWqUhcJ'")
    result = qwen_n8n_plugin("deactivate_workflow", workflow_id="leO4EqWL0nWqUhcJ")
    parsed_result = json.loads(result)
    print(f"Respuesta: Desactivación exitosa: {parsed_result.get('success', False)}\n")

    # 6. Comando: "Intenta crear un workflow"
    print("Usuario: 'Crea un workflow de ejemplo'")
    sample_workflow = {
        "name": "Workflow de Prueba desde Qwen",
        "nodes": [
            {
                "parameters": {},
                "id": "qwen-trigger-node",
                "name": "Qwen Trigger",
                "type": "n8n-nodes-base.manualTrigger",
                "typeVersion": 1,
                "position": [240, 300]
            }
        ],
        "connections": {},
        "settings": {
            "saveManualExecutions": True
        }
    }
    result = qwen_n8n_plugin("create_workflow", workflow_data=sample_workflow)
    parsed_result = json.loads(result)
    if parsed_result.get('success'):
        new_workflow = parsed_result.get('data', {})
        print(f"Respuesta: Workflow creado con ID: {new_workflow.get('id', 'Desconocido')}\n")
    else:
        print(f"Respuesta: Error creando workflow: {parsed_result.get('error', 'Desconocido')}\n")

    # 7. Comando: "Ejecuta el workflow con ID leO4EqWL0nWqUhcJ"
    print("Usuario: 'Ejecuta el workflow con ID leO4EqWL0nWqUhcJ'")
    result = qwen_n8n_plugin("execute_workflow", workflow_id="leO4EqWL0nWqUhcJ")
    parsed_result = json.loads(result)
    print(f"Respuesta: Ejecución exitosa: {parsed_result.get('success', False)}\n")

    # 8. Comando: "Obtén ejecuciones del workflow leO4EqWL0nWqUhcJ"
    print("Usuario: 'Obtén ejecuciones del workflow leO4EqWL0nWqUhcJ'")
    result = qwen_n8n_plugin("get_executions", workflow_id="leO4EqWL0nWqUhcJ", limit=5)
    parsed_result = json.loads(result)
    if parsed_result.get('success'):
        executions = parsed_result.get('data', [])
        print(f"Respuesta: Encontradas {len(executions)} ejecuciones\n")
    else:
        print(f"Respuesta: Error obteniendo ejecuciones\n")


def qwen_process_user_request(user_input: str):
    """
    Simula cómo Qwen procesaría una solicitud del usuario y decidiría usar el plugin de n8n

    Args:
        user_input: Entrada del usuario
    """
    print(f"Procesando solicitud: '{user_input}'")

    # Detectar intenciones relacionadas con n8n
    user_lower = user_input.lower()

    # Detectar IDs de workflows en la entrada (simplificado)
    workflow_ids = []
    for word in user_input.split():
        if len(word) >= 8 and word.isalnum():  # Asumiendo IDs alfanuméricos
            workflow_ids.append(word)

    # Determinar la acción basada en palabras clave
    if any(word in user_lower for word in ["list", "show", "all", "workflows", "workflow"]):
        if any(word in user_lower for word in ["active", "running", "started"]):
            result = qwen_n8n_plugin("list_active_workflows")
            return f"He listado los workflows activos: {result}"
        else:
            result = qwen_n8n_plugin("list_workflows")
            return f"He listado todos los workflows: {result}"

    elif any(word in user_lower for word in ["activate", "start", "run", "publish"]):
        # Intentar encontrar un ID de workflow en la entrada
        for wf_id in workflow_ids:
            if len(wf_id) >= 8:  # Probablemente sea un ID de workflow
                result = qwen_n8n_plugin("activate_workflow", workflow_id=wf_id)
                return f"He intentado activar el workflow {wf_id}: {result}"
        return "No pude encontrar un ID de workflow para activar. Por favor proporcione un ID específico."

    elif any(word in user_lower for word in ["deactivate", "stop", "pause", "unpublish"]):
        # Intentar encontrar un ID de workflow en la entrada
        for wf_id in workflow_ids:
            if len(wf_id) >= 8:  # Probablemente sea un ID de workflow
                result = qwen_n8n_plugin("deactivate_workflow", workflow_id=wf_id)
                return f"He intentado desactivar el workflow {wf_id}: {result}"
        return "No pude encontrar un ID de workflow para desactivar. Por favor proporcione un ID específico."

    elif any(word in user_lower for word in ["get", "show", "info", "information", "details"]) and any(wf_id in user_input for wf_id in workflow_ids):
        # Intentar encontrar un ID de workflow en la entrada
        for wf_id in workflow_ids:
            if len(wf_id) >= 8:  # Probablemente sea un ID de workflow
                result = qwen_n8n_plugin("get_workflow_by_id", workflow_id=wf_id)
                return f"Información del workflow {wf_id}: {result}"
        return "No pude encontrar un ID de workflow para obtener información. Por favor proporcione un ID específico."

    elif any(word in user_lower for word in ["create", "new", "add"]):
        # Crear un workflow básico
        sample_workflow = {
            "name": f"Workflow creado por Qwen - {len(user_input)}",
            "nodes": [
                {
                    "parameters": {},
                    "id": f"qwen-trigger-{hash(user_input) % 10000}",
                    "name": "Qwen Manual Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }
        result = qwen_n8n_plugin("create_workflow", workflow_data=sample_workflow)
        return f"He intentado crear un nuevo workflow: {result}"

    elif any(word in user_lower for word in ["execute", "run", "start"]):
        # Intentar encontrar un ID de workflow en la entrada
        for wf_id in workflow_ids:
            if len(wf_id) >= 8:  # Probablemente sea un ID de workflow
                result = qwen_n8n_plugin("execute_workflow", workflow_id=wf_id)
                return f"He intentado ejecutar el workflow {wf_id}: {result}"
        return "No pude encontrar un ID de workflow para ejecutar. Por favor proporcione un ID específico."

    elif any(word in user_lower for word in ["executions", "runs", "history"]):
        # Intentar encontrar un ID de workflow en la entrada
        for wf_id in workflow_ids:
            if len(wf_id) >= 8:  # Probablemente sea un ID de workflow
                result = qwen_n8n_plugin("get_executions", workflow_id=wf_id, limit=10)
                return f"Ejecuciones del workflow {wf_id}: {result}"
        return "No pude encontrar un ID de workflow para obtener ejecuciones. Por favor proporcione un ID específico."

    else:
        return "No identifiqué una acción específica de n8n en tu solicitud."

    return "Procesamiento completado."


if __name__ == "__main__":
    simulate_qwen_interaction()

    print("\n=== Simulación de Procesamiento de Solicitudes ===\n")

    # Ejemplos de solicitudes que Qwen podría recibir
    examples = [
        "Lista todos los workflows",
        "¿Qué workflows están activos?",
        "Activa el workflow leO4EqWL0nWqUhcJ",
        "Detén el workflow leO4EqWL0nWqUhcJ",
        "Muéstrame el workflow leO4EqWL0nWqUhcJ",
        "Ejecuta el workflow leO4EqWL0nWqUhcJ",
        "¿Cuáles son las últimas ejecuciones del workflow leO4EqWL0nWqUhcJ?"
    ]

    for example in examples:
        response = qwen_process_user_request(example)
        print(f"Solicitud: {example}")
        print(f"Respuesta: {response}\n")