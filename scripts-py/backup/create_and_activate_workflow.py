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
Script to create a new workflow with a proper trigger and then activate it
"""

import requests
import json
import uuid


def create_workflow_with_trigger(api_url: str, api_key: str, workflow_name: str):
    """
    Create a new workflow with a proper trigger node
    """
    headers = {
        'X-N8N-API-Key': api_key,
        'Content-Type': 'application/json'
    }
    
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
    
    try:
        response = requests.post(f"{api_url}/api/v1/workflows", headers=headers, json=workflow_data)
        
        if response.status_code in [200, 201]:
            created_workflow = response.json()
            print(f"✓ Successfully created workflow: '{created_workflow.get('name')}' with ID: {created_workflow.get('id')}")
            return created_workflow
        else:
            print(f"✗ Error creating workflow: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"✗ Error connecting to n8n: {str(e)}")
        return None


def activate_workflow(api_url: str, api_key: str, workflow_id: str) -> bool:
    """
    Activate a workflow in n8n instance
    """
    headers = {
        'X-N8N-API-Key': api_key,
        'Content-Type': 'application/json'
    }
    
    try:
        response = requests.post(f"{api_url}/api/v1/workflows/{workflow_id}/activate", headers=headers)

        if response.status_code == 200:
            print(f"✓ Successfully activated workflow {workflow_id}")
            return True
        elif response.status_code == 400:
            error_msg = response.json().get('message', 'Unknown error') if response.content else 'No response body'
            print(f"✗ Failed to activate workflow {workflow_id}: {error_msg}")
            return False
        else:
            print(f"✗ Error: Received status code {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return False


def main():
    # Configuration
    API_URL = "https://n8n.stax.ink"
    API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiYTA2MmZmOC04Mzc3LTRkZDMtOWQ5OS02ZmUwNDcxMzAzNGIiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiNDk4ZWZhOTctOWQ2MC00MjhiLWI1MzMtNTIxYzc2MDljOTBkIiwiaWF0IjoxNzcwMjEyNDY4fQ.50HHi-XfoG8ISAn4rIZbMkYmoVSEqcYofVMmvVQeXcE"
    
    workflow_name = f"Automatically Activated Workflow {uuid.uuid4().hex[:8]}"
    
    print(f"Creating new workflow with proper trigger: {workflow_name}")
    
    # Create a new workflow with a proper trigger
    created_workflow = create_workflow_with_trigger(API_URL, API_KEY, workflow_name)
    
    if created_workflow:
        workflow_id = created_workflow.get('id')
        
        print(f"\nAttempting to activate workflow {workflow_id}...")
        success = activate_workflow(API_URL, API_KEY, workflow_id)
        
        if success:
            print(f"\n✓ Workflow '{workflow_name}' (ID: {workflow_id}) has been successfully created AND activated!")
            
            # Verify the activation
            headers = {
                'X-N8N-API-Key': API_KEY,
                'Content-Type': 'application/json'
            }
            
            try:
                response = requests.get(f"{API_URL}/api/v1/workflows/{workflow_id}", headers=headers)
                if response.status_code == 200:
                    workflow_data = response.json()
                    is_active = workflow_data.get('active', False)
                    workflow_name = workflow_data.get('name', 'Unknown')
                    print(f"✓ Verification: Workflow '{workflow_name}' is {'ACTIVE' if is_active else 'INACTIVE'}")
                else:
                    print(f"✗ Could not verify activation status: {response.status_code}")
            except Exception as e:
                print(f"✗ Could not verify activation status: {str(e)}")
        else:
            print(f"\n✗ Failed to activate workflow {workflow_id}")
    else:
        print("✗ Failed to create workflow")


if __name__ == "__main__":
    main()