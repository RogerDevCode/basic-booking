import json

# JS: Guard & Normalize (Standard)
js_guard = r"""
const input = items[0].json;
const body = input.body;
if (!body) return [{ json: { error: true, message: "No body" } }];
const message = body.message || body.channel_post;
const chatId = message?.chat?.id;
const text = message?.text || "";
if (!chatId) return [{ json: { error: true, message: "No chat ID" } }];
return [{ json: { chatId: chatId, text: text, firstName: message?.from?.first_name || "User", type: "text" } }];
"""

# JS: Router Logic (New)
js_router = r"""
const text = $json.text;
let action = "unknown";
let slug = null;

if (text.startsWith("/start ref_")) {
    action = "set_context";
    slug = text.replace("/start ref_", "").trim();
} else if (text.startsWith("/book")) {
    action = "book";
} else if (text.startsWith("/help")) {
    action = "help";
}

// Tomorrow date for booking default
const tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
const dateStr = tomorrow.toISOString().split('T')[0];

return [{ json: { ...$json, action, slug, target_date: dateStr } }];
"""

# SQL: Set Context
sql_set_context = """
WITH pro AS (SELECT id, name FROM public.professionals WHERE slug = $2)
UPDATE public.users 
SET last_selected_professional_id = pro.id 
FROM pro
WHERE telegram_id = $1
RETURNING pro.name as doctor_name;
"""

# SQL: Get Context
sql_get_context = """
SELECT u.last_selected_professional_id, p.name as doctor_name
FROM public.users u
LEFT JOIN public.professionals p ON u.last_selected_professional_id = p.id
WHERE u.telegram_id = $1;
"""

wf = {
    "name": "BB_01_Telegram_Gateway",
    "nodes": [
        { "parameters": {"httpMethod": "POST", "path": "telegram-webhook", "responseMode": "responseNode"}, "id": "web", "name": "Webhook", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 0] },
        { "parameters": {"jsCode": js_guard}, "id": "guard", "name": "Guard", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [200, 0] },
        
        # ROUTER
        { "parameters": {"jsCode": js_router}, "id": "router_code", "name": "Analyze Intent", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [400, 0] },
        { "parameters": { "dataType": "string", "value1": "={{ $json.action }}", "rules": { "rules": [{"value2": "set_context", "outputKey": "set_context"}, {"value2": "book", "outputKey": "book"}] } }, "id": "router_switch", "name": "Router", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [600, 0] },

        # --- BRANCH: SET CONTEXT (/start ref_...) ---
        { 
            "parameters": { 
                "operation": "executeQuery", 
                "query": sql_set_context,
                "options": { "queryParameters": { "values": [ { "value": "={{ $json.chatId }}" }, { "value": "={{ $json.slug }}" } ] } }
            }, 
            "id": "db_set", "name": "DB: Set Context", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [800, -200], "credentials": {"postgres": {"name": "Postgres Neon"}} 
        },
        { "parameters": { "content": "✅ Has seleccionado al {{ $json.doctor_name || 'Doctor' }}. Escribe /book para ver horarios." }, "id": "msg_set", "name": "Msg: Context Set", "type": "n8n-nodes-base.set", "typeVersion": 1, "position": [1000, -200] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ $json }}" }, "id": "resp_set", "name": "Respond Set", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [1200, -200] },

        # --- BRANCH: BOOK (/book) ---
        # 1. Get Context
        { 
            "parameters": { 
                "operation": "executeQuery", 
                "query": sql_get_context,
                "options": { "queryParameters": { "values": [ { "value": "={{ $json.chatId }}" } ] } }
            }, 
            "id": "db_get", "name": "DB: Get Context", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [800, 200], "credentials": {"postgres": {"name": "Postgres Neon"}} 
        },
        
        # 2. Check if context exists
        { "parameters": { "dataType": "boolean", "value1": "={{ !!$json.last_selected_professional_id }}", "rules": { "rules": [{"value2": True, "outputKey": "has_context"}] }, "fallbackOutput": 1 }, "id": "check_context", "name": "Has Doctor?", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [1000, 200] },
        
        # 3. NO Context -> Error
        { "parameters": { "content": "⚠️ No has seleccionado un doctor. Por favor usa el enlace que te enviaron." }, "id": "msg_no_ctx", "name": "Msg: No Context", "type": "n8n-nodes-base.set", "typeVersion": 1, "position": [1200, 400] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ $json }}" }, "id": "resp_no_ctx", "name": "Respond Error", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [1400, 400] },

        # 4. YES Context -> Call Availability (The Magic)
        {
            "parameters": {
                "workflowId": { "__rl": True, "value": "BB_03_Availability_Engine", "mode": "list", "cachedResultName": "BB_03_Availability_Engine" },
                "workflowInputs": { "mappingMode": "defineBelow", "value": { "professional_id": "={{ $json.last_selected_professional_id }}", "date": "={{ $node['Analyze Intent'].json.target_date }}" } }
            },
            "id": "exec_avail", "name": "Call 'BB_03'", "type": "n8n-nodes-base.executeWorkflow", "typeVersion": 1.3, "position": [1200, 100]
        },
        
        { "parameters": { "content": "📅 Horarios para {{ $node['DB: Get Context'].json.doctor_name }}: {{ $json.slots ? $json.slots.length : 0 }} disponibles." }, "id": "msg_slots", "name": "Msg: Slots", "type": "n8n-nodes-base.set", "typeVersion": 1, "position": [1450, 100] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ $json }}" }, "id": "resp_slots", "name": "Respond Slots", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [1650, 100] }
    ],
    "connections": {
        "Webhook": {"main": [[{"node": "Guard", "type": "main", "index": 0}]]},
        "Guard": {"main": [[{"node": "Analyze Intent", "type": "main", "index": 0}]]},
        "Analyze Intent": {"main": [[{"node": "Router", "type": "main", "index": 0}]]},
        "Router": { "main": [[{"node": "DB: Set Context", "type": "main", "index": 0}], [{"node": "DB: Get Context", "type": "main", "index": 0}]] },
        
        "DB: Set Context": {"main": [[{"node": "Msg: Context Set", "type": "main", "index": 0}]]},
        "Msg: Context Set": {"main": [[{"node": "Respond Set", "type": "main", "index": 0}]]},
        
        "DB: Get Context": {"main": [[{"node": "Has Doctor?", "type": "main", "index": 0}]]},
        "Has Doctor?": { "main": [ [{"node": "Call 'BB_03'", "type": "main", "index": 0}], [{"node": "Msg: No Context", "type": "main", "index": 0}] ] },
        
        "Msg: No Context": {"main": [[{"node": "Respond Error", "type": "main", "index": 0}]]},
        
        "Call 'BB_03'": {"main": [[{"node": "Msg: Slots", "type": "main", "index": 0}]]},
        "Msg: Slots": {"main": [[{"node": "Respond Slots", "type": "main", "index": 0}]]}
    },
    "settings": {"executionOrder": "v1"}
}

with open('workflows/BB_01_Telegram_Gateway.json', 'w') as f:
    json.dump(wf, f, indent=2)
print("✅ BB_01 V14 (Multi-Doctor) Generated.")
