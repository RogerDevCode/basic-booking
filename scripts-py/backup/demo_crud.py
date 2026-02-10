#!/usr/bin/env python3
"""
Demonstration script showing how to use the N8N CRUD Agent
"""

import json
import sys
import os

# Add the current directory to the path so we can import n8n_crud_agent
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from n8n_crud_agent import N8NCrudAgent


def demo_crud_operations():
    # Configuration
    API_URL = "http://localhost:5678"

    # Initialize the agent (will use N8N_API_KEY or N8N_ACCESS_TOKEN automatically)
    agent = N8NCrudAgent(API_URL)
    
    print("=== N8N CRUD Agent Demo ===")
    print(f"Connected to: {API_URL}\n")
    
    # 1. CREATE: Create a new workflow
    print("--- 1. CREATE Operation ---")
    new_workflow = {
        "name": "Demo Workflow - Created via API",
        "nodes": [
            {
                "parameters": {},
                "id": "demo-trigger-node-id",
                "name": "Manual Trigger",
                "type": "n8n-nodes-base.manualTrigger",
                "typeVersion": 1,
                "position": [240, 300]
            }
        ],
        "connections": {},
        "settings": {
            "saveManualExecutions": True
        }
    }
    
    created_workflow = agent.create_workflow(new_workflow)
    if created_workflow:
        workflow_id = created_workflow.get('id')
        workflow_name = created_workflow.get('name')
        print(f"✓ Successfully created workflow: '{workflow_name}' with ID: {workflow_id}")
    else:
        print("✗ Failed to create workflow")
        return  # Exit if we can't create a workflow to test with
    
    # 2. READ: List all workflows
    print("\n--- 2. READ Operation (List All) ---")
    all_workflows = agent.list_workflows()
    if all_workflows:
        print(f"Found {len(all_workflows)} workflow(s):")
        for wf in all_workflows:
            status = "ACTIVE" if wf.get('active', False) else "INACTIVE"
            print(f"  - ID: {wf.get('id')} | Name: {wf.get('name')} | Status: {status}")
    else:
        print("No workflows found.")
    
    # 3. READ: Get specific workflow
    print(f"\n--- 3. READ Operation (Get Specific) ---")
    retrieved_workflow = agent.get_workflow_by_id(workflow_id)
    if retrieved_workflow:
        print(f"✓ Retrieved workflow: '{retrieved_workflow.get('name')}'")
        print(f"  ID: {retrieved_workflow.get('id')}")
        print(f"  Active: {retrieved_workflow.get('active', False)}")
    else:
        print("✗ Failed to retrieve workflow")
    
    # 4. UPDATE: Try to update the workflow (name only)
    print(f"\n--- 4. UPDATE Operation ---")
    update_data = {
        "name": f"Updated {workflow_name}",
        "nodes": [
            {
                "parameters": {},
                "id": "demo-trigger-node-id",
                "name": "Manual Trigger",
                "type": "n8n-nodes-base.manualTrigger",
                "typeVersion": 1,
                "position": [240, 300]
            }
        ],
        "connections": {},
        "settings": {
            "saveManualExecutions": True
        }
    }
    
    updated_workflow = agent.update_workflow(workflow_id, update_data)
    if updated_workflow:
        print(f"✓ Successfully updated workflow to: '{updated_workflow.get('name')}'")
    else:
        print("✗ Failed to update workflow (this may be expected depending on n8n version)")
    
    # 5. ACTIVATE: Try to activate the workflow
    print(f"\n--- 5. ACTIVATE Operation ---")
    if agent.activate_workflow(workflow_id):
        print(f"✓ Successfully activated workflow: {workflow_name}")
    else:
        print(f"✗ Failed to activate workflow: {workflow_name} (likely because it has no trigger node)")
    
    # 6. DEACTIVATE: Deactivate the workflow
    print(f"\n--- 6. DEACTIVATE Operation ---")
    if agent.deactivate_workflow(workflow_id):
        print(f"✓ Successfully deactivated workflow: {workflow_name}")
    else:
        print(f"✗ Failed to deactivate workflow: {workflow_name}")
    
    # 7. DELETE: Clean up by deleting the workflow
    print(f"\n--- 7. DELETE Operation ---")
    print("Note: Commenting out delete operation to preserve your workflow")
    # Uncomment the next lines if you want to actually delete the workflow
    # if agent.delete_workflow(workflow_id):
    #     print(f"✓ Successfully deleted workflow: {workflow_name}")
    # else:
    #     print(f"✗ Failed to delete workflow: {workflow_name}")
    
    print(f"\n--- Summary ---")
    print(f"Successfully demonstrated CRUD operations on workflow: {workflow_id}")
    print("The workflow remains in your n8n instance for inspection.")


def show_available_methods():
    """Show all available methods in the N8N CRUD Agent"""
    print("\n=== Available Methods in N8N CRUD Agent ===")
    print("• list_workflows() - Get all workflows")
    print("• list_active_workflows() - Get only active workflows")
    print("• get_workflow_by_id(id) - Get specific workflow")
    print("• create_workflow(data) - Create new workflow")
    print("• update_workflow(id, data) - Update existing workflow")
    print("• delete_workflow(id) - Delete workflow")
    print("• activate_workflow(id) - Activate (publish) workflow")
    print("• deactivate_workflow(id) - Deactivate (unpublish) workflow")
    print("• publish_workflow(id) - Alias for activate")
    print("• unpublish_workflow(id) - Alias for deactivate")


if __name__ == "__main__":
    demo_crud_operations()
    show_available_methods()