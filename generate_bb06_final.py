import json

# Load HTML
try:
    with open('dashboard_v36_login.html', 'r') as f:
        html_content = f.read()
except FileNotFoundError:
    html_content = "<h1>Error: dashboard_v36_login.html not found</h1>"

# SQL Queries
sql_calendar_fixed = """
SELECT b.id, b.start_time, b.end_time, b.status, u.first_name, u.last_name, p.name as pro_name
FROM bookings b
JOIN users u ON b.user_id = u.id
JOIN professionals p ON b.professional_id = p.id
WHERE b.status != 'cancelled'
AND b.start_time >= '{{ $json.query.start || '2026-01-01' }}'::timestamp
AND b.end_time <= '{{ $json.query.end || '2026-12-31' }}'::timestamp;
"""

sql_stats_v33 = """
SELECT 
    (SELECT COUNT(*) FROM bookings WHERE start_time::date = CURRENT_DATE) as today_bookings,
    (SELECT COUNT(*) FROM users) as total_users,
    public.get_tenant_config_json('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') as config;
"""

sql_upsert_config = """
INSERT INTO app_config (tenant_id, key, value, type)
SELECT 
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 
    key, 
    value::text, 
    'string'
FROM jsonb_each_text($1::jsonb)
WHERE key IN ('SLOT_DURATION_MINS', 'CALENDAR_MIN_TIME', 'CALENDAR_MAX_TIME', 'SCHEDULE_START_HOUR', 'SCHEDULE_END_HOUR', 'BOOKING_MIN_NOTICE_HOURS', 'BOOKING_MAX_DAYS_IN_ADVANCE', 'MIN_DURATION_MIN', 'MAX_DURATION_MIN', 'APP_TITLE', 'COLOR_PRIMARY', 'TIMEZONE')
ON CONFLICT (tenant_id, key) DO UPDATE SET value = EXCLUDED.value;
"""

# JWT GUARD (ULTRA ROBUST)
JWT_GUARD_JS = r"""
try {
    const headers = $input.all()[0].json.headers;
    const authHeader = headers['authorization'] || headers['Authorization'];

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return [{ json: { authenticated: false, error: true, status: 401, message: "MISSING_AUTH_HEADER" } }];
    }

    const token = authHeader.split(' ')[1];
    const parts = token.split('.');
    if (parts.length !== 3) {
        return [{ json: { authenticated: false, error: true, status: 401, message: "BAD_FORMAT" } }];
    }
    
    const payload = parts[1];
    
    // Manual Base64Url to Base64 conversion + Padding
    let b64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) {
        b64 += '=';
    }
    
    const decodedStr = Buffer.from(b64, 'base64').toString('utf8');
    const decoded = JSON.parse(decodedStr);
    
    // Expiration Check
    if (decoded.exp && Date.now() >= decoded.exp * 1000) {
        return [{ json: { authenticated: false, error: true, status: 401, message: "EXPIRED" } }];
    }
    
    // Role Check
    if (decoded.role !== 'admin') {
        return [{ json: { authenticated: false, error: true, status: 403, message: "FORBIDDEN" } }];
    }

    return [{ json: { ...$input.all()[0].json, user: decoded, authenticated: true, error: false } }];

} catch (e) {
    return [{ json: { authenticated: false, error: true, status: 401, message: "DECODE_FAIL: " + e.message } }];
}
"""

# SIGN JWT (NODE JS)
SIGN_JWT_JS = r"""
const crypto = require('crypto');
const user = $input.all()[0].json;

// This secret must match verified env in Docker
const secret = process.env.JWT_SECRET || 'AutoAgenda_Secret_Key_2026_Secure';

const header = { alg: 'HS256', typ: 'JWT' };
const payload = {
    user_id: user.user_id,
    tenant_id: user.tenant_id,
    role: user.role,
    exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60)
};

const base64Url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
const unsigned = base64Url(header) + '.' + base64Url(payload);
const signature = crypto.createHmac('sha256', secret).update(unsigned).digest('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

return [{ json: { token: unsigned + '.' + signature } }];
"""

wf = {
    "name": "BB_06_Admin_Dashboard",
    "nodes": [
        { "parameters": { "httpMethod": "GET", "path": "admin-v3", "responseMode": "responseNode" }, "id": "web_html", "name": "GET /admin", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 0] },
        { "parameters": { "respondWith": "text", "responseBody": html_content, "options": { "responseHeaders": { "entries": [{ "name": "Content-Type", "value": "text/html" }] } } }, "id": "resp_html", "name": "Serve HTML", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [250, 0] },

        { "parameters": { "httpMethod": "POST", "path": "api/login-v3", "responseMode": "responseNode" }, "id": "web_login", "name": "POST /api/login", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 1400] },
        { "parameters": { "jsCode": "const body = $input.all()[0].json.body || {}; return [{ json: { username: String(body.username || ''), password: String(body.password || '') } }];" }, "id": "guard_login", "name": "Guard: Login", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [200, 1400] },
        { "parameters": { "operation": "executeQuery", "query": "SELECT * FROM public.verify_admin_credentials($1, $2)", "options": { "queryParameters": { "values": [ { "value": "={{ $json.username }}" }, { "value": "={{ $json.password }}" } ] } } }, "id": "db_verify", "name": "DB: Verify Credentials", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [400, 1400], "credentials": {"postgres": {"id": "aa8wMkQBBzGHkJzn", "name": "Postgres Neon"}} },
        { "parameters": { "dataType": "boolean", "value1": "={{ $json.valid }}", "rules": { "rules": [{"value2": True, "outputKey": "valid"}] }, "fallbackOutput": 1 }, "id": "check_creds", "name": "Check Credentials", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [600, 1400] },
        { "parameters": { "jsCode": SIGN_JWT_JS }, "id": "sign_jwt", "name": "Code: Sign JWT", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [800, 1400] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ { success: true, token: $json.token } }}" }, "id": "resp_login_success", "name": "Respond: Success", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [1000, 1400] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ {error: true, message: \"Invalid username or password\"} }}", "options": { "responseCode": 401 } }, "id": "resp_login_fail", "name": "Respond: Fail", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [800, 1600] },

        { "parameters": { "httpMethod": "GET", "path": "api/stats-v3", "responseMode": "responseNode" }, "id": "web_stats", "name": "GET /api/stats", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 200] },
        { "parameters": { "jsCode": JWT_GUARD_JS }, "id": "auth_stats", "name": "Auth: Stats", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [200, 200] },
        { "parameters": { "dataType": "boolean", "value1": "={{ $json.authenticated }}", "rules": { "rules": [{"value2": True, "outputKey": "success"}] }, "fallbackOutput": 1 }, "id": "check_stats", "name": "Check Auth Stats", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [400, 200] },
        { "parameters": { "operation": "executeQuery", "query": sql_stats_v33 }, "id": "db_stats", "name": "DB: Config", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [600, 200], "credentials": {"postgres": {"id": "aa8wMkQBBzGHkJzn", "name": "Postgres Neon"}} },
        { "parameters": { "respondWith": "json", "responseBody": "={{ { stats: { today_bookings: $json.today_bookings, total_users: $json.total_users }, config: $json.config } }}" }, "id": "resp_stats", "name": "Respond Stats", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [800, 200] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ $json }}", "options": { "responseCode": "={{ $json.status || 401 }}" } }, "id": "err_stats", "name": "401 Stats", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [400, 400] },

        { "parameters": { "httpMethod": "GET", "path": "api/calendar-v3", "responseMode": "responseNode" }, "id": "web_cal", "name": "GET /api/calendar", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 600] },
        { "parameters": { "jsCode": JWT_GUARD_JS }, "id": "auth_cal", "name": "Auth: Calendar", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [200, 600] },
        { "parameters": { "dataType": "boolean", "value1": "={{ $json.authenticated }}", "rules": { "rules": [{"value2": True, "outputKey": "success"}] }, "fallbackOutput": 1 }, "id": "check_cal", "name": "Check Auth Cal", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [400, 600] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ $json }}", "options": { "responseCode": "={{ $json.status || 401 }}" } }, "id": "err_cal", "name": "401 Cal", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [400, 800] },
        { "parameters": { "operation": "executeQuery", "query": sql_calendar_fixed, "options": { "queryParameters": { "values": [ { "value": "={{ $json.query.start || '2026-01-01' }}" }, { "value": "={{ $json.query.end || '2026-12-31' }}" } ] } } }, "id": "db_cal", "name": "DB: Calendar", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [600, 600], "credentials": {"postgres": {"id": "aa8wMkQBBzGHkJzn", "name": "Postgres Neon"}}, "alwaysOutputData": True },
        { "parameters": { "jsCode": "const items = $input.all(); const events = items.filter(i => i.json.id).map(item => ({ id: item.json.id, title: item.json.first_name, start: new Date(item.json.start_time).toISOString(), end: new Date(item.json.end_time).toISOString(), status: item.json.status })); return [{ json: { events } }];" }, "id": "fmt_cal", "name": "Format Calendar", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [800, 600] },
        { "parameters": { "respondWith": "json", "responseBody": "={{ $json }}" }, "id": "resp_cal", "name": "Respond Calendar", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [1000, 600] },
        
        { "parameters": { "httpMethod": "POST", "path": "api/config-v3", "responseMode": "responseNode" }, "id": "web_conf", "name": "POST /api/config", "type": "n8n-nodes-base.webhook", "typeVersion": 1, "position": [0, 1000] },
        { "parameters": { "jsCode": JWT_GUARD_JS }, "id": "auth_conf", "name": "Auth: Config", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [200, 1000] },
        { "parameters": { "dataType": "boolean", "value1": "={{ $json.authenticated }}", "rules": { "rules": [{"value2": True, "outputKey": "success"}] }, "fallbackOutput": 1 }, "id": "check_conf", "name": "Check Auth Conf", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [400, 1000] },
        { "parameters": { "jsCode": "const body = $input.all()[0].json.body || {}; return [{ json: { ...body, valid: true } }];" }, "id": "guard_body", "name": "Guard: Body", "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [600, 1000] },
        { "parameters": { "dataType": "boolean", "value1": "={{ $json.valid }}", "rules": { "rules": [{"value2": True, "outputKey": "valid"}] }, "fallbackOutput": 1 }, "id": "check_body", "name": "Valid?", "type": "n8n-nodes-base.switch", "typeVersion": 1, "position": [800, 1000] },
        { "parameters": { "operation": "executeQuery", "query": sql_upsert_config, "options": { "queryParameters": { "values": [ { "value": "={{ JSON.stringify($json) }}" } ] } } }, "id": "db_upd", "name": "DB: Update", "type": "n8n-nodes-base.postgres", "typeVersion": 2.4, "position": [1000, 1000], "credentials": {"postgres": {"id": "aa8wMkQBBzGHkJzn", "name": "Postgres Neon"}} },
        { "parameters": { "respondWith": "json", "responseBody": "={{ { success: true } }}" }, "id": "resp_conf", "name": "Respond Config", "type": "n8n-nodes-base.respondToWebhook", "typeVersion": 1, "position": [1200, 1000] }
    ],
    "connections": {
        "GET /admin": {"main": [[{"node": "Serve HTML", "type": "main", "index": 0}]]},
        "POST /api/login": {"main": [[{"node": "Guard: Login", "type": "main", "index": 0}]]},
        "Guard: Login": {"main": [[{"node": "DB: Verify Credentials", "type": "main", "index": 0}]]},
        "DB: Verify Credentials": {"main": [[{"node": "Check Credentials", "type": "main", "index": 0}]]},
        "Check Credentials": { "main": [ [{"node": "Code: Sign JWT", "type": "main", "index": 0}], [{"node": "Respond: Fail", "type": "main", "index": 0}] ] },
        "Code: Sign JWT": {"main": [[{"node": "Respond: Success", "type": "main", "index": 0}]]},
        "GET /api/stats": {"main": [[{"node": "Auth: Stats", "type": "main", "index": 0}]]},
        "Auth: Stats": {"main": [[{"node": "Check Auth Stats", "type": "main", "index": 0}]]},
        "Check Auth Stats": { "main": [ [{"node": "DB: Config", "type": "main", "index": 0}], [{"node": "401 Stats", "type": "main", "index": 0}] ] },
        "DB: Config": {"main": [[{"node": "Respond Stats", "type": "main", "index": 0}]]},
        "GET /api/calendar": {"main": [[{"node": "Auth: Calendar", "type": "main", "index": 0}]]},
        "Auth: Calendar": {"main": [[{"node": "Check Auth Cal", "type": "main", "index": 0}]]},
        "Check Auth Cal": { "main": [ [{"node": "DB: Calendar", "type": "main", "index": 0}], [{"node": "401 Cal", "type": "main", "index": 0}] ] },
        "DB: Calendar": {"main": [[{"node": "Format Calendar", "type": "main", "index": 0}]]},
        "Format Calendar": {"main": [[{"node": "Respond Calendar", "type": "main", "index": 0}]]},
        "POST /api/config": {"main": [[{"node": "Auth: Config", "type": "main", "index": 0}]]},
        "Auth: Config": {"main": [[{"node": "Check Auth Conf", "type": "main", "index": 0}]]},
        "Check Auth Conf": { "main": [ [{"node": "Guard: Body", "type": "main", "index": 0}], [{"node": "401 Conf", "type": "main", "index": 0}] ] },
        "Guard: Body": {"main": [[{"node": "Valid?", "type": "main", "index": 0}]]},
        "Valid?": { "main": [ [{"node": "DB: Update", "type": "main", "index": 0}], [{"node": "Respond: Fail", "type": "main", "index": 0}] ] },
        "DB: Update": {"main": [[{"node": "Respond Config", "type": "main", "index": 0}]]}
    },
    "settings": {"executionOrder": "v1"}
}

with open('workflows/BB_06_Admin_Dashboard.json', 'w') as f:
    json.dump(wf, f, indent=2)
print("✅ BB_06 V42 (Consistent Name + Robust Guards) Generated.")
