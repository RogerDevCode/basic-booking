import json

# Load HTML
try:
    with open('dashboard_v36_login.html', 'r') as f:
        html_content = f.read()
except FileNotFoundError:
    html_content = "<h1>Error: dashboard_v36_login.html not found</h1>"

# SQL Queries
sql_stats_v33 = """
SELECT 
    (SELECT COUNT(*) FROM bookings WHERE start_time::date = CURRENT_DATE) as today_bookings,
    (SELECT COUNT(*) FROM users) as total_users,
    public.get_tenant_config_json('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') as config;
"""

# JWT GUARD (DEBUG MODE)
JWT_GUARD_JS = r"""
try {
    const headers = $input.all()[0].json.headers;
    const authHeader = headers['authorization'] || headers['Authorization'];

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return [{ json: { authenticated: false, error: true, status: 401, message: "Missing token" } }];
    }

    const token = authHeader.split(' ')[1];
    const parts = token.split('.');
    
    if (parts.length !== 3) {
        return [{ json: { authenticated: false, error: true, status: 401, message: "INVALID_TOKEN_FORMAT: " + token } }];
    }
    
    const payload = parts[1];
    
    // Fix Base64Url Padding logic
    let b64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) {
        b64 += '=';
    }
    
    let decodedStr;
    try {
        decodedStr = Buffer.from(b64, 'base64').toString();
    } catch (e) {
        return [{ json: { authenticated: false, error: true, status: 401, message: "BASE64_ERROR: " + e.message } }];
    }

    let decoded;
    try {
        decoded = JSON.parse(decodedStr);
    } catch (e) {
        return [{ json: { authenticated: false, error: true, status: 401, message: "JSON_ERROR: " + e.message + " | STR: " + decodedStr } }];
    }
    
    if (decoded.exp && Date.now() >= decoded.exp * 1000) {
        return [{ json: { authenticated: false, error: true, status: 401, message: "EXPIRED_TOKEN" } }];
    }
    
    if (decoded.role !== 'admin') {
        return [{ json: { authenticated: false, error: true, status: 403, message: "FORBIDDEN: " + decoded.role } }];
    }

    return [{ json: { ...$input.all()[0].json, user: decoded, authenticated: true, error: false } }];

} catch (e) {
    return [{ json: { authenticated: false, error: true, status: 401, message: "UNKNOWN_ERROR: " + e.message } }];
}
"""

# OTHER JS BLOCKS (Standard)
GUARD_LOGIN_JS = r"""
const body = $input.all()[0].json.body || {};
return [{ json: { username: String(body.username || ''), password: String(body.password || '') } }];
"""

SIGN_JWT_JS = r"""
const crypto = require('crypto');
const user = $input.all()[0].json;
const secret = process.env.JWT_SECRET || 'SUPER_SECRET_KEY_CHANGE_ME';
const header = { alg: 'HS256', typ: 'JWT' };
const payload = { user_id: user.user_id, tenant_id: user.tenant_id, role: user.role, exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60) };
const base64Url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const unsigned = base64Url(header) + '.' + base64Url(payload);
const signature = crypto.createHmac('sha256', secret).update(unsigned).digest('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
return [{ json: { token: unsigned + '.' + signature } }];
"""

CONFIG_GUARD_JS = r"""
try {
    const body = $input.all()[0].json.body || {};
    return [{ json: { ...body, valid: true } }];
} catch (e) {
    return [{ json: { error: true, status: 400, message: "Invalid JSON body" } }];
}
"""

LOGGING_JS = r"""const items = $input.all(); return items;"""

# ... (Rest of WF definition similar to V40 but with JWT_GUARD_JS updated)
# I will output the full WF logic here to ensure it's complete

wf = {
    "name": "BB_06_Admin_Dashboard_JWT_Debug",
    "nodes": [
        { "parameters": { "httpMethod": "GET", "path": "admin-v3", "responseMode": "lastNode" }, "id": "web_html", "name": "GET /admin", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 0] },
        { "parameters": { "respondWith": "text", "responseBody": html_content, "options": { "responseHeaders": { "entries": [{ "name": "Content-Type", "value": "text/html" }] } } }, "id": "resp_html", "name": "Serve HTML", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [250, 0] },

        { "parameters": { "httpMethod": "POST", "path": "api/login-v3", "responseMode": "responseNode" }, "id": "web_login", "name": "POST /api/login", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 1400] },
        { "parameters": { "jsCode": GUARD_LOGIN_JS }, "id": "guard_login", "name": "Guard: Login", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [200, 1400] },
        { "parameters": { "operation": "executeQuery", "query": "SELECT * FROM public.verify_admin_credentials('{{ $json.username }}', '{{ $json.password }}')" }, "id": "db_verify", "name": "DB: Verify", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [400, 1400], "credentials": {"postgres": {"name": "Postgres Neon"}} },
        { "parameters": { "dataType": "boolean", "value1": "={{ $json.valid }}", "rules": { "rules": [{"value2": True, "outputKey": "valid"}] }, "fallbackOutput": 1 }, "id": "check_creds", "name": "Check Credentials", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [600, 1400] },
        { "parameters": { "jsCode": SIGN_JWT_JS }, "id": "sign_jwt", "name": "Code: Sign JWT", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [800, 1400] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ { success: true, token: $json.token } }}" }, "id": "resp_login_ok", "name": "Respond: Success", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [1000, 1400] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ { error: true, message: 'Invalid credentials' } }}", "options": { "responseCode": 401 } }, "id": "resp_login_fail", "name": "Respond: Fail", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [800, 1600] },

        { "parameters": { "httpMethod": "GET", "path": "api/stats-v3", "responseMode": "responseNode" }, "id": "web_stats", "name": "GET /api/stats", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 200] },
        { "parameters": { "jsCode": JWT_GUARD_JS }, "id": "auth_stats", "name": "Auth: Stats", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [200, 200] },
        { "parameters": { "dataType": "boolean", "value1": "={{ $json.authenticated }}", "rules": { "rules": [{"value2": True, "outputKey": "success"}] }, "fallbackOutput": 1 }, "id": "check_stats", "name": "Check Auth Stats", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [400, 200] },
        { "parameters": { "operation": "executeQuery", "query": sql_stats_v33 }, "id": "db_stats", "name": "DB: Stats", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [600, 200], "credentials": {"postgres": {"name": "Postgres Neon"}} },
        { "parameters": { "respondWith": "json", "responseBody": "={{ { stats: { today_bookings: $json.today_bookings, total_users: $json.total_users }, config: $json.config } }}" }, "id": "resp_stats", "name": "Respond Stats", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [800, 200] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ $json }}", "options": { "responseCode": 401 } }, "id": "err_stats", "name": "401 Stats", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [600, 400] }
    ],
    "connections": {
        "GET /admin": {"main": [[{"node": "Serve HTML", "type": "main", "index": 0}]]},
        "POST /api/login": {"main": [[{"node": "Guard: Login", "type": "main", "index": 0}]]},
        "Guard: Login": {"main": [[{"node": "DB: Verify", "type": "main", "index": 0}]]},
        "DB: Verify": {"main": [[{"node": "Check Credentials", "type": "main", "index": 0}]]},
        "Check Credentials": { "main": [ [{"node": "Code: Sign JWT", "type": "main", "index": 0}], [{"node": "Respond: Fail", "type": "main", "index": 0}] ] },
        "Code: Sign JWT": {"main": [[{"node": "Respond: Success", "type": "main", "index": 0}]]},
        "GET /api/stats": {"main": [[{"node": "Auth: Stats", "type": "main", "index": 0}]]},
        "Auth: Stats": {"main": [[{"node": "Check Auth Stats", "type": "main", "index": 0}]]},
        "Check Auth Stats": { "main": [ [{"node": "DB: Stats", "type": "main", "index": 0}], [{"node": "401 Stats", "type": "main", "index": 0}] ] },
        "DB: Stats": {"main": [[{"node": "Respond Stats", "type": "main", "index": 0}]]}
    },
    "settings": {"executionOrder": "v1"}
}

with open('workflows/BB_06_Admin_Dashboard_JWT.json', 'w') as f:
    json.dump(wf, f, indent=2)
print("✅ BB_06 V41 (Debug Mode) Generated.")
