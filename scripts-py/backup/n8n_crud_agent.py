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
N8N CRUD Agent - Performs Create, Read, Update, Delete operations on n8n workflows
"""

import requests
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional, Union


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


class N8NCrudAgent:
    def __init__(self, api_url: str, api_key: str = None):
        """
        Initialize the N8N CRUD Agent

        Args:
            api_url: Base URL of the n8n instance
            api_key: API key for authentication (optional, will use N8N_ACCESS_TOKEN if not provided)
        """
        if not api_key:
            api_key = get_api_key()
            
        self.api_url = api_url.rstrip('/')
        self.api_key = api_key
        self.headers = {
            'X-N8N-API-Key': api_key,
            'Content-Type': 'application/json'
        }
    
    def list_workflows(self) -> Optional[List[Dict]]:
        """
        Retrieve all workflows from n8n instance
        
        Returns:
            List of workflows or None if error occurs
        """
        try:
            response = requests.get(f"{self.api_url}/api/v1/workflows", headers=self.headers)
            
            if response.status_code == 200:
                workflows_data = response.json()
                workflows = workflows_data.get('data', [])
                return workflows
            else:
                print(f"Error retrieving workflows: {response.status_code} - {response.text}")
                return None
        except Exception as e:
            print(f"Error connecting to n8n: {str(e)}")
            return None
    
    def list_active_workflows(self) -> Optional[List[Dict]]:
        """
        Retrieve all active workflows from n8n instance
        
        Returns:
            List of active workflows or None if error occurs
        """
        try:
            response = requests.get(f"{self.api_url}/api/v1/workflows", headers=self.headers)
            
            if response.status_code == 200:
                workflows_data = response.json()
                workflows = workflows_data.get('data', [])
                
                # Filter for active workflows only
                active_workflows = [wf for wf in workflows if wf.get('active', False)]
                return active_workflows
            else:
                print(f"Error retrieving workflows: {response.status_code} - {response.text}")
                return None
        except Exception as e:
            print(f"Error connecting to n8n: {str(e)}")
            return None
    
    def get_workflow_by_id(self, workflow_id: str) -> Optional[Dict]:
        """
        Retrieve a specific workflow by ID
        
        Args:
            workflow_id: ID of the workflow to retrieve
            
        Returns:
            Workflow data or None if error occurs
        """
        try:
            response = requests.get(f"{self.api_url}/api/v1/workflows/{workflow_id}", headers=self.headers)
            
            if response.status_code == 200:
                workflow = response.json()
                return workflow
            else:
                print(f"Error retrieving workflow {workflow_id}: {response.status_code} - {response.text}")
                return None
        except Exception as e:
            print(f"Error connecting to n8n: {str(e)}")
            return None
    
    def create_workflow(self, workflow_data: Dict) -> Optional[Dict]:
        """
        Create a new workflow in n8n
        
        Args:
            workflow_data: Dictionary containing workflow definition
            
        Returns:
            Created workflow data or None if error occurs
        """
        try:
            response = requests.post(f"{self.api_url}/api/v1/workflows", 
                                   headers=self.headers, 
                                   json=workflow_data)
            
            if response.status_code in [200, 201]:
                created_workflow = response.json()
                return created_workflow
            else:
                print(f"Error creating workflow: {response.status_code} - {response.text}")
                return None
        except Exception as e:
            print(f"Error connecting to n8n: {str(e)}")
            return None
    
    def update_workflow(self, workflow_id: str, workflow_data: Dict) -> Optional[Dict]:
        """
        Update an existing workflow in n8n

        Args:
            workflow_id: ID of the workflow to update
            workflow_data: Dictionary containing updated workflow definition

        Returns:
            Updated workflow data or None if error occurs
        """
        try:
            # Try PUT method first (some APIs use PUT instead of PATCH)
            response = requests.put(f"{self.api_url}/api/v1/workflows/{workflow_id}",
                                  headers=self.headers,
                                  json=workflow_data)

            if response.status_code == 200:
                updated_workflow = response.json()
                return updated_workflow
            elif response.status_code == 405:  # Method not allowed
                # Try PATCH method as fallback
                response = requests.patch(f"{self.api_url}/api/v1/workflows/{workflow_id}",
                                        headers=self.headers,
                                        json=workflow_data)
                if response.status_code == 200:
                    updated_workflow = response.json()
                    return updated_workflow
                else:
                    print(f"Error updating workflow {workflow_id} with PATCH: {response.status_code} - {response.text}")
                    return None
            else:
                print(f"Error updating workflow {workflow_id} with PUT: {response.status_code} - {response.text}")
                return None
        except Exception as e:
            print(f"Error connecting to n8n: {str(e)}")
            return None
    
    def delete_workflow(self, workflow_id: str) -> bool:
        """
        Delete a workflow from n8n
        
        Args:
            workflow_id: ID of the workflow to delete
            
        Returns:
            True if deletion was successful, False otherwise
        """
        try:
            response = requests.delete(f"{self.api_url}/api/v1/workflows/{workflow_id}", 
                                     headers=self.headers)
            
            if response.status_code == 200:
                return True
            else:
                print(f"Error deleting workflow {workflow_id}: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            print(f"Error connecting to n8n: {str(e)}")
            return False
    
    def activate_workflow(self, workflow_id: str) -> bool:
        """
        Activate a workflow in n8n (publish the workflow)

        Args:
            workflow_id: ID of the workflow to activate

        Returns:
            True if activation was successful, False otherwise
        """
        try:
            response = requests.post(f"{self.api_url}/api/v1/workflows/{workflow_id}/activate",
                                   headers=self.headers)

            if response.status_code == 200:
                return True
            elif response.status_code == 400:
                # Check if it's because there's no trigger node
                try:
                    error_data = response.json()
                    print(f"Error activating workflow {workflow_id}: {error_data.get('message', response.text)}")
                except:
                    print(f"Error activating workflow {workflow_id}: {response.status_code} - {response.text}")
                return False
            else:
                print(f"Error activating workflow {workflow_id}: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            print(f"Error connecting to n8n: {str(e)}")
            return False

    def deactivate_workflow(self, workflow_id: str) -> bool:
        """
        Deactivate a workflow in n8n (unpublish the workflow)

        Args:
            workflow_id: ID of the workflow to deactivate

        Returns:
            True if deactivation was successful, False otherwise
        """
        try:
            response = requests.post(f"{self.api_url}/api/v1/workflows/{workflow_id}/deactivate",
                                   headers=self.headers)

            if response.status_code == 200:
                return True
            else:
                print(f"Error deactivating workflow {workflow_id}: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            print(f"Error connecting to n8n: {str(e)}")
            return False

    def publish_workflow(self, workflow_id: str) -> bool:
        """
        Publish a workflow (alias for activate_workflow)

        Args:
            workflow_id: ID of the workflow to publish

        Returns:
            True if publishing was successful, False otherwise
        """
        return self.activate_workflow(workflow_id)

    def unpublish_workflow(self, workflow_id: str) -> bool:
        """
        Unpublish a workflow (alias for deactivate_workflow)

        Args:
            workflow_id: ID of the workflow to unpublish

        Returns:
            True if unpublishing was successful, False otherwise
        """
        return self.deactivate_workflow(workflow_id)


def main():
    # Configuration
    API_URL = "https://n8n.stax.ink"

    # Initialize the agent (will use N8N_ACCESS_TOKEN automatically)
    agent = N8NCrudAgent(API_URL)

    print("N8N CRUD Agent initialized")
    print(f"Connected to: {API_URL}")

    # Example operations
    print("\n--- Available Operations ---")
    print("1. List all workflows")
    print("2. List active workflows")
    print("3. Get workflow by ID")
    print("4. Create a new workflow")
    print("5. Update a workflow")
    print("6. Delete a workflow")
    print("7. Activate a workflow")
    print("8. Deactivate a workflow")

    # Example: List all workflows
    print("\n--- Listing all workflows ---")
    workflows = agent.list_workflows()
    if workflows:
        print(f"Found {len(workflows)} workflow(s):")
        for wf in workflows:
            status = "ACTIVE" if wf.get('active', False) else "INACTIVE"
            print(f"  - ID: {wf.get('id')} | Name: {wf.get('name')} | Status: {status}")
    else:
        print("No workflows found or error occurred.")

    # Example: List active workflows
    print("\n--- Listing active workflows ---")
    active_workflows = agent.list_active_workflows()
    if active_workflows:
        print(f"Found {len(active_workflows)} active workflow(s):")
        for wf in active_workflows:
            print(f"  - ID: {wf.get('id')} | Name: {wf.get('name')}")
    else:
        print("No active workflows found.")


if __name__ == "__main__":
    main()