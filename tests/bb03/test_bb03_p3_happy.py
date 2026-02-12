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
Happy path test for BB_03 Availability Engine.
Creates wrapper workflow, calls it with a valid provider + service.
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
WRAPPER_NAME = "Test_BB03_Wrapper_Happy"
WEBHOOK_PATH = f"test-bb03-happy-{str(uuid.uuid4())[:8]}"

PROVIDER_ID = "2eebc9bc-c2f8-46f8-9e78-7da0909fcca4"
SERVICE_ID = "a7a019cb-3442-4f57-8877-1b04a1749c01"


def create_wrapper_workflow(agent, input_data):
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
                "id": "prepare-data-node",
                "name": "Prepare Data",
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
                "main": [[{"node": "Prepare Data", "type": "main", "index": 0}]]
            },
            "Prepare Data": {
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


def run_happy_path():
    print_header("Test BB_03: Happy Path")

    agent = init_agent('http://localhost:5678')
    if not agent:
        return False

    print_step(1, 3, "Verificando BB_03")
    wf = verify_workflow_exists(agent, BB_03_ID, "BB_03_Slot_Availability")
    if not wf:
        return False

    print_step(2, 3, "Creando wrapper y ejecutando")
    test_input = {
        "provider_id": PROVIDER_ID,
        "service_id": SERVICE_ID,
        "target_date": "2026-03-01",
        "days_range": 3
    }

    wrapper = create_wrapper_workflow(agent, test_input)
    if not wrapper:
        print_error("No se pudo crear el workflow wrapper")
        return False

    print_success(f"Wrapper creado: {wrapper['id']} (Webhook: {WEBHOOK_PATH})")

    try:
        if agent.activate_workflow(wrapper['id']):
            print_info("Wrapper activado")

        webhook_url = f"{agent.api_url}/webhook/{WEBHOOK_PATH}"
        print_info(f"Llamando a {webhook_url} (POST)...")
        time.sleep(3)
        response = requests.post(webhook_url, json=test_input, timeout=15)
        if response.status_code != 200:
            print_error(f"Webhook response: {response.status_code} - {response.text}")
            return False

        print_success(f"Webhook response: {response.status_code}")
        try:
            result = response.json()
        except Exception:
            print_error(f"Respuesta no es JSON: {response.text}")
            return False

        if not result.get('success', False):
            print_error(f"BB_03 retorno error: {result.get('error_code')} - {result.get('error_message')}")
            return False

        print_success("BB_03 retorno success")
        print_info(f"Provider: {result.get('data', {}).get('provider_id')}")
        print_info(f"Days: {result.get('data', {}).get('date_range', {}).get('total_days')}")
        print_info(f"Slots days count: {len(result.get('data', {}).get('dates', []))}")

        print_step(3, 3, "OK")
        print_success("Happy path completado")
        return True

    finally:
        agent.delete_workflow(wrapper['id'])
        print_info("Workflow wrapper eliminado")


if __name__ == "__main__":
    run_happy_path()
