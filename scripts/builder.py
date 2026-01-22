import json
import os

# ==============================================================================
# CONFIGURACIÓN DE JAVASCRIPT (Lógica de Negocio)
# ==============================================================================

# JS: Validación Estricta y Normalización
js_validate = """
const root = items[0].json || {};
const data = root.body ? root.body : root; // Adaptador Universal (Webhook vs Interno)
let errors = [];

// 1. Validaciones de Tipos (Fail Fast)
if (typeof data.workflow_name !== 'string' || data.workflow_name.trim().length === 0) {
    errors.push("Validation: 'workflow_name' must be a non-empty string.");
}
if (typeof data.error_message !== 'string' || data.error_message.trim().length === 0) {
    errors.push("Validation: 'error_message' must be a non-empty string.");
}

// 2. Validación de Enum (Lista Blanca)
const validErrorTypes = ['VALIDATION', 'DATABASE', 'API', 'NETWORK', 'LOGIC', 'UNKNOWN', 'INFO', 'SECURITY'];
const et = String(data.error_type || 'UNKNOWN').toUpperCase();
if (data.error_type && !validErrorTypes.includes(et)) {
    errors.push(`Validation: 'error_type' must be one of ${validErrorTypes.join(', ')}.`);
}

// 3. Retorno Temprano si hay errores
if (errors.length > 0) {
    return [{ json: { isValid: false, status: 400, message: errors.join(" ") } }];
}

// 4. Extracción de Contexto Seguro
const context = data.error_context || data.optional_data || {};
const entityId = context.entity_id || data.entity_id || null;

return [{
    json: {
        isValid: true,
        workflow_name: data.workflow_name.trim(),
        error_message: data.error_message.trim(),
        error_type: et,
        severity: String(data.severity || 'ERROR').toUpperCase(),
        error_stack: data.error_stack || null,
        error_context: context,
        tenant_id: data.tenant_id || null,
        user_id: data.user_id || null,
        entity_id: entityId // Vital para el Firewall
    }
}];
"""

# JS: Enriquecimiento de Datos
js_enrich = """
const input = items[0].json;
return [{
    json: {
        ...input,
        created_at: new Date().toISOString(),
        n8n_execution_id: $execution.id || null
    }
}];
"""

# ==============================================================================
# CONFIGURACIÓN SQL (Consultas Parametrizadas)
# ==============================================================================

# SQL: Upsert para Strikes (Postgres 17)
sql_strike = """
INSERT INTO security_firewall (entity_id, strike_count, last_strike_at)
VALUES ($1, 1, NOW())
ON CONFLICT (entity_id) DO UPDATE
SET strike_count = security_firewall.strike_count + 1,
    last_strike_at = NOW(),
    is_blocked = CASE WHEN security_firewall.strike_count + 1 >= 3 THEN TRUE ELSE security_firewall.is_blocked END,
    blocked_until = CASE WHEN security_firewall.strike_count + 1 >= 3 THEN NOW() + INTERVAL '15 minutes' ELSE security_firewall.blocked_until END
RETURNING strike_count, is_blocked;
"""

# ==============================================================================
# ESTRUCTURA DEL WORKFLOW (n8n JSON Schema)
# ==============================================================================

workflow = {
    "name": "BB_00_Global_Error_Handler",
    "nodes": [
        # 1. Trigger
        {
            "parameters": {"httpMethod": "POST", "path": "error-handler", "responseMode": "responseNode", "options": {}},
            "id": "trigger", "name": "Webhook Trigger", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [100, 300]
        },
        # 2. Validación
        {
            "parameters": {"jsCode": js_validate},
            "id": "sanitize", "name": "Sanitize & Validate Input", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [300, 300]
        },
        # 3. Router Lógico
        {
            "parameters": {"conditions": {"boolean": [{"value1": "={{ $json.isValid }}", "value2": True}]}},
            "id": "is_valid", "name": "isValid?", "type": "n8n-nodes-base.if", "typeVersion": 1, "position": [500, 300]
        },
        # 4. Respuesta Error (400)
        {
            "parameters": {
                "httpCode": "400", "responseMode": "onNodeResult", "respondWith": "json",
                "responseBody": "={{ { \"status\": \"error\", \"message\": $json.message } }}"
            },
            "id": "resp_400", "name": "Respond 400", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [700, 450]
        },
        # 5. Enriquecimiento
        {
            "parameters": {"jsCode": js_enrich},
            "id": "enrich", "name": "Enrich Context", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [700, 200]
        },
        # 6. Log DB (Insert Nativo)
        {
            "parameters": {
                "operation": "insert", "schema": {"value": "public", "mode": "name"}, "table": {"value": "system_errors", "mode": "name"},
                "columns": {"mappingMode": "defineBelow", "value": {
                    "workflow_name": "={{ $json.workflow_name }}", "error_type": "={{ $json.error_type }}",
                    "severity": "={{ $json.severity }}", "error_message": "={{ $json.error_message }}",
                    "error_context": "={{ JSON.stringify($json.error_context) }}",
                    "workflow_execution_id": "={{ $json.n8n_execution_id }}"
                }},
                "options": {"returnFields": "error_id, created_at"}
            },
            "id": "db_log", "name": "Log to Database", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [900, 200],
            "credentials": {"postgres": {"id": "PLACEHOLDER", "name": "Postgres Neon"}}
        },
        # 7. Telegram (HTML Alert)
        {
            "parameters": {
                "resource": "message", "operation": "sendMessage", "chatId": "5391760292",
                "text": "=🚨 <b>SYSTEM ERROR</b>\n\n<b>Workflow:</b> {{ $node['Sanitize & Validate Input'].json.workflow_name }}\n<b>Error:</b> {{ $node['Sanitize & Validate Input'].json.error_message }}\n<b>ID:</b> {{ $json.error_id }}",
                "additionalFields": {"parse_mode": "HTML"}
            },
            "id": "telegram", "name": "Send Telegram Alert", "type": "n8n-nodes-base.telegram", "typeVersion": 1.1, "position": [1100, 200],
            "credentials": {"telegramApi": {"id": "PLACEHOLDER", "name": "Telegram Credentials"}},
            "continueOnFail": True
        },
        # 8. Check Strike (Conditional)
        {
            "parameters": {"conditions": {"string": [{"value1": "={{ $node['Sanitize & Validate Input'].json.entity_id }}", "operation": "isNotEmpty"}]}},
            "id": "check_entity", "name": "Has Entity ID?", "type": "n8n-nodes-base.if", "typeVersion": 1, "position": [1300, 200]
        },
        # 9. Add Strike (Query Execution)
        {
            "parameters": {
                "operation": "executeQuery", "query": sql_strike,
                "options": {"queryParameters": "={{ [ $node['Sanitize & Validate Input'].json.entity_id ] }}"}
            },
            "id": "db_strike", "name": "Firewall: Add Strike", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [1500, 100],
            "credentials": {"postgres": {"id": "PLACEHOLDER", "name": "Postgres Neon"}}
        },
        # 10. Respuesta OK (200)
        {
            "parameters": {
                "respondWith": "json",
                "responseBody": "={{ { \"status\": \"error_logged\", \"error_id\": $node['Log to Database'].json.error_id } }}"
            },
            "id": "resp_200", "name": "Respond 200", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [1700, 300]
        }
    ],
    "connections": {
        "Webhook Trigger": {"main": [[{"node": "Sanitize & Validate Input", "type": "main", "index": 0}]]},
        "Sanitize & Validate Input": {"main": [[{"node": "isValid?", "type": "main", "index": 0}]]},
        "isValid?": {"main": [[{"node": "Enrich Context", "type": "main", "index": 0}], [{"node": "Respond 400", "type": "main", "index": 0}]]},
        "Enrich Context": {"main": [[{"node": "Log to Database", "type": "main", "index": 0}]]},
        "Log to Database": {"main": [[{"node": "Send Telegram Alert", "type": "main", "index": 0}]]},
        "Send Telegram Alert": {"main": [[{"node": "Has Entity ID?", "type": "main", "index": 0}]]},
        "Has Entity ID?": {"main": [[{"node": "Firewall: Add Strike", "type": "main", "index": 0}], [{"node": "Respond 200", "type": "main", "index": 0}]]},
        "Firewall: Add Strike": {"main": [[{"node": "Respond 200", "type": "main", "index": 0}]]}
    },
    "settings": {"executionOrder": "v1"}
}

# Generación del Archivo
output_path = 'workflows/BB_00_Global_Error_Handler.json'
with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(workflow, f, indent=2, ensure_ascii=False)

print(f"✅ Workflow generado exitosamente: {output_path}")