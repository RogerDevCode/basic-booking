#!/usr/bin/env python3
"""
ZERO DEBT FIX: Strengthen validation to catch ALL invalid telegram_id values
Fixes tests #23 (SQL injection), #27 (NoSQL), #32 (boolean false)
"""

import json

# Leer workflow
with open("workflows/BB_02_Security_Firewall.json", 'r', encoding='utf-8') as f:
    workflow = json.load(f)

# Código de validación REFORZADO (Zero Tolerance)
zero_debt_validation = '''// UNIVERSAL GUARD: PATTERN E (Defensive Programming) - ZERO DEBT VERSION
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
            // ZERO DEBT: STRICT telegram_id validation
            const rawTelegramId = input.user.telegram_id;
            
            // Check presence
            if (rawTelegramId == null || rawTelegramId === undefined) {
                errors.push("user.telegram_id is required");
            } 
            // CRITICAL: Reject non-primitives (objects, arrays as single values)
            else if (typeof rawTelegramId === 'object' && rawTelegramId !== null) {
                errors.push("user.telegram_id must be a number, not an object");
            }
            // Reject boolean explicitly (before coercion)
            else if (typeof rawTelegramId === 'boolean') {
                errors.push("user.telegram_id must be a number, not a boolean");
            }
            else {
                // Convert to string first for trimming
                const telegramIdStr = String(rawTelegramId).trim();
                
                // Reject empty strings
                if (telegramIdStr.length === 0) {
                    errors.push("user.telegram_id cannot be empty");
                } else {
                    // Convert to number
                    const telegramId = Number(telegramIdStr);
                    
                    // ZERO DEBT: COMPREHENSIVE number validation
                    if (isNaN(telegramId)) {
                        errors.push("user.telegram_id must be a valid number (got NaN from: " + String(rawTelegramId).substring(0, 50) + ")");
                    } else if (!Number.isFinite(telegramId)) {
                        errors.push("user.telegram_id must be a finite number");
                    } else if (telegramId <= 0) {
                        errors.push("user.telegram_id must be a positive number (> 0)");
                    } else if (!Number.isSafeInteger(telegramId)) {
                        errors.push("user.telegram_id exceeds safe integer range");
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
        node['parameters']['jsCode'] = zero_debt_validation
        print("✓ Updated validation with ZERO DEBT checks")

# Guardar
with open("workflows/BB_02_Security_Firewall.json", 'w', encoding='utf-8') as f:
    json.dump(workflow, f, ensure_ascii=False, indent=2)

print("✓ Workflow updated successfully")
print("\nKey improvements:")
print("  1. Explicit object rejection: typeof === 'object'")
print("  2. Explicit boolean rejection: typeof === 'boolean'")
print("  3. NaN detection: isNaN() check with error message")
print("  4. Finite check: Number.isFinite()")
print("  5. Safe integer check: Number.isSafeInteger()")
print("\nThis catches:")
print("  ✓ SQL injection strings ('1 OR 1=1' → NaN)")
print("  ✓ NoSQL objects ({$ne: null} → object)")
print("  ✓ Boolean false (→ explicit rejection)")
