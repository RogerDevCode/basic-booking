#!/usr/bin/env python3

import sys
import os

# Add current directory to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))
from n8n_crud_agent import N8NCrudAgent

def activate_by_name(name):
    agent = N8NCrudAgent('http://localhost:5678')
    existing = agent.list_workflows()
    if existing:
        wf = next((w for w in existing if w['name'] == name), None)
        if wf:
            print(f"Found workflow '{name}' (ID: {wf['id']}). Activating...")
            agent.activate_workflow(wf['id'])
            print("Done.")
        else:
            print(f"Workflow '{name}' not found.")
    else:
        print("No workflows found.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 activate_workflow_by_name.py <workflow_name>")
        sys.exit(1)
    activate_by_name(sys.argv[1])
