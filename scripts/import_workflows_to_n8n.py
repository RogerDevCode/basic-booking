#!/usr/bin/env python3
"""
Script para importar workflows desde archivos JSON al servidor n8n
Este script incluye instrucciones para configurar n8n si es necesario
"""

import json
import os
import sys
from pathlib import Path
import subprocess
import time

def check_n8n_status():
    """
    Checks if n8n is running and accessible
    """
    try:
        response = subprocess.run(['curl', '-s', 'http://localhost:5678/healthz'], 
                                  capture_output=True, text=True, timeout=10)
        if "ok" in response.stdout:
            print("✓ n8n service is running and accessible")
            return True
        else:
            print("✗ n8n service is not responding correctly")
            return False
    except Exception as e:
        print(f"✗ Error checking n8n status: {e}")
        return False

def setup_instructions():
    """
    Provides instructions for setting up n8n
    """
    print("=" * 70)
    print("SETUP INSTRUCTIONS FOR N8N")
    print("=" * 70)
    print("\nBefore you can import workflows, you need to set up your n8n instance:")
    print("\n1. Open your browser and navigate to: http://localhost:5678")
    print("2. Follow the initial setup wizard to create your first user account")
    print("3. After creating your account, go to 'User Settings' > 'API' tab")
    print("4. Click 'Create API Key' and copy the generated key")
    print("5. Set the N8N_API_KEY or N8N_ACCESS_TOKEN environment variable with the key:")
    print("   export N8N_API_KEY=your_api_key_here")
    print("\nAfter completing these steps, run this script again.")
    print("=" * 70)

def import_workflows_from_directory(directory_path):
    """
    Importa todos los archivos JSON de workflows desde un directorio al servidor n8n
    
    Args:
        directory_path (str): Ruta al directorio que contiene los archivos JSON de workflows
    """
    # Agregar el directorio scripts-py al path para importar el módulo
    sys.path.append('/home/manager/Sync/N8N Projects/basic-booking/scripts-py')
    
    try:
        from qwen_n8n_plugin import qwen_n8n_plugin
    except ImportError as e:
        print(f"Error importing qwen_n8n_plugin: {e}")
        print("Make sure you have set up the N8N_API_KEY or N8N_ACCESS_TOKEN environment variable")
        return
    
    workflows_dir = Path(directory_path)
    
    # Verificar que el directorio existe
    if not workflows_dir.exists():
        print(f"Error: El directorio {directory_path} no existe")
        return
    
    # Obtener todos los archivos JSON en el directorio
    workflow_files = list(workflows_dir.glob("*.json"))
    
    if not workflow_files:
        print(f"No se encontraron archivos JSON en {directory_path}")
        return
    
    print(f"Encontrados {len(workflow_files)} archivos de workflow para importar:")
    
    # Importar cada archivo
    for workflow_file in workflow_files:
        print(f"\nImportando {workflow_file.name}...")
        
        try:
            # Leer el contenido del archivo JSON
            with open(workflow_file, 'r', encoding='utf-8') as f:
                workflow_data = json.load(f)
            
            # Crear el workflow en n8n
            result = qwen_n8n_plugin("create_workflow", workflow_data=workflow_data)
            result_dict = json.loads(result)
            
            if result_dict.get("success"):
                workflow_id = result_dict.get("data", {}).get("id")
                workflow_name = result_dict.get("data", {}).get("name", "Unknown")
                print(f"✓ {workflow_file.name} importado exitosamente")
                print(f"  - ID: {workflow_id}")
                print(f"  - Nombre: {workflow_name}")
                
                # Opcional: Activar el workflow después de importarlo
                if workflow_id:
                    activation_result = qwen_n8n_plugin("activate_workflow", workflow_id=workflow_id)
                    activation_dict = json.loads(activation_result)
                    
                    if activation_dict.get("success"):
                        print(f"  - Workflow activado exitosamente")
                    else:
                        print(f"  - Advertencia: No se pudo activar el workflow: {activation_dict.get('error')}")
            else:
                print(f"✗ Error al importar {workflow_file.name}: {result_dict.get('error')}")
                
        except json.JSONDecodeError as e:
            print(f"✗ Error al decodificar JSON en {workflow_file.name}: {e}")
        except Exception as e:
            print(f"✗ Error al importar {workflow_file.name}: {e}")

def main():
    # Directorio de workflows
    workflows_dir = "/home/manager/Sync/N8N Projects/basic-booking/workflows/"
    
    print("Verifying n8n service status...")
    if not check_n8n_status():
        print("n8n service is not accessible. Please ensure it's running.")
        return
    
    # Check if API key is configured in environment variables
    api_key_configured = os.environ.get('N8N_API_KEY') or os.environ.get('N8N_ACCESS_TOKEN')

    if not api_key_configured:
        print("API key not configured. Initiating setup process...")
        setup_instructions()
        return
    
    print("API key is configured. Starting workflow import...")
    print(f"Directorio de origen: {workflows_dir}")
    
    # Importar los workflows
    import_workflows_from_directory(workflows_dir)
    
    print("\nProceso de importación completado.")


if __name__ == "__main__":
    main()