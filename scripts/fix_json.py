import json

with open('tmp_js1.js', 'r') as f: js_code_1 = f.read()
with open('tmp_js2.js', 'r') as f: js_code_2 = f.read()
with open('tmp_sql.sql', 'r') as f: sql_query = f.read()

wf = {
    "name": "BB_00_Global_Error_Handler",
    "nodes": [
        {
            "parameters": {
                "httpMethod": "POST",
                "path": "error-handler",
                "responseMode": "responseNode",
                "options": {}
            },
            "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
            "name": "Webhook Trigger",
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 1,
            "position": [250, 300]
        },
        {
            "parameters": {
                "jsCode": js_code_1
            },
            "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
            "name": "Sanitize & Validate Input",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [450, 300]
        },
        {
            "parameters": {
                "conditions": {
                    "boolean": [
                        {
                            "value1": "={{ $json.isValid }}",
                            "value2": True
                        }
                    ]
                }
            },
            "id": "00000000-0000-0000-0000-000000000001",
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
            "id": "00000000-0000-0000-0000-000000000002",
            "name": "Respond 400",
            "type": "n8n-nodes-base.respondToWebhook",
            "typeVersion": 1,
            "position": [850, 450]
        },
        {
            "parameters": {
                "jsCode": js_code_2
            },
            "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",
            "name": "Enrich Context",
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [850, 200]
        },
        {
            "parameters": {
                "operation": "executeQuery",
                "query": sql_query,
                "options": {
                    "queryParameters": "={{ [ $json.workflow_name, $json.n8n_execution_id || null, $json.error_type, $json.severity, $json.error_message, $json.error_stack || null, JSON.stringify($json.error_context || {}), $json.tenant_id || null, $json.user_id || null ] }}"
                }
            },
            "id": "d4e5f6a7-b8c9-0123-def1-234567890123",
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
                            "value": "=🚨 *SYSTEM ERROR DETECTED*\n\n*Workflow:* {{ $(\"Sanitize & Validate Input\").item.json.workflow_name }}\n*Severity:* {{ $(\"Sanitize & Validate Input\").item.json.severity }}\n*Type:* {{ $(\"Sanitize & Validate Input\").item.json.error_type }}\n*Message:* {{ $(\"Sanitize & Validate Input\").item.json.error_message }}\n\n*Error ID:* {{ $(\"Log to Database\").item.json.error_id }}\n*Timestamp:* {{ $(\"Log to Database\").item.json.created_at }}"
                        },
                        {
                            "name": "parse_mode",
                            "value": "Markdown"
                        }
                    ]
                }
            },
            "id": "e5f6a7b8-c9d0-1234-ef12-345678901234",
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
            "id": "f6a7b8c9-d0e1-2345-f123-456789012345",
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
