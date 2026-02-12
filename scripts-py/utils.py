#!/usr/bin/env python3

# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

"""
Utility functions for n8n workflow management
"""

import json
import sys
import os
from typing import Dict, List, Optional

# Add the current directory to the path so we can import n8n_crud_agent
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from n8n_crud_agent import N8NCrudAgent


def list_workflows_simple(api_url: str = "https://n8n.stax.ink"):
    """
    Simple function to list all workflows
    """
    agent = N8NCrudAgent(api_url)
    
    print("Fetching all workflows from n8n...")
    print(f"URL: {api_url}")

    all_workflows = agent.list_workflows()

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
                    print(f"   To activate this workflow, use: agent.activate_workflow('{workflow_id}')")
        else:
            print("\nNo workflows found in the n8n instance.")
    else:
        print("\nFailed to retrieve workflows.")


def list_active_workflows_simple(api_url: str = "https://n8n.stax.ink"):
    """
    Simple function to list active workflows
    """
    agent = N8NCrudAgent(api_url)
    
    print("Fetching active workflows from n8n...")
    print(f"URL: {api_url}")

    active_workflows = agent.list_active_workflows()

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


def activate_workflow_simple(workflow_id: str, api_url: str = "https://n8n.stax.ink"):
    """
    Simple function to activate a specific workflow
    """
    agent = N8NCrudAgent(api_url)

    print(f"Attempting to activate workflow {workflow_id}...")
    print(f"URL: {api_url}")

    success = agent.activate_workflow(workflow_id)

    if success:
        print(f"\n✓ Workflow {workflow_id} has been successfully activated!")

        # Verify the activation
        print(f"\nVerifying activation status...")
        try:
            workflow_data = agent.get_workflow_by_id(workflow_id)
            if workflow_data:
                is_active = workflow_data.get('active', False)
                workflow_name = workflow_data.get('name', 'Unknown')
                print(f"✓ Verification: Workflow '{workflow_name}' (ID: {workflow_id}) is {'ACTIVE' if is_active else 'INACTIVE'}")
            else:
                print(f"✗ Could not verify activation status: Workflow not found")
        except Exception as e:
            print(f"✗ Could not verify activation status: {str(e)}")
    else:
        print(f"\n✗ Failed to activate workflow {workflow_id}")


def create_and_activate_workflow_with_trigger(workflow_name: str, api_url: str = "https://n8n.stax.ink"):
    """
    Create a new workflow with a proper trigger and then activate it
    """
    import uuid
    
    agent = N8NCrudAgent(api_url)

    # Define a workflow with a proper trigger
    workflow_data = {
        "name": workflow_name,
        "nodes": [
            {
                "parameters": {},
                "id": f"trigger-{uuid.uuid4().hex[:8]}",
                "name": "Schedule Trigger",
                "type": "n8n-nodes-base.scheduleTrigger",
                "typeVersion": 1,
                "position": [240, 300]
            },
            {
                "parameters": {
                    "values": {
                        "string": [
                            {
                                "name": "message",
                                "value": "Hello from scheduled workflow!"
                            }
                        ]
                    }
                },
                "id": f"set-{uuid.uuid4().hex[:8]}",
                "name": "Set Node",
                "type": "n8n-nodes-base.set",
                "typeVersion": 1,
                "position": [460, 300]
            }
        ],
        "connections": {
            "Schedule Trigger": {
                "main": [
                    [
                        {
                            "node": "Set Node",
                            "type": "main",
                            "index": 0
                        }
                    ]
                ]
            }
        },
        "settings": {
            "saveManualExecutions": True
        }
    }

    print(f"Creating new workflow with proper trigger: {workflow_name}")

    # Create a new workflow with a proper trigger
    created_workflow = agent.create_workflow(workflow_data)

    if created_workflow:
        workflow_id = created_workflow.get('id')

        print(f"\nAttempting to activate workflow {workflow_id}...")
        success = agent.activate_workflow(workflow_id)

        if success:
            print(f"\n✓ Workflow '{workflow_name}' (ID: {workflow_id}) has been successfully created AND activated!")

            # Verify the activation
            try:
                workflow_data = agent.get_workflow_by_id(workflow_id)
                if workflow_data:
                    is_active = workflow_data.get('active', False)
                    workflow_name = workflow_data.get('name', 'Unknown')
                    print(f"✓ Verification: Workflow '{workflow_name}' is {'ACTIVE' if is_active else 'INACTIVE'}")
                else:
                    print(f"✗ Could not verify activation status: Workflow not found")
            except Exception as e:
                print(f"✗ Could not verify activation status: {str(e)}")
        else:
            print(f"\n✗ Failed to activate workflow {workflow_id}")
    else:
        print("✗ Failed to create workflow")


def execute_workflow_manually(workflow_id: str, api_url: str = "https://n8n.stax.ink"):
    """
    Execute a workflow manually
    """
    agent = N8NCrudAgent(api_url)
    
    print(f"Executing workflow {workflow_id} manually...")
    
    result = agent.execute_workflow(workflow_id)
    
    if result:
        print("Workflow executed successfully!")
        print(json.dumps(result, indent=2))
    else:
        print(f"Failed to execute workflow {workflow_id}")


def get_recent_executions(workflow_id: str, limit: int = 5, api_url: str = "https://n8n.stax.ink"):
    """
    Get recent executions for a workflow
    """
    agent = N8NCrudAgent(api_url)
    
    print(f"\nRecent executions for workflow {workflow_id}:")
    
    executions = agent.get_executions(workflow_id, limit)
    
    if executions:
        for i, execution in enumerate(executions):
            print(f"  Execution {i+1}:")
            print(f"    ID: {execution.get('id')}")
            print(f"    Status: {execution.get('status')}")
            print(f"    Started: {execution.get('startedAt')}")
            print(f"    Ended: {execution.get('stoppedAt')}")
            print(f"    Mode: {execution.get('mode')}")
    else:
        print(f"No executions found for workflow {workflow_id}")


def load_workflow_from_json(file_path: str) -> Dict:
    """
    Load workflow from JSON file

    Args:
        file_path: Path to the JSON file containing the workflow

    Returns:
        Workflow data as dictionary
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        workflow_data = json.load(f)
    return workflow_data


def execute_workflow_from_json(file_path: str, api_url: str = "https://n8n.stax.ink"):
    """
    Execute the workflow from the JSON file
    """
    agent = N8NCrudAgent(api_url)
    
    # Load the workflow from the JSON file
    print("Loading workflow from JSON file...")
    workflow_data = load_workflow_from_json(file_path)

    # Extract workflow ID from the loaded data
    workflow_id = workflow_data.get('id')

    if not workflow_id:
        print("Error: Workflow ID not found in JSON file.")
        return

    print(f"Loaded workflow: {workflow_data.get('name', 'Unknown')}")

    # Create the workflow in n8n
    print("\nCreating workflow in n8n...")
    created_workflow = agent.create_workflow(workflow_data)

    if not created_workflow:
        print(f"Error creating workflow")
        return

    workflow_id = created_workflow["id"]
    workflow_name = created_workflow["name"]

    print(f"Workflow created successfully!")
    print(f"ID: {workflow_id}")
    print(f"Name: {workflow_name}")

    # Activate the workflow to make it executable
    print(f"\nActivating workflow {workflow_id}...")
    activation_success = agent.activate_workflow(workflow_id)

    if not activation_success:
        print(f"Error activating workflow")
        print("Note: This workflow may require a trigger node to be activated.")
    else:
        print("Workflow activated successfully!")

    # Get the workflow details to confirm it was created correctly
    print(f"\nGetting workflow details for {workflow_id}...")
    workflow_info = agent.get_workflow_by_id(workflow_id)

    if workflow_info:
        print(f"Workflow retrieved successfully:")
        print(f"  Name: {workflow_info.get('name')}")
        print(f"  Active: {workflow_info.get('active', False)}")
        print(f"  Trigger Count: {workflow_info.get('triggerCount', 0)}")
    else:
        print(f"Error getting workflow details")