#!/usr/bin/env python3
"""
Script to list all active workflows in n8n instance
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


def list_active_workflows(api_url: str, api_key: str) -> Optional[List[Dict]]:
    """
    Fetch and return all active workflows from n8n instance

    Args:
        api_url: Base URL of the n8n instance
        api_key: API key for authentication

    Returns:
        List of active workflows or None if error occurs
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

                # Filter for active workflows only
                active_workflows = [wf for wf in workflows if wf.get('active', False)]

                return active_workflows
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

    print("Fetching active workflows from n8n...")
    print(f"URL: {API_URL}")

    active_workflows = list_active_workflows(API_URL, API_KEY)

    if active_workflows is not None:
        if len(active_workflows) > 0:
            print(f"\nFound {len(active_workflows)} active workflow(s):\n")
            for idx, workflow in enumerate(active_workflows, 1):
                workflow_id = workflow.get('id', 'Unknown ID')
                workflow_name = workflow.get('name', 'Unnamed Workflow')
                print(f"{idx}. ID: {workflow_id} | Name: {workflow_name}")
        else:
            print("\nNo active workflows found.")
    else:
        print("\nFailed to retrieve workflows.")


if __name__ == "__main__":
    main()