#!/usr/bin/env python3
"""
Script para verificar la conexión con n8n
"""

import sys
import os

# Agregar el directorio actual al path para importar el módulo
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from n8n_crud_agent import N8NCrudAgent
import requests


def test_connection():
    """
    Prueba la conexión con n8n
    """
    api_url = "http://localhost:5678"
    api_key = os.environ.get('N8N_API_KEY') or os.environ.get('N8N_ACCESS_TOKEN')

    print(f"URL de n8n: {api_url}")
    print(f"API Key disponible: {'Sí' if api_key else 'No'}")

    if not api_key:
        print("❌ No se encontró la clave de API. Por favor, verifica la configuración.")
        return
    
    # Crear el agente
    agent = N8NCrudAgent(api_url, api_key)
    
    # Probar la conexión con un comando simple
    try:
        # Intentar hacer una solicitud directa para ver qué tipo de respuesta obtenemos
        headers = {
            "X-N8N-API-KEY": api_key
        }
        
        response = requests.get(f"{api_url}/api/v1/workflows", headers=headers)
        print(f"Código de estado HTTP: {response.status_code}")
        print(f"Respuesta: {response.text}")
        
        # Intentar con el agente
        workflows = agent.list_workflows()
        print(f"Workflows obtenidos: {workflows}")
        
    except Exception as e:
        print(f"Error durante la prueba de conexión: {e}")


if __name__ == "__main__":
    test_connection()