#!/usr/bin/env python3
import requests
import json

API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzYzhiY2JjNi0xMjM3LTQ2OWQtODExNy0yZmY1ZWE0YTY3YjciLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiNzAxOGNhNmYtYWNkZi00MDdmLTg3MmEtYmU4OWFjMzQwNWZlIiwiaWF0IjoxNzcxMDgyNDk2fQ.eahCQeMDXc-hlFabC4pS3sf1C8BSRM1htLoZY1yYl_M"
WORKFLOW_ID = "lDCN0NU7YKNqpHYM"
BASE_URL = "http://localhost:5678"

# Read the updated workflow
with open('/home/manager/Sync/N8N Projects/basic-booking/workflows/BB_00_Global_Error_Handler.json', 'r') as f:
    workflow_data = json.load(f)

# Get current workflow to preserve settings
headers = {"X-N8N-API-KEY": API_KEY}
resp = requests.get(f"{BASE_URL}/api/v1/workflows/{WORKFLOW_ID}", headers=headers)
current = resp.json()

print(f"Current workflow: {current.get('name', 'N/A')}")
print(f"Current nodes: {len(current.get('nodes', []))}")

# Get minimal valid settings
settings_payload = {
    "executionOrder": "v1",
    "saveManualExecutions": True,
    "callerPolicy": "workflowsFromSameOwner"
}

# Update only the nodes and connections
update_payload = {
    "name": current.get("name", "BB_00_Global_Error_Handler"),
    "nodes": workflow_data.get("nodes", []),
    "connections": workflow_data.get("connections", {}),
    "settings": settings_payload
}

print(f"\nNew nodes count: {len(update_payload['nodes'])}")

# Update workflow
resp = requests.put(
    f"{BASE_URL}/api/v1/workflows/{WORKFLOW_ID}",
    headers=headers,
    json=update_payload
)

print(f"\nStatus: {resp.status_code}")
if resp.status_code == 200:
    result = resp.json()
    print(f"Updated: {result.get('name', 'N/A')}")
    print(f"Nodes: {len(result.get('nodes', []))}")
else:
    print(f"Error: {resp.text[:500]}")
