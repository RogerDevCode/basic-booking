
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
from typing import Dict, Optional

# Add scripts-py to path

from n8n_crud_agent import N8NCrudAgent

API_URL = "http://localhost:5678"
WF_ID = "Rhn_gioVdn3Q3AeiyNPYg"
WEBHOOK_PATH = "289b5478-0eee-433e-a3ec-7e26e2501cd5"
WEBHOOK_URL = f"{API_URL}/webhook/{WEBHOOK_PATH}"

agent = N8NCrudAgent(API_URL)

def get_last_execution_result(workflow_id: str) -> Optional[Dict]:
    # Get recent executions globally and filter manually
    all_executions = agent.get_executions(limit=20)
    if all_executions:
        # Find latest execution for our workflow
        workflow_executions = [e for e in all_executions if e.get('workflowId') == workflow_id]
        if workflow_executions:
            exec_id = workflow_executions[0]['id']
            return agent.get_execution_by_id(exec_id)
    return None

def run_test(name: str, payload: Dict):
    print(f"\n--- TEST: {name} ---")
    
    print(f"Triggering webhook...")
    try:
        requests.post(WEBHOOK_URL, json=payload, timeout=5)
        print("Waiting 2 seconds for execution to complete...")
        time.sleep(2)
        
        result = get_last_execution_result(WF_ID)
        if result:
            print(f"Execution ID: {result.get('id')}")
            print(f"Status: {result.get('status')}")
            
            # Find the output node data
            # In BB_02, the return nodes are: 
            # "Return Authorized", "Return Denied", "Return Validation Error", "Return Error"
            run_data = result.get('data', {}).get('resultData', {}).get('runData', {})
            
            output_nodes = ["Return Authorized", "Return Denied", "Return Validation Error", "Return Error", "Return Error After Notify"]
            found_output = False
            
            for node in output_nodes:
                if node in run_data:
                    print(f"Output from node [{node}]:")
                    node_data = run_data[node][0].get('data', {}).get('main', [{}])[0].get('json', {})
                    print(json.dumps(node_data, indent=2))
                    found_output = True
                    break
            
            if not found_output:
                print("Could not find final output node in execution data.")
                # Show first few node names to debug
                print(f"Nodes executed: {list(run_data.keys())}")
        else:
            print("No execution found.")
            
    except Exception as e:
        print(f"Test failed: {e}")

def main():
    print(f"Testing BB_02_Security_Firewall")
    
    # Scenario A: Authorized Admin (Roger)
    run_test("Authorized Admin", {
        "user": {
            "telegram_id": 5391760292,
            "first_name": "Roger",
            "username": "roger_admin"
        },
        "routing": {"action": "start"}
    })

    # Scenario B: New User
    run_test("New User", {
        "user": {
            "telegram_id": 999111222,
            "first_name": "Test",
            "username": "test_new"
        }
    })

    # Scenario C: Banned User (888888888)
    run_test("Banned User", {
        "user": {
            "telegram_id": 888888888,
            "first_name": "Banned",
            "username": "banned_user"
        }
    })

    # Scenario D: Invalid Input (Negative ID)
    run_test("Invalid Input", {
        "user": {
            "telegram_id": -1
        }
    })

if __name__ == "__main__":
    main()