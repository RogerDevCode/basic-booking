#!/usr/bin/env python3

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

import json
import uuid
import time
import requests

# Add current directory to path
if os.path.abspath(os.path.join(os.path.dirname(__file__), '../../scripts-py')) not in sys.path:
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../scripts-py')))
from n8n_crud_agent import N8NCrudAgent

def get_helper_id(agent):
    existing = agent.list_workflows()
    helper = next((w for w in existing if w['name'] == "BB_04_Helper_Validate_Booking"), None)
    if helper:
        return helper['id']
    else:
        raise Exception("Helper workflow not found!")

def run_test_case(agent, input_data, description):
    HELPER_ID = get_helper_id(agent)
    print(f"\n🚀 {description} (Helper ID: {HELPER_ID})...")
    
    wrapper_name = f"Test_Helper_Wrapper_{str(uuid.uuid4())[:8]}"
    webhook_path = f"test-helper-{str(uuid.uuid4())[:8]}"
    
    wrapper = {
        "name": wrapper_name,
        "nodes": [
            {
                "parameters": {
                    "httpMethod": "POST",
                    "path": webhook_path,
                    "options": {}
                },
                "id": "webhook",
                "name": "Webhook",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [250, 300],
                "webhookId": str(uuid.uuid4())
            },
            {
                "parameters": {
                    "jsCode": f"return [{{ json: {json.dumps(input_data)} }}];"
                },
                "id": "prepare",
                "name": "Prepare Data",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [450, 300]
            },
            {
                "parameters": {
                    "workflowId": HELPER_ID,
                    "options": {}
                },
                "id": "exec_helper",
                "name": "Execute Helper",
                "type": "n8n-nodes-base.executeWorkflow",
                "typeVersion": 1,
                "position": [650, 300]
            }
        ],
        "connections": {
            "Webhook": { "main": [[{"node": "Prepare Data", "type": "main", "index": 0}]] },
            "Prepare Data": { "main": [[{"node": "Execute Helper", "type": "main", "index": 0}]] }
        },
        "settings": { "executionOrder": "v1" }
    }
    
    wf = agent.create_workflow(wrapper)
    if not wf:
        print("❌ Failed to create wrapper")
        return
    
    print(f"   Wrapper created: {wf['id']}")

    try:
        print("   Activating wrapper...")
        agent.activate_workflow(wf['id'])
        time.sleep(5)
        
        url = f"{agent.api_url}/webhook/{webhook_path}"
        try:
            print(f"   Posting to webhook: {url}")
            requests.post(url, json={}, timeout=10)
        except Exception as e:
            print(f"⚠️ Webhook post error: {e}")
            pass
            
        print("   Waiting for execution...")
        time.sleep(5)
        execs = agent.get_executions(workflow_id=wf['id'], limit=1)
        
        if execs:
            run_data = agent.get_execution_by_id(execs[0]['id'])['data']['resultData']['runData']
            if 'Execute Helper' in run_data:
                node_data = run_data['Execute Helper'][0]
                if 'data' in node_data:
                    output = node_data['data']['main'][0][0]['json']
                    print(f"✅ Output: {json.dumps(output, indent=2)}")
                    return output
                else:
                    print(f"❌ Node 'Execute Helper' missing 'data'. Keys: {node_data.keys()}")
                    print(f"   Full Node Data: {json.dumps(node_data, indent=2)}")
            else:
                 print("⚠️ Execute Helper node not found in execution data.")
                 print(f"   Nodes run: {list(run_data.keys())}")
                 # Print detailed run data for debugging
                 print(f"   Full Run Data: {json.dumps(run_data, indent=2)}")
        else:
            print("❌ No execution found")
            return None
            
    finally:
        print(f"   Deleting wrapper {wf['id']}...")
        agent.delete_workflow(wf['id'])

def get_real_ids(agent):
    query_wf = {
        "name": f"Get_IDs_{str(uuid.uuid4())[:8]}",
        "nodes": [
            {
                "parameters": {},
                "id": "start",
                "name": "Start",
                "type": "n8n-nodes-base.manualTrigger",
                "typeVersion": 1,
                "position": [250, 300]
            },
            {
                "parameters": {
                    "operation": "executeQuery",
                    "query": "SELECT id FROM providers LIMIT 1;",
                    "options": {}
                },
                "id": "get_provider",
                "name": "Get Provider",
                "type": "n8n-nodes-base.postgres",
                "typeVersion": 2.4,
                "position": [450, 300],
                "credentials": { "postgres": { "id": "99BnrzwZQDhYU6Ly", "name": "Postgres Booking" } }
            },
            {
                "parameters": {
                    "operation": "executeQuery",
                    "query": "SELECT id FROM users LIMIT 1;",
                    "options": {}
                },
                "id": "get_user",
                "name": "Get User",
                "type": "n8n-nodes-base.postgres",
                "typeVersion": 2.4,
                "position": [650, 300],
                "credentials": { "postgres": { "id": "99BnrzwZQDhYU6Ly", "name": "Postgres Booking" } }
            }
        ],
        "connections": {
            "Start": { "main": [[{"node": "Get Provider", "type": "main", "index": 0}]] },
            "Get Provider": { "main": [[{"node": "Get User", "type": "main", "index": 0}]] }
        },
        "settings": { "executionOrder": "v1" }
    }
    
    wf = agent.create_workflow(query_wf)
    if not wf:
        raise Exception("Failed to create get_real_ids workflow")

    try:
        res = agent.execute_workflow(wf['id'])
        run_data = res['data']['resultData']['runData']
        provider_id = run_data['Get Provider'][0]['data']['main'][0][0]['json']['id']
        user_id = run_data['Get User'][0]['data']['main'][0][0]['json']['id']
        return provider_id, user_id
    finally:
        agent.delete_workflow(wf['id'])

def test_helper():
    agent = N8NCrudAgent('http://localhost:5678')
    print(f"📋 Testing Helper Workflow: BB_04_Helper_Validate_Booking")

    try:
        p_id, u_id = get_real_ids(agent)
        print(f"ℹ️ Found Real IDs - Provider: {p_id}, User: {u_id}")
    except Exception as e:
        print(f"⚠️ Failed to get real IDs: {e}. Using dummies.")
        p_id = "11111111-1111-1111-1111-111111111111"
        u_id = "11111111-1111-1111-1111-111111111111"

    # Case 1
    valid_input = {
        "provider_id": p_id, 
        "user_id": u_id, 
        "start_time": "2026-03-01T10:00:00Z",
        "end_time": "2026-03-01T11:00:00Z",
        "service_id": "service-123"
    }
    res1 = run_test_case(agent, valid_input, "Valid Input")
    
    # Case 2: Invalid (Short)
    invalid_input = valid_input.copy()
    invalid_input['end_time'] = "2026-03-01T10:05:00Z"
    res2 = run_test_case(agent, invalid_input, "Invalid Input (Short)")
    
    if res2 and res2.get('valid') is False:
        print("✅ Validation caught error successfully.")

if __name__ == "__main__":
    test_helper()
