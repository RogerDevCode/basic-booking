#!/usr/bin/env python3
"""
Script de diagnóstico para verificar la conexión con n8n
"""

import requests
import os
import json

def diagnose_n8n_connection():
    api_url = "http://localhost:5678"
    api_key = os.environ.get('N8N_API_KEY') or os.environ.get('N8N_ACCESS_TOKEN')
    
    print("🔍 Diagnóstico de conexión con n8n")
    print(f"📍 URL: {api_url}")
    print(f"🔑 API Key disponible: {'Sí' if api_key else 'No'}")
    
    if not api_key:
        print("❌ No se encontró la API Key. Configura N8N_API_KEY o N8N_ACCESS_TOKEN")
        return
    
    # Headers comunes
    headers = {
        'X-N8N-API-Key': api_key,
        'Content-Type': 'application/json'
    }
    
    # 1. Probar endpoint raíz
    print("\n1️⃣ Probando endpoint raíz...")
    try:
        response = requests.get(f"{api_url}/", headers=headers)
        print(f"   Estado: {response.status_code}")
        if response.status_code == 200:
            print("   ✅ Acceso al dashboard permitido")
        else:
            print(f"   ❌ Error: {response.text}")
    except Exception as e:
        print(f"   ❌ Excepción: {e}")
    
    # 2. Probar endpoint de workflows
    print("\n2️⃣ Probando endpoint de workflows...")
    try:
        response = requests.get(f"{api_url}/api/v1/workflows", headers=headers)
        print(f"   Estado: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            workflows = data.get('data', [])
            print(f"   ✅ {len(workflows)} workflows encontrados")
        else:
            print(f"   ❌ Error: {response.text}")
    except Exception as e:
        print(f"   ❌ Excepción: {e}")
    
    # 3. Probar método HTTP permitido
    print("\n3️⃣ Probando métodos HTTP...")
    try:
        # Intentar con OPTIONS para ver qué métodos están permitidos
        response = requests.options(f"{api_url}/api/v1/workflows", headers=headers)
        print(f"   OPTIONS Estado: {response.status_code}")
        if 'allow' in response.headers:
            print(f"   Métodos permitidos: {response.headers['allow']}")
        
        # Intentar con GET
        response = requests.get(f"{api_url}/api/v1/workflows", headers=headers)
        print(f"   GET Estado: {response.status_code}")
        
        # Intentar con POST
        response = requests.post(f"{api_url}/api/v1/workflows", headers=headers, json={})
        print(f"   POST Estado: {response.status_code}")
        
    except Exception as e:
        print(f"   ❌ Excepción: {e}")
    
    # 4. Probar ejecución de workflow específica
    print("\n4️⃣ Probando ejecución de workflow...")
    try:
        # Primero obtener un workflow para probar
        response = requests.get(f"{api_url}/api/v1/workflows", headers=headers)
        if response.status_code == 200:
            workflows = response.json().get('data', [])
            if workflows:
                workflow_id = workflows[0]['id']
                print(f"   Probando con workflow: {workflow_id}")
                
                # Intentar ejecutarlo
                exec_response = requests.post(
                    f"{api_url}/api/v1/workflows/{workflow_id}/run", 
                    headers=headers,
                    json={}
                )
                print(f"   Estado ejecución: {exec_response.status_code}")
                if exec_response.status_code != 200:
                    print(f"   Detalle: {exec_response.text}")
            else:
                print("   ❌ No hay workflows para probar")
        else:
            print(f"   ❌ No se pudieron obtener workflows: {response.text}")
    except Exception as e:
        print(f"   ❌ Excepción: {e}")
    
    # 5. Probar con diferentes headers de autenticación
    print("\n5️⃣ Probando diferentes headers de autenticación...")
    auth_headers = [
        {'X-N8N-API-Key': api_key, 'Content-Type': 'application/json'},
        {'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'},
        {'X-Api-Key': api_key, 'Content-Type': 'application/json'}
    ]
    
    for i, auth_header in enumerate(auth_headers):
        try:
            response = requests.get(f"{api_url}/api/v1/workflows", headers=auth_header)
            print(f"   Tipo {i+1} - Estado: {response.status_code}")
        except Exception as e:
            print(f"   Tipo {i+1} - ❌ Excepción: {e}")

if __name__ == "__main__":
    diagnose_n8n_connection()