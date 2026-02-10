#!/usr/bin/env python3
"""
Script para importar el workflow BB_00_Global_Error_Handler en n8n
"""

import json
import sys
import os

# Agregar el directorio actual al path para importar el módulo
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from qwen_n8n_plugin import qwen_n8n_plugin


def import_workflow_from_json(json_file_path):
    """
    Importa un workflow desde un archivo JSON
    
    Args:
        json_file_path: Ruta al archivo JSON del workflow
    """
    # Leer el contenido del archivo JSON
    with open(json_file_path, 'r', encoding='utf-8') as file:
        workflow_data = json.load(file)
    
    print(f"Leyendo workflow desde: {json_file_path}")
    print(f"Nombre del workflow: {workflow_data.get('name', 'Unknown')}")
    print(f"Número de nodos: {len(workflow_data.get('nodes', []))}")
    
    # Intentar crear el workflow usando el plugin
    result = qwen_n8n_plugin("create_workflow", workflow_data=workflow_data)
    
    print("\nResultado de la importación:")
    print(result)
    
    # Parsear el resultado para verificar si fue exitoso
    result_dict = json.loads(result)
    
    if result_dict.get("success"):
        workflow_info = result_dict.get("data", {})
        workflow_id = workflow_info.get("id")
        workflow_name = workflow_info.get("name")
        
        print(f"\n✅ Workflow importado exitosamente!")
        print(f"ID: {workflow_id}")
        print(f"Nombre: {workflow_name}")
        
        return workflow_id
    else:
        print(f"\n❌ Error al importar el workflow:")
        print(result_dict.get("error", "Error desconocido"))
        return None


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Uso: python import_bb00_workflow.py <ruta_al_archivo_json>")
        print("Ejemplo: python import_bb00_workflow.py ../temp_n8n_import/BB_00_Global_Error_Handler.json")
        sys.exit(1)
    
    json_file_path = sys.argv[1]
    
    if not os.path.exists(json_file_path):
        print(f"Error: El archivo {json_file_path} no existe")
        sys.exit(1)
    
    workflow_id = import_workflow_from_json(json_file_path)
    
    if workflow_id:
        print(f"\n🎉 El workflow BB_00_Global_Error_Handler ha sido importado correctamente con ID: {workflow_id}")
    else:
        print("\n⚠️  Hubo un problema al importar el workflow.")
        sys.exit(1)