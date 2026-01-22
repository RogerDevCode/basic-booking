import json

# JS Code for Validation
js_code_validation = """// ============================================================================
// NODE: Sanitize & Validate Error Input (STRICT TYPE CHECKING)
// ENFORCEMENT: Fail Fast Methodology
// ============================================================================

const root = items[0].json || {};
const data = root.body ? root.body : root;
let errors = [];

// Rule 1: workflow_name
if (typeof data.workflow_name !== 'string' || data.workflow_name.trim().length === 0) {
    errors.push("Validation: 'workflow_name' must be a non-empty string.");
}

// Rule 2: error_message
if (typeof data.error_message !== 'string' || data.error_message.trim().length === 0) {
    errors.push("Validation: 'error_message' must be a non-empty string.");
}

// Rule 3: Enum Validations
const validErrorTypes = ['VALIDATION', 'DATABASE', 'API', 'NETWORK', 'LOGIC', 'UNKNOWN', 'INFO']; // Added INFO for testing
const et = String(data.error_type || 'UNKNOWN').toUpperCase();
if (data.error_type && !validErrorTypes.includes(et)) {
    errors.push(`Validation: 'error_type' must be one of ${validErrorTypes.join(', ')}.`);
}

if (errors.length > 0) {
    return [{ json: { isValid: false, status: 400, message: errors.join(" ") } }];
}

return [{
    json: {
        isValid: true,
        workflow_name: data.workflow_name.trim(),
        error_message: data.error_message.trim(),
        error_type: et,
        severity: String(data.severity || 'ERROR').toUpperCase(),
        error_stack: data.error_stack || null,
        error_context: data.error_context || data.optional_data || {},
        tenant_id: data.tenant_id || null,
        user_id: data.user_id || (data.optional_data ? data.optional_data.user_id : null)
    }
}];"""

# JS Code for Enrichment
js_code_enrich = """const input = items[0].json;
const timestamp = new Date().toISOString();
const executionId = $execution.id || null;
return [{
    json: {
        ...input,
        created_at: timestamp,
        n8n_execution_id: executionId
    }
}];"""

# Use single quotes for inner string to avoid triple quote issues in python
telegram_message = '=🚨 *SYSTEM ERROR DETECTED*\n\n*Workflow:* {{ $("Sanitize & Validate Input").item.json.workflow_name }}\n*Severity:* {{ $("Sanitize & Validate Input").item.json.severity }}\n*Type:* {{ $("Sanitize & Validate Input").item.json.error_type }}\n*Message:* {{ $("Sanitize & Validate Input").item.json.error_message }}\n\n*Error ID:* {{ $("Log to Database").item.json.error_id }}\n*Timestamp:* {{ $("Log to Database").item.json.created_at }}'

wf = {
    "name": "BB_00_Global_Error_Handler_v3",
    "nodes": [
        {
            "parameters": {
                "httpMethod": "POST",
                "path": "error-handler",
                "responseMode": "responseNode",
                "options": {}
            },
            "id": "a1b2c3d4",
            "name": "Webhook Trigger",
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 1,
            "position": [250, 300]
        },
        {
            "parameters": {"jsCode": js_code_validation},
            "id": "b2c3d4e5",
            "name": "Sanitize & Validate Input",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [450, 300]
        },
        {
            "parameters": {
                "conditions": {
                    "boolean": [{"value1": "={{ $json.isValid }}", "value2": True}]
                }
            },
            "id": "c3d4e5f6",
            "name": "isValid?",
            "type": "n8n-nodes-base.if",
            "typeVersion": 1,
            "position": [650, 300]
        },
        {
            "parameters": {
                "httpCode": "400",
                "responseMode": "onNodeResult",
                "respondWith": "json",
                "responseBody": "={{ {\n  \"status\": \"error\",\n  \"message\": $json.message\n} }}",
                "options": {}
            },
            "id": "d4e5f6a7",
            "name": "Respond 400",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1,
            "position": [850, 450]
        },
        {
            "parameters": {"jsCode": js_code_enrich},
            "id": "e5f6a7b8",
            "name": "Enrich Context",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [850, 200]
        },
        {
            "parameters": {
                "operation": "insert",
                "schema": {"value": "public", "mode": "name"},
                "table": {"value": "system_errors", "mode": "name"},
                "columns": {
                    "mappingMode": "defineBelow",
                    "value": {
                        "workflow_name": "={{ $json.workflow_name }}",
                        "workflow_execution_id": "={{ $json.n8n_execution_id }}",
                        "error_type": "={{ $json.error_type }}",
                        "severity": "={{ $json.severity }}",
                        "error_message": "={{ $json.error_message }}",
                        "error_stack": "={{ $json.error_stack }}",
                        "error_context": "={{ JSON.stringify($json.error_context) }}",
                        "tenant_id": "={{ $json.tenant_id }}",
                        "user_id": "={{ $json.user_id }}"
                    }
                },
                "options": {"returnFields": "error_id, created_at"}
            },
            "id": "f6a7b8c9",
            "name": "Log to Database",
            "type": "n8n-nodes-base.postgres",
            "typeVersion": 2.4,
            "position": [1050, 200],
            "credentials": {
                "postgres": {
                    "id": "aa8wMkQBBzGHkJzn",
                    "name": "Postgres Neon"
                }
            }
        },
        {
            "parameters": {
                "method": "POST",
                "url": "https://api.telegram.org/bot{{ $env.TELEGRAM_BOT_TOKEN }}/sendMessage",
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {
                            "name": "chat_id",
                            "value": "={{ $env.TELEGRAM_ADMIN_CHAT_ID }}"
                        },
                        {
                            "name": "text",
                            "value": telegram_message
                        },
                        {
                            "name": "parse_mode",
                            "value": "Markdown"
                        }
                    ]
                }
            },
            "id": "01234567",
            "name": "Send Telegram Alert",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.2,
            "position": [1250, 200]
        },
        {
            "parameters": {
                "respondWith": "json",
                "responseBody": "={{ {\n  \"status\": \"error_logged\",\n  \"error_id\": $(\"Log to Database\").item.json.error_id,\n  \"timestamp\": $(\"Log to Database\").item.json.created_at\n} }}",
                "options": {}
            },
            "id": "89012345",
            "name": "Respond 200",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1,
            "position": [1450, 200]
        }
    ],
    "connections": {
        "Webhook Trigger": {"main": [[{"node": "Sanitize & Validate Input", "type": "main", "index": 0}]]},
        "Sanitize & Validate Input": {"main": [[{"node": "isValid?", "type": "main", "index": 0}]]},
        "isValid?": {"main": [[{"node": "Enrich Context", "type": "main", "index": 0}], [{"node": "Respond 400", "type": "main", "index": 0}]]},
        "Enrich Context": {"main": [[{"node": "Log to Database", "type": "main", "index": 0}]]},
        "Log to Database": {"main": [[{"node": "Send Telegram Alert", "type": "main", "index": 0}]]},
        "Send Telegram Alert": {"main": [[{"node": "Respond 200", "type": "main", "index": 0}]]}
    },
    "settings": {"executionOrder": "v1"}
}

with open('workflows/BB_00_Global_Error_Handler.json', 'w') as f:
    json.dump(wf, f, indent=2)
