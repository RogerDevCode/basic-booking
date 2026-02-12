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

"""
Full Chain Test for BB_03_Availability_Engine via EXECUTE
Avoids webhook response errors by calling the orchestrator directly.
"""

import time
import uuid
import json
import requests
from workflow_config import N8N_LOCAL_URL
from test_helpers import (
    print_header, print_step, print_success, print_error, print_info,
    init_agent, verify_workflow_exists
)

BB_03_MAIN_ID = "g5JAoByPdzyKflLj"

def run_bb03_chain_exec():
    print_header("BB_03 Availability Engine - Direct Exec Chain Test")
    
    agent = init_agent(N8N_LOCAL_URL)
    if not agent: return False
    
    # 1. Prepare Wrapper
    print_step(1, 4, "Creating temporary wrapper workflow")
    
    payload = {
        "provider_slug": "test-pro",
        "days_range": 3,
        "target_date": "2026-03-01"
    }
    
    webhook_path = f"test-bb03-chain-{str(uuid.uuid4())[:8]}"
    
    wrapper = {
        "name": f"Temp_BB03_Chain_{str(uuid.uuid4())[:8]}",
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
                    "jsCode": f"return [{{ json: {json.dumps(payload)} }}];"
                },
                "id": "prep",
                "name": "Prepare Data",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [450, 300]
            },
            {
                "parameters": {
                    "method": "POST",
                    "url": f"{N8N_LOCAL_URL}/webhook/bb03-main",
                    "sendBody": True,
                    "bodyParameters": {
                        "parameters": [
                            { "name": "provider_slug", "value": "={{ $json.provider_slug }}" },
                            { "name": "days_range", "value": "={{ $json.days_range }}" },
                            { "name": "target_date", "value": "={{ $json.target_date }}" }
                        ]
                    },
                    "options": {}
                },
                "id": "trigger_main",
                "name": "Trigger BB_03 Main",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.1,
                "position": [650, 300]
            }
        ],
        "connections": {
            "Webhook": { "main": [[{"node": "Prepare Data", "type": "main", "index": 0}]] },
            "Prepare Data": { "main": [[{"node": "Trigger BB_03 Main", "type": "main", "index": 0}]] }
        },
        "settings": { "executionOrder": "v1" }
    }
    
    wf = agent.create_workflow(wrapper)
    if not wf:
        print_error("Failed to create wrapper")
        return False
    
    try:
        # 2. Execute via Webhook
        print_step(2, 4, "Activating and triggering wrapper via Webhook")
        agent.activate_workflow(wf['id'])
        time.sleep(2)
        
        webhook_url = f"{N8N_LOCAL_URL}/webhook/{webhook_path}"
        requests.post(webhook_url, json={}, timeout=10)
        
        print_info("Waiting for execution to complete...")
        time.sleep(5)
        
        # 3. Analyze Results
        print_step(3, 4, "Analyzing results from BB_03 chain")
        execs = agent.get_executions(workflow_id=wf['id'], limit=1)
        
        if not execs:
            print_info("Retrying execution detection in 5s...")
            time.sleep(5)
            execs = agent.get_executions(workflow_id=wf['id'], limit=1)

        if execs:
            full_exec = agent.get_execution_by_id(execs[0]['id'])
            run_data = full_exec['data']['resultData']['runData']
            print_info(f"Available nodes in execution: {list(run_data.keys())}")
            
            node_name = 'Trigger BB_03 Main'
            if node_name in run_data and len(run_data[node_name]) > 0:
                node_exec = run_data[node_name][0]
                print_info(f"Node execution keys: {list(node_exec.keys())}")
                
                if 'data' in node_exec:
                    print_info(f"Node data branches: {list(node_exec['data'].keys())}")
                else:
                    if 'error' in node_exec:
                        print_error(f"Node Error Details: {json.dumps(node_exec['error'])}")
                    
                if 'data' in node_exec and 'main' in node_exec['data'] and len(node_exec['data']['main']) > 0:
                    main_branch = node_exec['data']['main']
                    print_info(f"Main branch items: {len(main_branch)}")
                    
                    if len(main_branch) > 0 and main_branch[0] and len(main_branch[0]) > 0:
                        main_output = main_branch[0][0].get('json', {})
                        print_info(f"Main output JSON: {json.dumps(main_output)[:200]}...")
                        
                        if main_output.get('success'):
                            print_success("BB_03 Chain reported success")
                            data = main_output.get('data', {})
                            slots = data.get('slots', []) if isinstance(data, dict) else []
                            print_info(f"Slots found: {len(slots)}")
                            return True
                        else:
                            print_error(f"BB_03 Chain reported failure: {main_output.get('error_message')}")
                            if main_output.get('message'):
                                print_info(f"Message: {main_output.get('message')}")
                            return False
                    else:
                        print_error(f"{node_name} output data branch is empty")
                        return False
                else:
                    print_error(f"{node_name} node executed but has no output data")
                    return False
            else:
                print_error(f"{node_name} node did not execute.")
                return False
            
    finally:
        # 4. Cleanup
        print_step(4, 4, "Cleaning up wrapper")
        agent.delete_workflow(wf['id'])

if __name__ == "__main__":
    try:
        success = run_bb03_chain_exec()
        print("\n" + "="*40)
        if success:
            print_success("BB_03 CHAIN TEST PASSED")
        else:
            print_error("BB_03 CHAIN TEST FAILED")
        sys.exit(0 if success else 1)
    except Exception as e:
        print_error(f"Unexpected error: {str(e)}")
        sys.exit(1)
