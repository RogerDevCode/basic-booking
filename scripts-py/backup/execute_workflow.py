#!/usr/bin/env python3
"""
Script to execute the workflow from the JSON file
"""

import json
import sys
import os
from typing import Dict, Any

# Add the scripts-py directory to the path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from qwen_n8n_plugin import qwen_n8n_plugin


def load_workflow_from_json(file_path: str) -> Dict[str, Any]:
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


def main():
    # Path to the workflow JSON file
    workflow_file_path = "/home/manager/Sync/docker-compose/n8n/workflow_ejemplo_pandas_numpy.json"

    # Load the workflow from the JSON file
    print("Loading workflow from JSON file...")
    workflow_data = load_workflow_from_json(workflow_file_path)
    
    # Extract workflow ID from the loaded data
    workflow_id = workflow_data.get('id')
    
    if not workflow_id:
        print("Error: Workflow ID not found in JSON file.")
        return
    
    print(f"Loaded workflow: {workflow_data.get('name', 'Unknown')}")
    
    # Create the workflow in n8n
    print("\nCreating workflow in n8n...")
    create_result = qwen_n8n_plugin("create_workflow", workflow_data=workflow_data)
    create_result_dict = json.loads(create_result)
    
    if not create_result_dict.get("success"):
        print(f"Error creating workflow: {create_result_dict.get('error')}")
        return
    
    workflow_id = create_result_dict["data"]["id"]
    workflow_name = create_result_dict["data"]["name"]
    
    print(f"Workflow created successfully!")
    print(f"ID: {workflow_id}")
    print(f"Name: {workflow_name}")
    
    # Activate the workflow to make it executable
    print(f"\nActivating workflow {workflow_id}...")
    activate_result = qwen_n8n_plugin("activate_workflow", workflow_id=workflow_id)
    activate_result_dict = json.loads(activate_result)
    
    if not activate_result_dict.get("success"):
        print(f"Error activating workflow: {activate_result_dict.get('error')}")
        print("Note: This workflow may require a trigger node to be activated.")
    else:
        print("Workflow activated successfully!")
        
    # Get the workflow details to confirm it was created correctly
    print(f"\nGetting workflow details for {workflow_id}...")
    get_result = qwen_n8n_plugin("get_workflow_by_id", workflow_id=workflow_id)
    get_result_dict = json.loads(get_result)
    
    if get_result_dict.get("success"):
        workflow_info = get_result_dict["data"]
        print(f"Workflow retrieved successfully:")
        print(f"  Name: {workflow_info.get('name')}")
        print(f"  Active: {workflow_info.get('active', False)}")
        print(f"  Trigger Count: {workflow_info.get('triggerCount', 0)}")
    else:
        print(f"Error getting workflow details: {get_result_dict.get('error')}")


if __name__ == "__main__":
    main()