#!/usr/bin/env python3

# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../scripts-py')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

"""
Script para importar workflows a n8n usando la API
"""
import os
import json
import requests
from pathlib import Path

def import_workflows():
    # Configurar la URL base de n8n
    n8n_url = "https://n8n.stax.ink"
    
    # Obtener el token de autenticación
    username = os.getenv("N8N_USERNAME", "admin")
    password = os.getenv("N8N_PASSWORD", "admin")
    
    # Crear sesión
    session = requests.Session()
    
    # Intentar iniciar sesión
    login_response = session.post(
        f"{n8n_url}/login",
        data={
            "email": username,
            "password": password
        }
    )
    
    if login_response.status_code != 200:
        print(f"No se pudo iniciar sesión: {login_response.status_code}")
        # Continuar sin autenticación si es una instancia sin autenticación
    
    # Directorio de workflows
    workflows_dir = Path("/home/manager/Sync/N8N Projects/basic-booking/workflows/")
    
    # Importar cada archivo JSON
    for workflow_file in workflows_dir.glob("*.json"):
        print(f"Importando {workflow_file.name}...")
        
        with open(workflow_file, 'r', encoding='utf-8') as f:
            workflow_data = json.load(f)
        
        # Enviar solicitud para crear el workflow
        headers = {
            "Content-Type": "application/json"
        }
        
        # Si hay un token de sesión, añadirlo al header
        if session.cookies:
            headers.update(dict(session.cookies))
        
        response = session.post(
            f"{n8n_url}/rest/workflows",
            headers=headers,
            json=workflow_data
        )
        
        if response.status_code in [200, 201]:
            print(f"✓ {workflow_file.name} importado exitosamente")
        else:
            print(f"✗ Error al importar {workflow_file.name}: {response.status_code} - {response.text}")

if __name__ == "__main__":
    import_workflows()