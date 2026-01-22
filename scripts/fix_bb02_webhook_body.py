#!/usr/bin/env python3
"""
FIX: Update validation code to read from webhook body instead of root object
"""

import json

# Leer workflow
with open("workflows/BB_02_Security_Firewall.json", 'r', encoding='utf-8') as f:
    workflow = json.load(f)

# Nuevo código de validación corregido
fixed_validation_code = '''// UNIVERSAL GUARD: PATTERN E (Defensive Programming)
// IMPORTANTE: Este webhook espera LA MISMA estructura que Execute Workflow Trigger
// Para permitir tests unitarios/integración con datos reales
try {
    // FIX: Read from webhook body, not root object
    const webhookData = $input.all()[0].json || {};
    const input = webhookData.body || webhookData;  // Webhook has .body, internal triggers don't
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

# Actualizar nodo
for node in workflow['nodes']:
    if node['name'] == 'Test: Defensive Validation':
        node['parameters']['jsCode'] = fixed_validation_code
        print(f"✓ Updated validation code to read from webhook.body")

# Guardar
with open("workflows/BB_02_Security_Firewall.json", 'w', encoding='utf-8') as f:
    json.dump(workflow, f, ensure_ascii=False, indent=2)

print("✓ Workflow updated successfully")
print("\nKey change:")
print("  OLD: const input = $input.all()[0].json")
print("  NEW: const input = webhookData.body || webhookData")
print("\nThis fixes webhook vs internal trigger compatibility")
