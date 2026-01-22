#!/usr/bin/env python3
"""
Script para agregar Test Webhook a BB_02_Security_Firewall.json
con validación defensiva completa (Pattern A, D, E)
"""

import json
import sys

def create_test_webhook_node():
    """Crea el nodo de Test Webhook"""
    return {
        "parameters": {
            "path": "test/firewall",
            "httpMethod": "POST",
            "responseMode": "responseNode",
            "options": {}
        },
        "id": "test_webhook",
        "name": "Test Webhook",
        "type": "n8n-nodes-base.webhook",
        "typeVersion": 1.1,
        "position": [0, 400],
        "webhookId": ""
    }

def create_validation_node():
    """Crea el nodo de validación defensiva - MISMO CONTRATO QUE TRIGGER ORIGINAL"""
    validation_code = '''// UNIVERSAL GUARD: PATTERN E (Defensive Programming)
// IMPORTANTE: Este webhook espera LA MISMA estructura que Execute Workflow Trigger
// Para permitir tests unitarios/integración con datos reales
try {
    const input = $input.all()[0].json || {};
    const errors = [];
    
    // ========================================
    // PATTERN D + A: Safe Object Navigation + Validation
    // ========================================
    
    // Validate 'user' object (REQUIRED)
    if (!input || typeof input !== 'object') {
        errors.push("Input must be an object");
    } else {
        // Check 'user' key
        if (!input.user || typeof input.user !== 'object') {
            errors.push("Missing key: user (object required)");
        } else {
            // Validate telegram_id inside user
            const rawTelegramId = input.user.telegram_id;
            if (rawTelegramId == null || rawTelegramId === undefined) {
                errors.push("user.telegram_id is required");
            } else {
                const telegramIdStr = String(rawTelegramId).trim();
                if (telegramIdStr.length === 0) {
                    errors.push("user.telegram_id cannot be empty");
                } else {
                    const telegramId = Number(telegramIdStr);
                    if (isNaN(telegramId) || telegramId <= 0) {
                        errors.push("user.telegram_id must be a positive number");
                    }
                }
            }
            
            // Validate RUT if present (OPTIONAL)
            const rut = input.user.rut;
            if (rut !== null && rut !== undefined && rut !== "") {
                if (typeof rut !== 'string') {
                    errors.push("user.rut must be a string");
                } else {
                    const rutTrimmed = rut.trim();
                    if (rutTrimmed.length > 0) {
                        const rutRegex = /^[0-9]+-[0-9kK]$/;
                        if (!rutRegex.test(rutTrimmed)) {
                            errors.push("user.rut format invalid (expected: 12345678-K)");
                        }
                    }
                }
            }
        }
        
        // Check 'routing' key (REQUIRED)
        if (!input.routing || typeof input.routing !== 'object') {
            errors.push("Missing key: routing (object required)");
        } else {
            // Validate intent if present
            const intent = input.routing.intent;
            if (intent !== null && intent !== undefined && intent !== "") {
                if (typeof intent !== 'string') {
                    errors.push("routing.intent must be a string");
                } else if (intent.trim().length === 0) {
                    errors.push("routing.intent cannot be empty string");
                }
            }
        }
    }
    
    // ========================================
    // FAIL FAST: Return 400 on validation error
    // ========================================
    if (errors.length > 0) {
        return [{ 
            json: { 
                error: true, 
                status: 400, 
                message: "Validation Failed",
                details: errors,
                received: input
            } 
        }];
    }
    
    // ========================================
    // SUCCESS: Pass-through original structure (mismo que trigger)
    // ========================================
    return [{
        json: input  // Sin transformación - misma estructura que Execute Workflow Trigger
    }];
    
} catch (e) {
    // PATTERN E: Universal Guard Error Handler
    return [{ 
        json: { 
            error: true, 
            status: 500, 
            message: "Guard Crash: " + e.message,
            stack: e.stack
        } 
    }];
}'''
    
    return {
        "parameters": {
            "jsCode": validation_code
        },
        "id": "test_validation",
        "name": "Test: Defensive Validation",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [250, 400]
    }

def create_response_node():
    """Crea el nodo de respuesta HTTP"""
    response_code = '''// Check if there's an error from validation
const data = $input.item.json;

if (data.error) {
    // Return error response
    return {
        ...data,
        respondWith: {
            statusCode: data.status || 400,
            headers: {
                'Content-Type': 'application/json'
            }
        }
    };
}

// Success response with security analysis
return {
    success: true,
    security_analysis: data.security || {},
    user: data.user || {},
    message: "Firewall check completed",
    respondWith: {
        statusCode: 200,
        headers: {
            'Content-Type': 'application/json'
        }
    }
};'''
    
    return {
        "parameters": {
            "jsCode": response_code
        },
        "id": "test_response_builder",
        "name": "Test: Build Response",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": [1450, 400]
    }

def create_response_webhook_node():
    """Crea el nodo Respond to Webhook"""
    return {
        "parameters": {
            "respondWith": "={{ $json.respondWith }}",
            "options": {}
        },
        "id": "test_respond",
        "name": "Test: Respond",
        "type": "n8n-nodes-base.respondToWebhook",
        "typeVersion": 1.1,
        "position": [1700, 400]
    }

def modify_workflow(input_file, output_file):
    """Modifica el workflow agregando los nuevos nodos"""
    
    # Leer archivo original
    with open(input_file, 'r', encoding='utf-8') as f:
        workflow = json.load(f)
    
    # Agregar nuevos nodos
    new_nodes = [
        create_test_webhook_node(),
        create_validation_node(),
        create_response_node(),
        create_response_webhook_node()
    ]
    
    workflow['nodes'].extend(new_nodes)
    
    # Agregar conexiones para el flujo de test
    if 'connections' not in workflow:
        workflow['connections'] = {}
    
    # Test Webhook -> Test Validation
    workflow['connections']['Test Webhook'] = {
        "main": [[{
            "node": "Test: Defensive Validation",
            "type": "main",
            "index": 0
        }]]
    }
    
    # Test Validation -> Guard: Input Schema (merge con flujo principal)
    workflow['connections']['Test: Defensive Validation'] = {
        "main": [[{
            "node": "Guard: Input Schema",
            "type": "main",
            "index": 0
        }]]
    }
    
    # Return Data -> Test Response Builder (solo si viene de test)
    # No modificamos las conexiones existentes, agregamos nueva rama paralela
    if 'Return Data' not in workflow['connections']:
        workflow['connections']['Return Data'] = {"main": [[]]}
    
    # Test Response Builder -> Test Respond
    workflow['connections']['Test: Build Response'] = {
        "main": [[{
            "node": "Test: Respond",
            "type": "main",
            "index": 0
        }]]
    }
    
    # Logic: Security Policy -> Test Response Builder (ruta adicional)
    # Agregamos una tercera salida desde Logic: Security Policy
    if 'Logic: Security Policy' in workflow['connections']:
        workflow['connections']['Logic: Security Policy']['main'][0].append({
            "node": "Test: Build Response",
            "type": "main",
            "index": 0
        })

    
    # Guardar archivo modificado
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, ensure_ascii=False, indent=2)
    
    print(f"✓ Workflow modificado exitosamente")
    print(f"✓ Agregados 4 nodos: Test Webhook, Validation, Response Builder, Respond")
    print(f"✓ Total de nodos: {len(workflow['nodes'])}")
    print(f"✓ Guardado en: {output_file}")

if __name__ == "__main__":
    input_file = "workflows/BB_02_Security_Firewall.json"
    output_file = "workflows/BB_02_Security_Firewall.json"
    
    try:
        modify_workflow(input_file, output_file)
        sys.exit(0)
    except Exception as e:
        print(f"✗ Error: {e}", file=sys.stderr)
        sys.exit(1)
