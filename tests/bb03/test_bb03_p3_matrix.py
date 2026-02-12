#!/usr/bin/env python3

# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../scripts-py')))
try:
    import watchdog
    watchdog.setup(600)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

"""
Combinatorial tests for BB_03 Availability Engine.
Covers invalid inputs, edge cases, and service-specific availability.
"""

import json
import time
import uuid
import requests

from n8n_crud_agent import N8NCrudAgent
from test_helpers import (
    print_header, print_step, print_success, print_error, print_info,
    init_agent, verify_workflow_exists
)

BB_03_ID = '4D2-fV_Y792B3eDweI3lH'
WRAPPER_NAME = "Test_BB03_Wrapper_Matrix"
WEBHOOK_PATH = f"test-bb03-matrix-{str(uuid.uuid4())[:8]}"

PROVIDER_ID = "2eebc9bc-c2f8-46f8-9e78-7da0909fcca4"
SERVICE_ID = "a7a019cb-3442-4f57-8877-1b04a1749c01"


def create_wrapper_workflow(agent):
    workflow_data = {
        "name": WRAPPER_NAME,
        "nodes": [
            {
                "parameters": {
                    "httpMethod": "POST",
                    "path": WEBHOOK_PATH,
                    "responseMode": "responseNode",
                    "options": {}
                },
                "id": "webhook-node",
                "name": "Webhook",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [260, 300],
                "webhookId": str(uuid.uuid4())
            },
            {
                "parameters": {
                    "jsCode": "return $input.all().map(item => ({ json: item.json.body || item.json }));"
                },
                "id": "passthrough-node",
                "name": "Pass Through",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [460, 300]
            },
            {
                "parameters": {
                    "workflowId": {
                        "__rl": True,
                        "value": BB_03_ID,
                        "mode": "id",
                        "cachedResultUrl": f"/workflow/{BB_03_ID}"
                    },
                    "options": {}
                },
                "id": "execute-bb03-node",
                "name": "Execute BB_03",
                "type": "n8n-nodes-base.executeWorkflow",
                "typeVersion": 1.1,
                "position": [660, 300]
            },
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": "={{ $json }}",
                    "options": {
                        "responseCode": 200
                    }
                },
                "id": "respond-node",
                "name": "Respond",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1,
                "position": [860, 300]
            }
        ],
        "connections": {
            "Webhook": {
                "main": [[{"node": "Pass Through", "type": "main", "index": 0}]]
            },
            "Pass Through": {
                "main": [[{"node": "Execute BB_03", "type": "main", "index": 0}]]
            },
            "Execute BB_03": {
                "main": [[{"node": "Respond", "type": "main", "index": 0}]]
            }
        },
        "settings": {
            "executionOrder": "v1"
        }
    }

    return agent.create_workflow(workflow_data)


def call_wrapper(agent, payload):
    webhook_url = f"{agent.api_url}/webhook/{WEBHOOK_PATH}"
    response = requests.post(webhook_url, json=payload, timeout=20)
    if response.status_code != 200:
        return None, f"HTTP {response.status_code}: {response.text}"
    try:
        return response.json(), None
    except Exception:
        return None, "Response is not JSON"


def run_matrix():
    print_header("Test BB_03: Matrix")

    agent = init_agent('http://localhost:5678')
    if not agent:
        return False

    print_step(1, 4, "Verificando BB_03")
    wf = verify_workflow_exists(agent, BB_03_ID, "BB_03_Slot_Availability")
    if not wf:
        return False

    print_step(2, 4, "Creando wrapper")
    wrapper = create_wrapper_workflow(agent)
    if not wrapper:
        print_error("No se pudo crear el workflow wrapper")
        return False

    global wrapper_id
    wrapper_id = wrapper['id']

    try:
        agent.activate_workflow(wrapper_id)
        time.sleep(3)

        cases = [
            {
                "name": "missing_provider",
                "payload": {"target_date": "2026-03-01"},
                "expect_success": False,
                "expect_code": "VALIDATION_FAILED"
            },
            {
                "name": "invalid_provider_uuid",
                "payload": {"provider_id": "not-a-uuid"},
                "expect_success": False,
                "expect_code": "VALIDATION_FAILED"
            },
            {
                "name": "invalid_days_range",
                "payload": {"provider_id": PROVIDER_ID, "days_range": 0},
                "expect_success": False,
                "expect_code": "VALIDATION_FAILED"
            },
            {
                "name": "invalid_target_date",
                "payload": {"provider_id": PROVIDER_ID, "target_date": "2026-13-40"},
                "expect_success": False,
                "expect_code": "VALIDATION_FAILED"
            },
            {
                "name": "service_not_found",
                "payload": {"provider_id": PROVIDER_ID, "service_id": "11111111-1111-1111-1111-111111111111"},
                "expect_success": False,
                "expect_code": "SERVICE_NOT_FOUND"
            },
            {
                "name": "happy_provider_only",
                "payload": {"provider_id": PROVIDER_ID, "days_range": 3},
                "expect_success": True
            },
            {
                "name": "happy_with_service",
                "payload": {"provider_id": PROVIDER_ID, "service_id": SERVICE_ID, "days_range": 3},
                "expect_success": True
            },
            {
                "name": "large_range_edge",
                "payload": {"provider_id": PROVIDER_ID, "days_range": 30},
                "expect_success": True
            }
        ]

        failures = 0
        print_step(3, 4, "Ejecutando casos")
        for case in cases:
            result, err = call_wrapper(agent, case['payload'])
            if err:
                print_error(f"{case['name']}: {err}")
                failures += 1
                continue

            if case['expect_success']:
                if not result.get('success'):
                    print_error(f"{case['name']}: expected success, got {result.get('error_code')} {result.get('error_message')}")
                    failures += 1
                else:
                    print_success(f"{case['name']}: success")
            else:
                if result.get('success'):
                    print_error(f"{case['name']}: expected failure, got success")
                    failures += 1
                else:
                    if case.get('expect_code') and result.get('error_code') != case['expect_code']:
                        print_error(f"{case['name']}: expected {case['expect_code']} got {result.get('error_code')}")
                        failures += 1
                    else:
                        print_success(f"{case['name']}: failure as expected ({result.get('error_code')})")

        print_step(4, 4, "Resultados")
        if failures:
            print_error(f"Matrix terminado con {failures} fallas")
            return False

        print_success("Matrix OK")
        return True

    finally:
        agent.delete_workflow(wrapper_id)
        print_info("Workflow wrapper eliminado")


if __name__ == "__main__":
    run_matrix()
