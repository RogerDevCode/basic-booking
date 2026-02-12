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
Script to get a report of all workflows on the n8n server
"""

import json
import sys
import os

# Add the current directory to the path so we can import n8n_crud_agent
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from n8n_crud_agent import N8NCrudAgent


def get_workflows_report():
    # Configuration
    API_URL = "http://localhost:5678"

    # Initialize the agent (will use N8N_API_KEY or N8N_ACCESS_TOKEN automatically)
    try:
        agent = N8NCrudAgent(API_URL)
    except Exception as e:
        print(f"Error initializing N8N agent: {e}")
        return

    print("=== N8N Workflows Report ===")
    print(f"Connected to: {API_URL}\n")

    # Get all workflows
    all_workflows = agent.list_workflows()
    
    if all_workflows:
        print(f"Total workflows found: {len(all_workflows)}\n")
        
        # Separate active and inactive workflows
        active_workflows = [wf for wf in all_workflows if wf.get('active', False)]
        inactive_workflows = [wf for wf in all_workflows if not wf.get('active', False)]
        
        print(f"Active workflows ({len(active_workflows)}):")
        print("-" * 50)
        for wf in active_workflows:
            print(f"  • ID: {wf.get('id')}")
            print(f"    Name: {wf.get('name')}")
            print(f"    Active: {wf.get('active', False)}")
            print(f"    Created: {wf.get('createdAt', 'N/A')}")
            print(f"    Updated: {wf.get('updatedAt', 'N/A')}")
            print()
        
        print(f"Inactive workflows ({len(inactive_workflows)}):")
        print("-" * 50)
        for wf in inactive_workflows:
            print(f"  • ID: {wf.get('id')}")
            print(f"    Name: {wf.get('name')}")
            print(f"    Active: {wf.get('active', False)}")
            print(f"    Created: {wf.get('createdAt', 'N/A')}")
            print(f"    Updated: {wf.get('updatedAt', 'N/A')}")
            print()
    else:
        print("No workflows found on the server.")
        print("\nNote: This could mean:")
        print("- The n8n server is not running")
        print("- The API key is incorrect or not set")
        print("- There are no workflows created yet")
        print("- Network connectivity issues")

    # Also get active workflows specifically
    print("=" * 60)
    print("Summary:")
    print(f"- Total workflows: {len(all_workflows) if all_workflows else 0}")
    if all_workflows:
        active_count = len([wf for wf in all_workflows if wf.get('active', False)])
        inactive_count = len([wf for wf in all_workflows if not wf.get('active', False)])
        print(f"- Active workflows: {active_count}")
        print(f"- Inactive workflows: {inactive_count}")


if __name__ == "__main__":
    get_workflows_report()