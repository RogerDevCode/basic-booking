#!/usr/bin/env python3
"""
Script para cargar el workflow BB_00_Global_Error_Handler al servidor n8n
usando el agente Python con fallback automático
"""

import json
import os
import sys
from pathlib import Path

def load_bb00_workflow():
    """
    Loads the BB_00_Global_Error_Handler workflow to n8n server
    """
    # Add the scripts-py directory to the Python path
    sys.path.append('/home/manager/Sync/N8N Projects/basic-booking/scripts-py')
    
    try:
        from qwen_n8n_plugin import qwen_n8n_plugin
        
        # Read the workflow file
        workflow_path = Path("/home/manager/Sync/N8N Projects/basic-booking/workflows/BB_00_Global_Error_Handler.json")
        
        if not workflow_path.exists():
            print(f"Error: Workflow file not found at {workflow_path}")
            return False
            
        with open(workflow_path, 'r', encoding='utf-8') as f:
            workflow_data = json.load(f)
        
        print("Cargando el workflow BB_00_Global_Error_Handler...")
        
        # Try to create the workflow
        result = qwen_n8n_plugin("create_workflow", workflow_data=workflow_data)
        result_dict = json.loads(result)
        
        if result_dict.get("success"):
            workflow_id = result_dict.get("data", {}).get("id")
            workflow_name = result_dict.get("data", {}).get("name", "Unknown")
            print(f"✓ Workflow BB_00_Global_Error_Handler cargado exitosamente")
            print(f"  - ID: {workflow_id}")
            print(f"  - Nombre: {workflow_name}")
            
            # Try to activate the workflow
            if workflow_id:
                activation_result = qwen_n8n_plugin("activate_workflow", workflow_id=workflow_id)
                activation_dict = json.loads(activation_result)
                
                if activation_dict.get("success"):
                    print(f"  - Workflow activado exitosamente")
                    return True
                else:
                    print(f"  - Advertencia: No se pudo activar el workflow: {activation_dict.get('error')}")
                    return True
        else:
            print(f"✗ Error al cargar el workflow: {result_dict.get('error')}")
            return False
            
    except ImportError as e:
        print(f"Error importing qwen_n8n_plugin: {e}")
        print("Verifique que ha completado la configuración inicial de n8n")
        return False
    except FileNotFoundError:
        print("Archivo del workflow BB_00_Global_Error_Handler no encontrado")
        return False
    except json.JSONDecodeError as e:
        print(f"Error al decodificar el archivo JSON: {e}")
        return False
    except Exception as e:
        print(f"Error inesperado al cargar el workflow: {e}")
        return False

def main():
    print("Iniciando carga del workflow BB_00_Global_Error_Handler...")

    # Check if API key is configured in environment variables
    api_key_configured = os.environ.get('N8N_API_KEY') or os.environ.get('N8N_ACCESS_TOKEN')

    if not api_key_configured:
        print("Advertencia: No se ha configurado la variable de ambiente N8N_API_KEY o N8N_ACCESS_TOKEN")
        print("Siga las instrucciones para configurar n8n antes de continuar:")
        print("1. Abra http://localhost:5678 en su navegador")
        print("2. Complete el asistente de configuración inicial")
        print("3. Vaya a 'Configuración de Usuario' > pestaña 'API'")
        print("4. Haga clic en 'Crear clave API' y copie la clave generada")
        print("5. Defina la variable de ambiente N8N_API_KEY o N8N_ACCESS_TOKEN con la clave:")
        print("   export N8N_API_KEY=su_clave_aqui")
        return False
    
    success = load_bb00_workflow()
    
    if success:
        print("\n✓ El workflow BB_00_Global_Error_Handler se ha cargado correctamente")
    else:
        print("\n✗ Hubo un error al cargar el workflow BB_00_Global_Error_Handler")
    
    return success

if __name__ == "__main__":
    main()