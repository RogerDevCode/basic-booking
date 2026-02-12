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

TARGET_WF_NAME = "BB_04_Booking_Transaction"

def get_target_id(agent):
    existing = agent.list_workflows()
    target = next((w for w in existing if w['name'] == TARGET_WF_NAME), None)
    if target:
        return target['id']
    else:
        raise Exception(f"{TARGET_WF_NAME} not found!")

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
                "credentials": { "postgres": { "id": "99BnrzwZQDhYU6Ly", "name": "Postgres Booking" } } # Use correct cred ID
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
        # Note: If no data, this will crash, which is fine for now
        provider_id = run_data['Get Provider'][0]['data']['main'][0][0]['json']['id']
        user_id = run_data['Get User'][0]['data']['main'][0][0]['json']['id']
        return provider_id, user_id
    finally:
        agent.delete_workflow(wf['id'])

def run_test(agent, webhook_id, payload, description):
    print(f"\n🚀 {description}...")
    url = f"{agent.api_url}/webhook/{webhook_id}" # Use ID or path?
    # BB_04 has webhookId "bb04-booking-webhook" and path "book-v3"
    # So URL is /webhook/book-v3
    url = f"{agent.api_url}/webhook/book-v3"
    
    # We need to use POST
    try:
        response = requests.post(url, json=payload, timeout=15)
        print(f"   Response Code: {response.status_code}")
        try:
            print(f"   Response Body: {json.dumps(response.json(), indent=2)}")
        except:
            print(f"   Response Text: {response.text}")
        return response
    except Exception as e:
        print(f"❌ Request failed: {e}")
        return None

def main():
    agent = N8NCrudAgent('http://localhost:5678')
    
    # Verify workflow exists and is active?
    # Webhooks in N8N are active if the workflow is active.
    # We need to activate it if not active.
    wf_id = get_target_id(agent)
    print(f"ℹ️ Target Workflow ID: {wf_id}")
    
    agent.activate_workflow(wf_id)
    time.sleep(2)
    
    try:
        p_id, u_id = get_real_ids(agent)
        print(f"ℹ️ Real IDs: {p_id}, {u_id}")
    except Exception as e:
        print(f"⚠️ Failed to get real IDs: {e}. using dummies")
        p_id = "11111111-1111-1111-1111-111111111111"
        u_id = "11111111-1111-1111-1111-111111111111"

    # 1. Invalid Input (Helper Should Catch)
    invalid_payload = {
        "provider_id": "invalid-uuid",
        "user_id": u_id,
        "start_time": "2026-03-01T10:00:00Z",
        "end_time": "2026-03-01T11:00:00Z"
    }
    resp1 = run_test(agent, None, invalid_payload, "Test 1: Invalid UUID (Helper Guard)")
    # Expect 400
    
    # 2. Invalid Logic (Helper Should Catch - Provider Not Found)
    # Using dummy ID validation logic failure
    logic_fail_payload = {
        "provider_id": "11111111-1111-1111-1111-111111111111",
        "user_id": u_id, 
        "start_time": "2026-03-01T10:00:00Z",
        "end_time": "2026-03-01T11:00:00Z"
    }
    resp2 = run_test(agent, None, logic_fail_payload, "Test 2: Provider Not Found (Helper Logic)")
    # Expect 400
    
    # 3. Valid Input (Should Pass Helper -> Lock -> GCal)
    valid_payload = {
        "provider_id": p_id,
        "user_id": u_id,
        "start_time": "2026-03-01T12:00:00Z", # Ensure future time
        "end_time": "2026-03-01T13:00:00Z"
    }
    resp3 = run_test(agent, None, valid_payload, "Test 3: Valid Input (Full Flow)")
    # Expect 201 (Success) or 409 (Locked) or 400/500 (GCal/DB fail)
    # If we get 400 and message is NOT from helper ("Validation failed"), then helper passed.

if __name__ == "__main__":
    main()
