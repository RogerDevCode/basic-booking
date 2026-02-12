
# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../scripts-py')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

import sys
import os
import json
import requests
import time
import uuid
from typing import Dict, Optional

API_URL = "https://n8n.stax.ink"
BB02_ID = "Rhn_gioVdn3Q3AeiyNPYg"

# Add scripts-py to path
from n8n_crud_agent import N8NCrudAgent

agent = N8NCrudAgent(API_URL)

def create_caller_workflow():
    name = f"Test_Caller_{uuid.uuid4().hex[:4]}"
    webhook_path = f"test-call-bb02-{uuid.uuid4().hex[:4]}"
    workflow = {
        "name": name,
        "nodes": [
            {
                "parameters": {
                    "httpMethod": "POST",
                    "path": webhook_path,
                    "responseMode": "lastNode",
                    "options": {}
                },
                "id": "webhook",
                "name": "Webhook",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [0, 0]
            },
            {
                "parameters": {
                    "workflowId": BB02_ID,
                    "options": {}
                },
                "id": "call_bb02",
                "name": "Call BB02",
                "type": "n8n-nodes-base.executeWorkflow",
                "typeVersion": 1.1,
                "position": [250, 0]
            }
        ],
        "connections": {
            "Webhook": {
                "main": [[{"node": "Call BB02", "type": "main", "index": 0}]]
            }
        },
        "settings": {"saveManualExecutions": True}
    }
    
    print(f"Creating temporary caller workflow: {name}")
    created = agent.create_workflow(workflow)
    if created:
        workflow_id = created['id']
        agent.activate_workflow(workflow_id)
        return workflow_id, webhook_path
    return None, None

def run_tests():
    wf_id, webhook_path = create_caller_workflow()
    if not wf_id:
        print("Failed to create caller workflow")
        return

    url = f"{API_URL}/webhook/{webhook_path}"
    print(f"Caller Webhook URL: {url}")

    scenarios = [
        ("Authorized Admin", {"user": {"telegram_id": 5391760292, "first_name": "Roger"}}),
        ("New User", {"user": {"telegram_id": 999111222, "first_name": "New"}}),
        ("Banned User", {"user": {"telegram_id": 888888888, "first_name": "Banned"}}),
        ("Invalid ID", {"user": {"telegram_id": -1}})
    ]

    for name, payload in scenarios:
        print(f"\n--- Scenario: {name} ---")
        try:
            resp = requests.post(url, json=payload, timeout=15)
            if resp.status_code == 200:
                print(f"Result: {json.dumps(resp.json(), indent=2)}")
            else:
                print(f"Failed Status {resp.status_code}: {resp.text}")
        except Exception as e:
            print(f"Error: {e}")

    # Cleanup
    print(f"\nCleaning up caller workflow {wf_id}...")
    agent.delete_workflow(wf_id)

if __name__ == "__main__":
    run_tests()