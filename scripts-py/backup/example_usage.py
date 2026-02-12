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
Example script demonstrating how to use the N8N CRUD Agent to create and manage workflows
"""

import json
import sys
import os

# Add the current directory to the path so we can import n8n_crud_agent
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from n8n_crud_agent import N8NCrudAgent


def create_example_workflow():
    # Configuration
    API_URL = "https://n8n.stax.ink"

    # Initialize the agent (will use N8N_API_KEY or N8N_ACCESS_TOKEN automatically)
    agent = N8NCrudAgent(API_URL)
    
    # Define a simple example workflow
    example_workflow = {
        "name": "Example Trigger Workflow",
        "nodes": [
            {
                "parameters": {},
                "id": "1c2cef1c-6cb0-46b8-bfd9-7e4b67dda1a3",
                "name": "My Trigger",
                "type": "n8n-nodes-base.manualTrigger",
                "typeVersion": 1,
                "position": [240, 300]
            },
            {
                "parameters": {
                    "values": {
                        "string": [
                            {
                                "name": "returnValue",
                                "value": "={{$json.input1}}"
                            }
                        ]
                    },
                    "options": {}
                },
                "id": "5f5a1e2c-5e4d-452e-b623-74413451399c",
                "name": "Set node",
                "type": "n8n-nodes-base.set",
                "typeVersion": 1,
                "position": [460, 300]
            }
        ],
        "connections": {
            "My Trigger": {
                "main": [
                    [
                        {
                            "node": "Set node",
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
    
    print("Creating example workflow...")
    created_workflow = agent.create_workflow(example_workflow)
    
    if created_workflow:
        workflow_id = created_workflow.get('id')
        workflow_name = created_workflow.get('name')
        print(f"✓ Successfully created workflow: '{workflow_name}' with ID: {workflow_id}")
        
        # Optionally activate the workflow
        print(f"Activating workflow {workflow_id}...")
        if agent.activate_workflow(workflow_id):
            print(f"✓ Successfully activated workflow: {workflow_name}")
        else:
            print(f"✗ Failed to activate workflow: {workflow_name}")
        
        # List all workflows again to confirm
        print("\n--- All workflows after creation ---")
        workflows = agent.list_workflows()
        if workflows:
            for wf in workflows:
                status = "ACTIVE" if wf.get('active', False) else "INACTIVE"
                print(f"  - ID: {wf.get('id')} | Name: {wf.get('name')} | Status: {status}")
        
        # Show how to update the workflow
        print(f"\n--- Updating workflow {workflow_id} ---")
        update_data = {
            "name": f"Updated {workflow_name}",
            "active": False  # Keep it inactive after update
        }
        updated_workflow = agent.update_workflow(workflow_id, update_data)
        if updated_workflow:
            print(f"✓ Successfully updated workflow to: '{updated_workflow.get('name')}'")
        else:
            print("✗ Failed to update workflow")
        
        # Demonstrate getting a specific workflow
        print(f"\n--- Getting workflow by ID: {workflow_id} ---")
        retrieved_workflow = agent.get_workflow_by_id(workflow_id)
        if retrieved_workflow:
            print(f"✓ Retrieved workflow: '{retrieved_workflow.get('name')}'")
        else:
            print("✗ Failed to retrieve workflow")
        
        # Show how to deactivate the workflow
        print(f"\n--- Deactivating workflow {workflow_id} ---")
        if agent.deactivate_workflow(workflow_id):
            print(f"✓ Successfully deactivated workflow: {workflow_name}")
        else:
            print(f"✗ Failed to deactivate workflow: {workflow_name}")
        
        # Option to delete the workflow (commented out to prevent accidental deletion)
        # print(f"\n--- Deleting workflow {workflow_id} ---")
        # if agent.delete_workflow(workflow_id):
        #     print(f"✓ Successfully deleted workflow: {workflow_name}")
        # else:
        #     print(f"✗ Failed to delete workflow: {workflow_name}")
        
    else:
        print("✗ Failed to create workflow")


if __name__ == "__main__":
    create_example_workflow()