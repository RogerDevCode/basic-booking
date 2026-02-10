#!/usr/bin/env python3
"""
Script to activate a specific workflow in n8n instance
"""

import requests
import json
import os
import sys
from pathlib import Path


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


def activate_workflow(api_url: str, api_key: str, workflow_id: str) -> bool:
    """
    Activate a workflow in n8n instance

    Args:
        api_url: Base URL of the n8n instance
        api_key: API key for authentication
        workflow_id: ID of the workflow to activate

    Returns:
        True if activation was successful, False otherwise
    """
    # Authentication using X-N8N-API-Key header
    headers = {
        'X-N8N-API-Key': api_key,
        'Content-Type': 'application/json'
    }

    try:
        # Activate the workflow
        response = requests.post(f"{api_url}/api/v1/workflows/{workflow_id}/activate", headers=headers)

        # Check if the request was successful
        if response.status_code == 200:
            print(f"✓ Successfully activated workflow {workflow_id}")
            return True
        elif response.status_code == 400:
            error_msg = response.json().get('message', 'Unknown error') if response.content else 'No response body'
            print(f"✗ Failed to activate workflow {workflow_id}: {error_msg}")
            return False
        elif response.status_code == 401:
            print("✗ Error: Unauthorized. Please check your API key.")
            return False
        elif response.status_code == 403:
            print("✗ Error: Forbidden. Your API key may not have sufficient permissions.")
            return False
        else:
            print(f"✗ Error: Received status code {response.status_code}")
            print(f"Response: {response.text}")
            return False

    except requests.exceptions.ConnectionError:
        print("✗ Error: Could not connect to n8n instance. Please check if n8n is running at the specified URL.")
        return False
    except requests.exceptions.Timeout:
        print("✗ Error: Request timed out. Please check your connection to the n8n instance.")
        return False
    except requests.exceptions.RequestException as e:
        print(f"✗ Error: An unexpected error occurred while making the request: {str(e)}")
        return False


def main():
    # Configuration
    API_URL = "http://localhost:5678"
    API_KEY = get_api_key()

    # Workflow ID to activate (the first one from our previous listing)
    WORKFLOW_ID = "V2TftD82S1qlpkCf"  # Example Trigger Workflow

    print(f"Attempting to activate workflow {WORKFLOW_ID}...")
    print(f"URL: {API_URL}")

    success = activate_workflow(API_URL, API_KEY, WORKFLOW_ID)

    if success:
        print(f"\n✓ Workflow {WORKFLOW_ID} has been successfully activated!")

        # Verify the activation
        print(f"\nVerifying activation status...")
        headers = {
            'X-N8N-API-Key': API_KEY,
            'Content-Type': 'application/json'
        }

        try:
            response = requests.get(f"{API_URL}/api/v1/workflows/{WORKFLOW_ID}", headers=headers)
            if response.status_code == 200:
                workflow_data = response.json()
                is_active = workflow_data.get('active', False)
                workflow_name = workflow_data.get('name', 'Unknown')
                print(f"✓ Verification: Workflow '{workflow_name}' (ID: {WORKFLOW_ID}) is {'ACTIVE' if is_active else 'INACTIVE'}")
            else:
                print(f"✗ Could not verify activation status: {response.status_code}")
        except Exception as e:
            print(f"✗ Could not verify activation status: {str(e)}")
    else:
        print(f"\n✗ Failed to activate workflow {WORKFLOW_ID}")


if __name__ == "__main__":
    main()