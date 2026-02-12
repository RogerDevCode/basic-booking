#!/usr/bin/env python3

import sys
import os
import json
import uuid

# Add current directory to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))
from n8n_crud_agent import N8NCrudAgent

HELPER_NAME = "BB_04_Helper_Validate_Booking"

def create_helper():
    agent = N8NCrudAgent('http://localhost:5678')
    
    # Check if exists
    existing = agent.list_workflows()
    if existing:
        for wf in existing:
            if wf['name'] == HELPER_NAME:
                print(f"⚠️ Workflow {HELPER_NAME} already exists (ID: {wf['id']}). Updating...")
    
    # Define Nodes
    nodes = [
        {
            "parameters": {},
            "id": "start",
            "name": "Start",
            "type": "n8n-nodes-base.executeWorkflowTrigger",
            "typeVersion": 1,
            "position": [250, 300]
        },
        {
            "parameters": {},
            "id": "manual",
            "name": "Manual",
            "type": "n8n-nodes-base.manualTrigger",
            "typeVersion": 1,
            "position": [250, 100]
        },
        {
            "parameters": {
                "jsCode": """
try {
    const root = $input.first().json;
    const input = root.body ? root.body : root;
    
    const errors = [];
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    if (!input.provider_id || !uuidRegex.test(input.provider_id)) errors.push("Invalid provider_id");
    if (!input.user_id || !uuidRegex.test(input.user_id)) errors.push("Invalid user_id");
    
    const start = new Date(input.start_time);
    const end = new Date(input.end_time);
    
    if (isNaN(start.getTime())) errors.push("Invalid start_time format");
    if (isNaN(end.getTime())) errors.push("Invalid end_time format");
    if (start.getTime() >= end.getTime()) errors.push("start_time must be strictly before end_time");

    if (errors.length > 0) {
        return [{ json: { valid: false, error_code: "ERR_VALIDATION", message: "Validation failed", details: errors } }];
    }

    const serviceId = input.service_id || null;
    const durationMin = (end - start) / (1000 * 60);
    
    return [{ json: { 
        ...input, 
        service_id: serviceId, 
        duration_min: durationMin, 
        valid: true 
    } }];
} catch (e) {
    return [{ json: { valid: false, error_code: "ERR_GUARD_CRASH", message: e.message } }];
}
"""
            },
            "id": "guard",
            "name": "Guard Validation",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [450, 300]
        },
        {
            "parameters": {
                "mode": "rules",
                "rules": {
                    "values": [
                        {
                            "outputKey": "error",
                            "conditions": {
                                "options": { "caseSensitive": True, "version": 3 },
                                "conditions": [
                                    { "id": "is-invalid", "leftValue": "={{ $json.valid }}", "operator": { "type": "boolean", "operation": "false" }, "rightValue": "" }
                                ],
                                "combinator": "and"
                            }
                        }
                    ]
                },
                "options": { "fallbackOutput": "extra" }
            },
            "id": "check_guard",
            "name": "Guard_Check_Switch",
            "type": "n8n-nodes-base.switch",
            "typeVersion": 3,
            "position": [650, 300]
        },
        {
            "parameters": {
                "operation": "executeQuery",
                "query": "SELECT public.get_app_config_json() as config"
            },
            "id": "get_config",
            "name": "Get Config",
            "type": "n8n-nodes-base.postgres",
            "typeVersion": 2.4,
            "position": [850, 200], # Moved up slightly for linear visual
            "credentials": {
                "postgres": {
                    "id": "99BnrzwZQDhYU6Ly",
                    "name": "Postgres Booking"
                }
            }
        },
        {
            "parameters": {
                "operation": "executeQuery",
                "query": "SELECT EXISTS(SELECT 1 FROM providers WHERE id = '{{ $('Guard Validation').item.json.provider_id }}' AND deleted_at IS NULL) as provider_exists, EXISTS(SELECT 1 FROM users WHERE id = '{{ $('Guard Validation').item.json.user_id }}' AND deleted_at IS NULL) as user_exists",
                "options": {}
            },
            "id": "val_fks",
            "name": "Validate FKs",
            "type": "n8n-nodes-base.postgres",
            "typeVersion": 2.4,
            "position": [1050, 200], # Linear sequence
            "credentials": {
                "postgres": {
                    "id": "99BnrzwZQDhYU6Ly",
                    "name": "Postgres Booking"
                }
            }
        },
        {
            "parameters": {
                "jsCode": """
const guard = $('Guard Validation').item.json;
const config = $('Get Config').item.json.config || {};
const fks = $('Validate FKs').item.json;

// Check FKs
if (!fks.provider_exists) return [{ json: { valid: false, error_code: "ERR_PROVIDER_NOT_FOUND", message: "Provider not found" } }];
if (!fks.user_exists) return [{ json: { valid: false, error_code: "ERR_USER_NOT_FOUND", message: "User not found" } }];

// Check Duration
const durationMin = guard.duration_min;
const minDuration = parseInt(config.MIN_DURATION_MIN || 15);
const maxDuration = parseInt(config.MAX_DURATION_MIN || 120);

if (durationMin < minDuration || durationMin > maxDuration) {
    return [{ json: { 
        valid: false, 
        error_code: "ERR_INVALID_DURATION", 
        message: `Duration must be between ${minDuration} and ${maxDuration} minutes` 
    } }];
}

return [{ json: { ...guard, valid: true } }];
"""
            },
            "id": "final_logic",
            "name": "Final Logic",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [1250, 200]
        },
        {
            "parameters": {},
            "id": "end",
            "name": "End",
            "type": "n8n-nodes-base.noOp",
            "typeVersion": 1,
            "position": [850, 400]
        }
    ]

    # Connections (Linear)
    connections = {
        "Start": { "main": [[{"node": "Guard Validation", "type": "main", "index": 0}]] },
        "Manual": { "main": [[{"node": "Guard Validation", "type": "main", "index": 0}]] },
        "Guard Validation": { "main": [[{"node": "Guard_Check_Switch", "type": "main", "index": 0}]] },
        "Guard_Check_Switch": {
            "main": [
                [{"node": "End", "type": "main", "index": 0}], # 0: Invalid -> End
                [   # 1: Valid -> Run Config Check
                    {"node": "Get Config", "type": "main", "index": 0}
                ]
            ]
        },
        "Get Config": { "main": [[{"node": "Validate FKs", "type": "main", "index": 0}]] },
        "Validate FKs": { "main": [[{"node": "Final Logic", "type": "main", "index": 0}]] }
    }
    
    workflow = {
        "name": HELPER_NAME,
        "nodes": nodes,
        "connections": connections,
        "settings": {
            "executionOrder": "v1",
            "callerPolicy": "workflowsFromSameOwner"
        }
    }
    
    print(f"Creating/Updating {HELPER_NAME}...")
    existing_id = next((w['id'] for w in existing if w['name'] == HELPER_NAME), None)
    
    if existing_id:
        print(f"Deleting existing workflow {existing_id}...")
        agent.delete_workflow(existing_id)
        
    res = agent.create_workflow(workflow)
    print(f"Created: {res['id']}")

if __name__ == "__main__":
    create_helper()
