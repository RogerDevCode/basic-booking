#!/usr/bin/env python3
"""
FIX: Add IF node to route validation errors correctly in BB_02
"""

import json

# Leer workflow
with open("workflows/BB_02_Security_Firewall.json", 'r', encoding='utf-8') as f:
    workflow = json.load(f)

print("Current workflow nodes:", len(workflow['nodes']))

# Crear nodo IF para rutear errores
if_node = {
    "parameters": {
        "conditions": {
            "options": {
                "caseSensitive": True,
                "leftValue": "",
                "typeValidation": "strict"
            },
            "conditions": [
                {
                    "id": "error_detected",
                    "leftValue": "={{ $json.error }}",
                    "rightValue": True,
                    "operator": {
                        "type": "boolean",
                        "operation": "equals"
                    }
                }
            ],
            "combinator": "and"
        },
        "options": {}
    },
    "id": "validation_router",
    "name": "Route: Validation Check",
    "type": "n8n-nodes-base.if",
    "typeVersion": 2,
    "position": [500, 400]
}

# Agregar nodo
workflow['nodes'].append(if_node)
print("✓ Added IF node")

# Actualizar conexiones
# Test: Defensive Validation → Route: Validation Check
workflow['connections']['Test: Defensive Validation'] = {
    "main": [[{
        "node": "Route: Validation Check",
        "type": "main",
        "index": 0
    }]]
}

# Route: Validation Check → TRUE (error) → Test: Build Response
# Route: Validation Check → FALSE (valid) → Guard: Input Schema
workflow['connections']['Route: Validation Check'] = {
    "main": [
        [
            {
                "node": "Test: Build Response",
                "type": "main",
                "index": 0
            }
        ],
        [
            {
                "node": "Guard: Input Schema",
                "type": "main",
                "index": 0
            }
        ]
    ]
}

print("✓ Updated connections")

# Guardar
with open("workflows/BB_02_Security_Firewall.json", 'w', encoding='utf-8') as f:
    json.dump(workflow, f, ensure_ascii=False, indent=2)

print(f"✓ Workflow updated successfully")
print(f"✓ Total nodes: {len(workflow['nodes'])}")
print(f"\n✓ Flow now:")
print("  Test Webhook → Test Validation → IF")
print("    ├─ [ERROR] → Test Response → Test Respond (400)")
print("    └─ [VALID] → Guard: Input Schema → ... → (200)")
