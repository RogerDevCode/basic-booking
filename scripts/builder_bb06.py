import json

# Load HTML V3.1
try:
    with open('dashboard_v3_1.html', 'r') as f:
        html_content = f.read()
except FileNotFoundError:
    html_content = "<h1>Error: dashboard_v3_1.html not found</h1>"

# SQL: The simplest possible query to verify connectivity
sql_test = "SELECT id, start_time, status FROM bookings LIMIT 10;"

wf = {
    "name": "BB_06_Admin_Dashboard",
    "nodes": [
        { "parameters": { "httpMethod": "GET", "path": "admin", "responseMode": "responseNode" }, "id": "web_html", "name": "GET /admin", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 0] },
        { "parameters": { "respondWith": "text", "responseBody": html_content, "options": { "responseHeaders": { "entries": [{ "name": "Content-Type", "value": "text/html" }] } } }, "id": "resp_html", "name": "Serve HTML", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [250, 0] },

        { "parameters": { "httpMethod": "GET", "path": "api/calendar", "responseMode": "responseNode" }, "id": "web_cal", "name": "GET /api/calendar", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 200] },
        { 
            "parameters": { "operation": "executeQuery", "query": sql_test }, 
            "id": "db_test", "name": "DB: Test", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [250, 200], 
            "credentials": {"postgres": {"id": "aa8wMkQBBzGHkJzn", "name": "Postgres Neon"}},
            "alwaysOutputData": True
        },
        { 
            "parameters": { 
                "jsCode": "const items = $input.all(); return [{ json: { data: items.map(i => i.json), count: items.length } }];" 
            }, 
            "id": "fmt_test", "name": "Format Test", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [450, 200] 
        },
        { "parameters": { "respondWith": "json", "responseBody": "={{ $json }}" }, "id": "resp_test", "name": "Respond Test", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [650, 200] }
    ],
    "connections": {
        "GET /admin": {"main": [[{"node": "Serve HTML", "type": "main", "index": 0}]]},
        "GET /api/calendar": {"main": [[{"node": "DB: Test", "type": "main", "index": 0}]]},
        "DB: Test": {"main": [[{"node": "Format Test", "type": "main", "index": 0}]]},
        "Format Test": {"main": [[{"node": "Respond Test", "type": "main", "index": 0}]]}
    },
    "settings": {"executionOrder": "v1"}
}

with open('workflows/BB_06_Admin_Dashboard.json', 'w') as f:
    json.dump(wf, f, indent=2)
print("✅ BB_06 V9 (Connectivity Test) Generated.")
