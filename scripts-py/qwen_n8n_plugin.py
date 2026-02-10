#!/usr/bin/env python3
"""
Plugin de n8n para Qwen
Este plugin permite a Qwen interactuar con tu instancia de n8n
"""

import json
import sys
import os
from typing import Dict, Any, Optional

# Agregar el directorio actual al path para importar el módulo
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from n8n_crud_agent import N8NCrudAgent


def get_api_key():
    """
    Obtiene la API key de las variables de ambiente N8N_API_KEY o N8N_ACCESS_TOKEN
    Si no están definidas, muestra un mensaje de error y termina la ejecución
    """
    # Intenta obtenerla de las variables de ambiente
    api_key = os.environ.get('N8N_API_KEY') or os.environ.get('N8N_ACCESS_TOKEN')

    # Si no se encontró la API key, mostrar mensaje de error y salir
    if not api_key:
        print("Error: No se encontró ninguna variable de ambiente N8N_API_KEY o N8N_ACCESS_TOKEN.")
        print("Por favor, configura alguna de estas variables de ambiente.")
        sys.exit(1)

    return api_key


class N8NPlugin:
    """
    Plugin de n8n para Qwen
    Proporciona métodos para interactuar con n8n desde Qwen
    """

    def __init__(self, api_url: str = "http://localhost:5678", api_key: str = None):
        """
        Inicializa el plugin con la configuración de n8n

        Args:
            api_url: URL de la instancia de n8n
            api_key: Clave de API para autenticación
        """
        if not api_key:
            # Usar la API key de la variable de ambiente o archivo .env
            api_key = get_api_key()

        self.agent = N8NCrudAgent(api_url, api_key)

    def execute_action(self, action: str, **kwargs) -> Dict[str, Any]:
        """
        Ejecuta una acción específica en n8n

        Args:
            action: La acción a ejecutar (list_workflows, create_workflow, etc.)
            **kwargs: Parámetros adicionales para la acción

        Returns:
            Resultado de la acción como diccionario
        """
        try:
            if action == "list_workflows":
                return self._list_workflows(**kwargs)
            elif action == "list_active_workflows":
                return self._list_active_workflows(**kwargs)
            elif action == "get_workflow_by_id":
                return self._get_workflow_by_id(**kwargs)
            elif action == "create_workflow":
                return self._create_workflow(**kwargs)
            elif action == "update_workflow":
                return self._update_workflow(**kwargs)
            elif action == "delete_workflow":
                return self._delete_workflow(**kwargs)
            elif action == "activate_workflow":
                return self._activate_workflow(**kwargs)
            elif action == "deactivate_workflow":
                return self._deactivate_workflow(**kwargs)
            elif action == "publish_workflow":
                return self._publish_workflow(**kwargs)
            elif action == "unpublish_workflow":
                return self._unpublish_workflow(**kwargs)
            elif action == "execute_workflow":
                return self._execute_workflow(**kwargs)
            elif action == "get_executions":
                return self._get_executions(**kwargs)
            elif action == "get_execution_by_id":
                return self._get_execution_by_id(**kwargs)
            else:
                return {
                    "success": False,
                    "error": f"Acción desconocida: {action}",
                    "supported_actions": [
                        "list_workflows", "list_active_workflows", "get_workflow_by_id",
                        "create_workflow", "update_workflow", "delete_workflow",
                        "activate_workflow", "deactivate_workflow",
                        "publish_workflow", "unpublish_workflow",
                        "execute_workflow", "get_executions", "get_execution_by_id"
                    ]
                }
        except Exception as e:
            return {
                "success": False,
                "error": f"Error ejecutando acción {action}: {str(e)}"
            }

    def _list_workflows(self, **kwargs) -> Dict[str, Any]:
        """Lista todos los workflows"""
        workflows = self.agent.list_workflows()
        return {
            "success": workflows is not None,
            "data": workflows if workflows is not None else [],
            "count": len(workflows) if workflows is not None else 0
        }

    def _list_active_workflows(self, **kwargs) -> Dict[str, Any]:
        """Lista solo workflows activos"""
        workflows = self.agent.list_active_workflows()
        return {
            "success": workflows is not None,
            "data": workflows if workflows is not None else [],
            "count": len(workflows) if workflows is not None else 0
        }

    def _get_workflow_by_id(self, **kwargs) -> Dict[str, Any]:
        """Obtiene un workflow específico por ID"""
        workflow_id = kwargs.get('workflow_id')
        if not workflow_id:
            return {"success": False, "error": "workflow_id es requerido"}

        workflow = self.agent.get_workflow_by_id(workflow_id)
        return {
            "success": workflow is not None,
            "data": workflow
        }

    def _create_workflow(self, **kwargs) -> Dict[str, Any]:
        """Crea un nuevo workflow"""
        workflow_data = kwargs.get('workflow_data')
        if not workflow_data:
            return {"success": False, "error": "workflow_data es requerido"}

        created = self.agent.create_workflow(workflow_data)
        return {
            "success": created is not None,
            "data": created
        }

    def _update_workflow(self, **kwargs) -> Dict[str, Any]:
        """Actualiza un workflow existente"""
        workflow_id = kwargs.get('workflow_id')
        workflow_data = kwargs.get('workflow_data')

        if not workflow_id:
            return {"success": False, "error": "workflow_id es requerido"}
        if not workflow_data:
            return {"success": False, "error": "workflow_data es requerido"}

        updated = self.agent.update_workflow(workflow_id, workflow_data)
        return {
            "success": updated is not None,
            "data": updated
        }

    def _delete_workflow(self, **kwargs) -> Dict[str, Any]:
        """Elimina un workflow"""
        workflow_id = kwargs.get('workflow_id')
        if not workflow_id:
            return {"success": False, "error": "workflow_id es requerido"}

        success = self.agent.delete_workflow(workflow_id)
        return {
            "success": success
        }

    def _activate_workflow(self, **kwargs) -> Dict[str, Any]:
        """Activa un workflow"""
        workflow_id = kwargs.get('workflow_id')
        if not workflow_id:
            return {"success": False, "error": "workflow_id es requerido"}

        success = self.agent.activate_workflow(workflow_id)
        return {
            "success": success
        }

    def _deactivate_workflow(self, **kwargs) -> Dict[str, Any]:
        """Desactiva un workflow"""
        workflow_id = kwargs.get('workflow_id')
        if not workflow_id:
            return {"success": False, "error": "workflow_id es requerido"}

        success = self.agent.deactivate_workflow(workflow_id)
        return {
            "success": success
        }

    def _publish_workflow(self, **kwargs) -> Dict[str, Any]:
        """Publica un workflow (alias para activar)"""
        workflow_id = kwargs.get('workflow_id')
        if not workflow_id:
            return {"success": False, "error": "workflow_id es requerido"}

        success = self.agent.publish_workflow(workflow_id)
        return {
            "success": success
        }

    def _unpublish_workflow(self, **kwargs) -> Dict[str, Any]:
        """Despublica un workflow (alias para desactivar)"""
        workflow_id = kwargs.get('workflow_id')
        if not workflow_id:
            return {"success": False, "error": "workflow_id es requerido"}

        success = self.agent.unpublish_workflow(workflow_id)
        return {
            "success": success
        }

    def _execute_workflow(self, **kwargs) -> Dict[str, Any]:
        """Ejecuta un workflow manualmente"""
        workflow_id = kwargs.get('workflow_id')
        if not workflow_id:
            return {"success": False, "error": "workflow_id es requerido"}

        result = self.agent.execute_workflow(workflow_id)
        return {
            "success": result is not None,
            "data": result
        }

    def _get_executions(self, **kwargs) -> Dict[str, Any]:
        """Obtiene ejecuciones de un workflow"""
        workflow_id = kwargs.get('workflow_id')
        limit = kwargs.get('limit', 10)

        executions = self.agent.get_executions(workflow_id, limit)
        return {
            "success": executions is not None,
            "data": executions if executions is not None else [],
            "count": len(executions) if executions is not None else 0
        }

    def _get_execution_by_id(self, **kwargs) -> Dict[str, Any]:
        """Obtiene una ejecución específica por ID"""
        execution_id = kwargs.get('execution_id')
        if not execution_id:
            return {"success": False, "error": "execution_id es requerido"}

        execution = self.agent.get_execution_by_id(execution_id)
        return {
            "success": execution is not None,
            "data": execution
        }


# Función de conveniencia para que Qwen pueda llamar directamente
def qwen_n8n_plugin(action: str, **kwargs) -> str:
    """
    Función principal que Qwen puede llamar para interactuar con n8n

    Args:
        action: La acción a ejecutar
        **kwargs: Parámetros para la acción

    Returns:
        Resultado serializado como JSON string
    """
    plugin = N8NPlugin()
    result = plugin.execute_action(action, **kwargs)
    return json.dumps(result, indent=2, ensure_ascii=False)


# Ejemplo de uso
if __name__ == "__main__":
    # Ejemplo de cómo usar el plugin
    print("Plugin de n8n para Qwen")
    print("Ejemplo de uso:")

    # Listar workflows
    result = qwen_n8n_plugin("list_workflows")
    print(f"Listar workflows: {result}")

    # Activar un workflow (ejemplo)
    # result = qwen_n8n_plugin("activate_workflow", workflow_id="some_id")
    # print(f"Activar workflow: {result}")