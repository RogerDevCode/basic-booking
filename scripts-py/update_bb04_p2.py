#!/usr/bin/env python3

import sys
import os
import json
import uuid

# Add current directory to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))
from n8n_crud_agent import N8NCrudAgent

TARGET_WF_NAME = "BB_04_Booking_Transaction"
HELPER_NAME = "BB_04_Helper_Validate_Booking"

def update_workflow():
    agent = N8NCrudAgent('http://localhost:5678')
    
    # 1. Get Target Workflow Info (ID)
    existing = agent.list_workflows()
    target_wf_meta = next((w for w in existing if w['name'] == TARGET_WF_NAME), None)
    
    # ALWAYS load base from file to ensure clean slate
    print(f"Loading base workflow from file...")
    file_path = os.path.join(os.path.dirname(__file__), "../workflows/BB_04_Booking_Transaction.json")
    try:
         with open(file_path, 'r') as f:
             full_wf = json.load(f)
         print("✅ Loaded workflow from file.")
    except Exception as e:
        print(f"❌ Failed to load file: {e}")
        return

    nodes = full_wf['nodes']
    connections = full_wf['connections']
    
    # 2. Get Helper ID
    helper_meta = next((w for w in existing if w['name'] == HELPER_NAME), None)
    if not helper_meta:
         print(f"❌ Helper workflow {HELPER_NAME} not found!")
         return
    helper_id = helper_meta['id']

    # 3. Define Nodes to Remove
    nodes_to_remove = [
        "Guard", 
        "Valid?", 
        "Get Config", 
        "Validate Duration", 
        "Duration OK?",
        "Validate Foreign Keys", # "val_fks"
        "FKs OK?" # "check_fks"
    ]
    
    # Filter nodes
    new_nodes = [n for n in nodes if n['name'] not in nodes_to_remove]
    
    # 4. Create New Nodes
    execute_helper_node = {
        "parameters": {
            "workflowId": helper_id,
            "options": {
                "waitForSubWorkflow": True
            }
        },
        "id": "exec_helper",
        "name": "Execute Helper",
        "type": "n8n-nodes-base.executeWorkflow",
        "typeVersion": 1,
        "position": [250, 300] # Position where Webhook connects to
    }
    
    check_helper_node = {
        "parameters": {
            "mode": "rules",
            "rules": {
                "values": [
                    {
                        "outputKey": "valid",
                        "conditions": {
                            "options": { "caseSensitive": True, "version": 3 },
                            "conditions": [
                                { "id": "is-valid", "leftValue": "={{ $json.valid }}", "operator": { "type": "boolean", "operation": "true" }, "rightValue": "" }
                            ],
                            "combinator": "and"
                        }
                    }
                ]
            },
            "options": { "fallbackOutput": "extra" }
        },
        "id": "check_helper",
        "name": "Check Helper",
        "type": "n8n-nodes-base.switch",
        "typeVersion": 3,
        "position": [450, 300]
    }

    # Audit Log Node
    audit_log_node = {
        "parameters": {
            "operation": "insert",
            "schema": "public",
            "table": "audit_logs",
            "columns": {
                "mappingMode": "defineBelow",
                "value": {
                    "action": "INSERT",
                    "record_id": "={{ $json.booking_id }}",
                    "entity": "bookings",
                    "details": "={{ JSON.stringify($json) }}"
                }
            }
        },
        "id": "audit_log",
        "name": "Audit Log",
        "type": "n8n-nodes-base.postgres",
        "typeVersion": 2.4,
        "position": [2700, -200],
        "credentials": {
            "postgres": {
                "id": "aa8wMkQBBzGHkJzn",
                "name": "Postgres Neon"
            }
        }
    }
    
    # Error Handler Node (Transaction Fail)
    error_handler_node = {
        "parameters": {
            "workflowId": "={{ $workflow('BB_00_Global_Error_Handler').id }}",
            "options": {
                "waitForSubWorkflow": False
            }
        },
        "id": "call_bb00_fail",
        "name": "Call BB_00 Transaction Fail",
        "type": "n8n-nodes-base.executeWorkflow",
        "typeVersion": 1,
        "position": [2900, 0]
    }
    
    new_nodes.append(execute_helper_node)
    new_nodes.append(check_helper_node)
    new_nodes.append(audit_log_node)
    new_nodes.append(error_handler_node)
    
    # Sanitize nodes (fix retryOnFail issue)
    for node in new_nodes:
        if 'retryOnFail' in node and isinstance(node['retryOnFail'], dict):
             # If enabled is true, set to True, else False or remove
             if node['retryOnFail'].get('enabled', False):
                 node['retryOnFail'] = True
             else:
                 del node['retryOnFail']
                 
    # 5. Rebuild Connections
    # We remove connections FROM removed nodes.
    new_connections = {k: v for k, v in connections.items() if k not in nodes_to_remove}
    
    # We remove connections TO removed nodes.
    # Connections structure: { SourceName: { OutputName: [ [ { node: TargetName, ... } ] ] } }
    cleaned_connections = {}
    for source_name, output_dict in new_connections.items():
        cleaned_outputs = {}
        for output_name, connection_lists in output_dict.items():
            valid_connection_lists = []
            for connection_list in connection_lists:
                valid_connections = []
                for connection in connection_list:
                    # Check if target node exists in new_nodes
                    if any(n['name'] == connection['node'] for n in new_nodes):
                        valid_connections.append(connection)
                if valid_connections:
                    valid_connection_lists.append(valid_connections)
            if valid_connection_lists:
                cleaned_outputs[output_name] = valid_connection_lists
        if cleaned_outputs:
            cleaned_connections[source_name] = cleaned_outputs
            
    # Add New Connections
    # Webhook -> Execute Helper
    if "Webhook" in cleaned_connections:
        cleaned_connections["Webhook"]["main"] = [[{"node": "Execute Helper", "type": "main", "index": 0}]]
    else:
        cleaned_connections["Webhook"] = { "main": [[{"node": "Execute Helper", "type": "main", "index": 0}]] }

    # Execute Helper -> Check Helper
    cleaned_connections["Execute Helper"] = { "main": [[{"node": "Check Helper", "type": "main", "index": 0}]] }
    
    # Check Helper
    # Output 0 (Valid) -> DB: Lock Slot (Name: "DB: Lock Slot")
    # Output 1 (Invalid/Fallback) -> 400 Bad Request (Name: "400 Bad Request") # Name in JSON is "400 Bad Request"
    
    cleaned_connections["Check Helper"] = {
        "main": [
            [{"node": "DB: Lock Slot", "type": "main", "index": 0}], # Index 0: Valid
            [{"node": "400 Bad Request", "type": "main", "index": 0}] # Index 1: Fallback (Invalid)
        ]
    }
    
    # Respond Success -> Audit Log
    cleaned_connections["Respond Success"] = { "main": [[{"node": "Audit Log", "type": "main", "index": 0}]] }

    # Respond Fail -> Call BB_00 Transaction Fail
    cleaned_connections["Respond Fail"] = { "main": [[{"node": "Call BB_00 Transaction Fail", "type": "main", "index": 0}]] }

    
    # 6. Construct Request Body
    clean_wf = {
        "nodes": new_nodes,
        "connections": cleaned_connections,
        "name": full_wf.get('name', TARGET_WF_NAME),
        "settings": full_wf.get('settings', {})
    }
    
    # 7. Update or Create Workflow
    if target_wf_meta:
        print(f"Updating workflow {target_wf_meta['id']}...")
        response = agent.update_workflow(target_wf_meta['id'], clean_wf)
        print(f"✅ Workflow updated: {response['id']}")
    else:
        print(f"Creating new workflow {TARGET_WF_NAME}...")
        response = agent.create_workflow(clean_wf)
        if response:
             print(f"✅ Workflow created: {response['id']}")
        else:
             print("❌ Failed to create workflow.")

if __name__ == "__main__":
    update_workflow()
