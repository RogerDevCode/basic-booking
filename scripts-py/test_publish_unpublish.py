#!/usr/bin/env python3
"""
Test script to verify the new publish/unpublish functionality
"""

import sys
import os
from pathlib import Path

# Add the current directory to the path so we can import n8n_crud_agent
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from n8n_crud_agent import N8NCrudAgent


def test_publish_unpublish():
    # Configuration
    API_URL = "http://localhost:5678"

    # Get API key from environment variables
    API_KEY = os.environ.get('N8N_API_KEY') or os.environ.get('N8N_ACCESS_TOKEN')

    if not API_KEY:
        print("Error: No API key found. Please set N8N_API_KEY or N8N_ACCESS_TOKEN environment variable.")
        return

    # Initialize the agent
    agent = N8NCrudAgent(API_URL, API_KEY)

    print("=== Testing Publish/Unpublish Functionality ===\n")

    # First, let's create a new workflow to test with
    print("--- Creating a new workflow for testing ---")
    new_workflow = {
        "name": "Publish/Unpublish Test Workflow",
        "nodes": [
            {
                "parameters": {},
                "id": "test-trigger-node",
                "name": "Test Trigger",
                "type": "n8n-nodes-base.scheduleTrigger",  # Using schedule trigger for activation
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
    if not created_workflow:
        print("✗ Failed to create workflow for testing")
        return

    workflow_id = created_workflow.get('id')
    workflow_name = created_workflow.get('name')
    print(f"✓ Created workflow: '{workflow_name}' with ID: {workflow_id}")

    # Verify initial state (should be inactive)
    print(f"\n--- Verifying initial state ---")
    initial_state = agent.get_workflow_by_id(workflow_id)
    if initial_state:
        is_active = initial_state.get('active', False)
        print(f"Initial state: {'ACTIVE' if is_active else 'INACTIVE'}")

    # Test publish using the new method
    print(f"\n--- Testing publish_workflow() ---")
    publish_result = agent.publish_workflow(workflow_id)
    if publish_result:
        print("✓ publish_workflow() succeeded")
        # Verify state after publishing
        after_publish = agent.get_workflow_by_id(workflow_id)
        if after_publish:
            is_active = after_publish.get('active', False)
            print(f"State after publish: {'ACTIVE' if is_active else 'INACTIVE'}")
    else:
        print("✗ publish_workflow() failed")

    # Test unpublish using the new method
    print(f"\n--- Testing unpublish_workflow() ---")
    unpublish_result = agent.unpublish_workflow(workflow_id)
    if unpublish_result:
        print("✓ unpublish_workflow() succeeded")
        # Verify state after unpublishing
        after_unpublish = agent.get_workflow_by_id(workflow_id)
        if after_unpublish:
            is_active = after_unpublish.get('active', False)
            print(f"State after unpublish: {'ACTIVE' if is_active else 'INACTIVE'}")
    else:
        print("✗ unpublish_workflow() failed")

    # Test that publish/unpublish are aliases for activate/deactivate
    print(f"\n--- Testing that publish/unpublish are aliases ---")
    # Activate using activate_workflow
    activate_result = agent.activate_workflow(workflow_id)
    if activate_result:
        print("✓ activate_workflow() succeeded")

    # Deactivate using deactivate_workflow
    deactivate_result = agent.deactivate_workflow(workflow_id)
    if deactivate_result:
        print("✓ deactivate_workflow() succeeded")

    # Compare results
    if publish_result == activate_result:
        print("✓ publish_workflow() behaves the same as activate_workflow()")
    else:
        print("✗ publish_workflow() behaves differently than activate_workflow()")

    if unpublish_result == deactivate_result:
        print("✓ unpublish_workflow() behaves the same as deactivate_workflow()")
    else:
        print("✗ unpublish_workflow() behaves differently than deactivate_workflow()")

    print(f"\n--- Testing new execution functionality ---")
    # Execute the workflow
    execution_result = agent.execute_workflow(workflow_id)
    if execution_result:
        print("✓ execute_workflow() succeeded")
        print(f"  Execution ID: {execution_result.get('id')}")
    else:
        print("✗ execute_workflow() failed")

    # Get executions
    executions = agent.get_executions(workflow_id, limit=5)
    if executions:
        print(f"✓ get_executions() succeeded, found {len(executions)} executions")
    else:
        print("✗ get_executions() failed")

    print(f"\n--- Cleanup: Keeping workflow for inspection ---")
    print(f"The test workflow '{workflow_name}' (ID: {workflow_id}) remains in your n8n instance")

    print(f"\n=== Publish/Unpublish Functionality Test Complete ===")


if __name__ == "__main__":
    test_publish_unpublish()