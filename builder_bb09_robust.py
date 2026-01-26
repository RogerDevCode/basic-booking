import json

wf = {
    "name": "BB_09_Deep_Link_Redirect",
    "nodes": [
        { "parameters": { "httpMethod": "GET", "path": "agendar/:slug", "responseMode": "responseNode" }, "id": "web_deep", "name": "GET /agendar/:slug", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 0] },
        
        # FIXED: Direct Interpolation + Always Output Data
        { 
            "parameters": { 
                "operation": "executeQuery", 
                "query": "SELECT slug FROM public.professionals WHERE slug = '{{ $json.params.slug }}' AND deleted_at IS NULL"
            }, 
            "id": "db_lookup", "name": "DB: Find Doctor", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [250, 0], 
            "credentials": {"postgres": {"id": "aa8wMkQBBzGHkJzn", "name": "Postgres Neon"}},
            "alwaysOutputData": True 
        },
        
        # Switch checks if slug exists in the output
        { "parameters": { "dataType": "boolean", "value1": "={{ !!$json.slug }}", "rules": { "rules": [{"value2": True, "outputKey": "found"}] }, "fallbackOutput": 1 }, "id": "check_found", "name": "Found?", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [500, 0] },
        
        # REDIRECT (FOUND)
        { 
            "parameters": { 
                "respondWith": "redirect", 
                "redirectUrl": "={{ 'https://t.me/setcalendarbot?start=' + $json.slug }}" 
            }, 
            "id": "resp_redirect", "name": "Redirect Telegram", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [750, 0] 
        },
        
        # 404 (NOT FOUND)
        { 
            "parameters": { 
                "respondWith": "text", 
                "responseBody": "<h1>Doctor no encontrado</h1><p>Verifica el enlace.</p>",
                "options": { "responseCode": 404, "responseHeaders": { "entries": [{"name": "Content-Type", "value": "text/html"}] } }
            }, 
            "id": "resp_404", "name": "404 Not Found", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [750, 200] 
        }
    ],
    "connections": {
        "GET /agendar/:slug": {"main": [[{"node": "DB: Find Doctor", "type": "main", "index": 0}]]},
        "DB: Find Doctor": {"main": [[{"node": "Found?", "type": "main", "index": 0}]]},
        "Found?": { "main": [ [{"node": "Redirect Telegram", "type": "main", "index": 0}], [{"node": "404 Not Found", "type": "main", "index": 0}] ] }
    },
    "settings": {"executionOrder": "v1"}
}

with open('workflows/BB_09_Deep_Link_Redirect.json', 'w') as f:
    json.dump(wf, f, indent=2)
print("✅ BB_09 (Robust + Always Output) Generated.")
