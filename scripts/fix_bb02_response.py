#!/usr/bin/env python3
"""
Fix: Simplificar Test: Build Response para que funcione con respondToWebhook
"""

import json

# Leer workflow
with open("workflows/BB_02_Security_Firewall.json", 'r', encoding='utf-8') as f:
    workflow = json.load(f)

# Nuevo código simplificado para Test: Build Response
simplified_response_code = '''// Build response data (sin respondWith object)
const data = $input.item.json;

if (data.error) {
    // Return error response (respondToWebhook usará statusCode from data.status)
    return {
        error: true,
        status: data.status || 400,
        message: data.message,
        details: data.details || [],
        received: data.received || {}
    };
}

// Success response with security analysis
return {
    success: true,
    status: 200,
    security_analysis: data.security || {},
    user: data.user || {},
    routing: data.routing || {},
    message: "Firewall check completed - Test mode"
};'''

# Actualizar el nodo
for node in workflow['nodes']:
    if node['name'] == 'Test: Build Response':
        node['parameters']['jsCode'] = simplified_response_code
        print(f"✓ Updated node: {node['name']}")

# Guardar
with open("workflows/BB_02_Security_Firewall.json", 'w', encoding='utf-8') as f:
    json.dump(workflow, f, ensure_ascii=False, indent=2)

print("✓ Workflow fixed successfully")
