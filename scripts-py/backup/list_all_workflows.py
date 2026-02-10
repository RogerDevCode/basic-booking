#!/usr/bin/env python3
"""
Script to list all workflows (active and inactive) in n8n instance
"""

import requests
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional


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


def list_all_workflows(api_url: str, api_key: str) -> Optional[List[Dict]]:
    """
    Fetch and return all workflows from n8n instance

    Args:
        api_url: Base URL of the n8n instance
        api_key: API key for authentication

    Returns:
        List of all workflows or None if error occurs
    """
    # Authentication using X-N8N-API-Key header
    headers = {
        'X-N8N-API-Key': api_key,
        'Content-Type': 'application/json'
    }

    try:
        # Get all workflows using the correct API endpoint
        response = requests.get(f"{api_url}/api/v1/workflows", headers=headers)

        # Check if the request was successful
        if response.status_code == 200:
            try:
                workflows_data = response.json()

                # Extract workflows from the response
                workflows = workflows_data.get('data', []) if isinstance(workflows_data, dict) else workflows_data

                return workflows
            except json.JSONDecodeError:
                print("Error: Could not parse the response as JSON.")
                return None
        elif response.status_code == 401:
            print("Error: Unauthorized. Please check your API key.")
            print("Note: Make sure the API key is correctly set in n8n settings.")
            return None
        elif response.status_code == 403:
            print("Error: Forbidden. Your API key may not have sufficient permissions.")
            return None
        else:
            print(f"Error: Received status code {response.status_code}")
            print(f"Response: {response.text}")
            return None

    except requests.exceptions.ConnectionError:
        print("Error: Could not connect to n8n instance. Please check if n8n is running at the specified URL.")
        return None
    except requests.exceptions.Timeout:
        print("Error: Request timed out. Please check your connection to the n8n instance.")
        return None
    except requests.exceptions.RequestException as e:
        print(f"Error: An unexpected error occurred while making the request: {str(e)}")
        return None


def main():
    # Configuration
    API_URL = "http://localhost:5678"
    API_KEY = get_api_key()

    print("Fetching all workflows from n8n...")
    print(f"URL: {API_URL}")

    all_workflows = list_all_workflows(API_URL, API_KEY)

    if all_workflows is not None:
        if len(all_workflows) > 0:
            print(f"\nFound {len(all_workflows)} workflow(s):\n")
            for idx, workflow in enumerate(all_workflows, 1):
                workflow_id = workflow.get('id', 'Unknown ID')
                workflow_name = workflow.get('name', 'Unnamed Workflow')
                workflow_active = workflow.get('active', False)
                status = "ACTIVE" if workflow_active else "INACTIVE"
                print(f"{idx}. ID: {workflow_id} | Name: {workflow_name} | Status: {status}")

                # If workflow is inactive, suggest activation
                if not workflow_active:
                    print(f"   To activate this workflow, use: activate_workflow('{workflow_id}')")
        else:
            print("\nNo workflows found in the n8n instance.")
    else:
        print("\nFailed to retrieve workflows.")


if __name__ == "__main__":
    main()