#!/usr/bin/env python3

# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

"""
Script to execute the workflow manually
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


def execute_workflow_manually():
    """
    Execute the workflow manually using the manual trigger
    """
    # Configuration
    API_URL = "https://n8n.stax.ink"
    API_KEY = get_api_key()

    headers = {
        'X-N8N-API-Key': API_KEY,
        'Content-Type': 'application/json'
    }

    # Get the workflow to identify the manual trigger node
    response = requests.get(f"{API_URL}/api/v1/workflows", headers=headers)

    if response.status_code != 200:
        print(f"Error getting workflows: {response.status_code} - {response.text}")
        return

    workflows_data = response.json()
    workflows = workflows_data.get('data', [])

    # Find our specific workflow
    target_workflow = None
    for wf in workflows:
        if wf.get('name') == 'Ejemplo: Análisis de Datos con Pandas y Numpy':
            target_workflow = wf
            break

    if not target_workflow:
        print("Target workflow not found!")
        return

    workflow_id = target_workflow['id']
    print(f"Found workflow '{target_workflow['name']}' with ID: {workflow_id}")

    # Execute the workflow by triggering the manual trigger
    # The endpoint for manual execution is typically POST to /webhook/<webhook-id> or using the execute endpoint
    try:
        # Try to execute using the workflow execution endpoint
        exec_response = requests.post(
            f"{API_URL}/api/v1/workflows/{workflow_id}/run",
            headers=headers
        )

        if exec_response.status_code == 200:
            execution_data = exec_response.json()
            print("Workflow executed successfully!")
            print(json.dumps(execution_data, indent=2))
        else:
            print(f"Failed to execute workflow via run endpoint: {exec_response.status_code} - {exec_response.text}")

            # Alternative: try to trigger via webhook if available
            nodes = target_workflow.get('nodes', [])
            webhook_node = None

            for node in nodes:
                if node.get('type') == 'n8n-nodes-base.manualTrigger':
                    print(f"Found manual trigger node: {node.get('name')}")
                    # For manual triggers, we usually just need to call the execute endpoint
                    break
                elif node.get('type') == 'n8n-nodes-base.webhook':
                    webhook_node = node
                    print(f"Found webhook node: {node.get('name')}, ID: {node.get('webhookId')}")

            if webhook_node:
                # Try calling the webhook endpoint
                webhook_id = webhook_node.get('webhookId')
                webhook_response = requests.post(
                    f"{API_URL}/webhook/{webhook_id}",
                    headers={'Content-Type': 'application/json'},
                    json={}  # Empty body for the trigger
                )

                if webhook_response.status_code in [200, 202]:
                    print("Workflow triggered via webhook successfully!")
                    print(f"Response: {webhook_response.status_code}")
                else:
                    print(f"Failed to trigger via webhook: {webhook_response.status_code} - {webhook_response.text}")

    except Exception as e:
        print(f"Error executing workflow: {str(e)}")


def get_recent_executions(workflow_id):
    """
    Get recent executions for the workflow
    """
    API_URL = "https://n8n.stax.ink"
    API_KEY = get_api_key()

    headers = {
        'X-N8N-API-Key': API_KEY,
        'Content-Type': 'application/json'
    }

    try:
        response = requests.get(
            f"{API_URL}/api/v1/executions?filter={{\"workflowId\":\"{workflow_id}\"}}&limit=5",
            headers=headers
        )

        if response.status_code == 200:
            executions_data = response.json()
            executions = executions_data.get('data', {}).get('results', [])

            print(f"\nRecent executions for workflow {workflow_id}:")
            for i, execution in enumerate(executions):
                print(f"  Execution {i+1}:")
                print(f"    ID: {execution.get('id')}")
                print(f"    Status: {execution.get('status')}")
                print(f"    Started: {execution.get('startedAt')}")
                print(f"    Ended: {execution.get('stoppedAt')}")
                print(f"    Mode: {execution.get('mode')}")

                # Print the data if available
                execution_data = execution.get('data')
                if execution_data:
                    print(f"    Data: {json.dumps(execution_data, indent=4)[:500]}...")  # Truncate long output
        else:
            print(f"Failed to get executions: {response.status_code} - {response.text}")

    except Exception as e:
        print(f"Error getting executions: {str(e)}")


if __name__ == "__main__":
    print("Executing workflow 'Ejemplo: Análisis de Datos con Pandas y Numpy'...")
    execute_workflow_manually()

    # Get the workflow ID again to fetch recent executions
    API_URL = "https://n8n.stax.ink"
    API_KEY = get_api_key()

    headers = {
        'X-N8N-API-Key': API_KEY,
        'Content-Type': 'application/json'
    }

    response = requests.get(f"{API_URL}/api/v1/workflows", headers=headers)
    if response.status_code == 200:
        workflows_data = response.json()
        workflows = workflows_data.get('data', [])

        for wf in workflows:
            if wf.get('name') == 'Ejemplo: Análisis de Datos con Pandas y Numpy':
                get_recent_executions(wf['id'])
                break