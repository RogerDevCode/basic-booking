#!/usr/bin/env python3
"""
BB_06 Admin Dashboard - Availability Integration Builder
Adds /api/availability endpoint and updates HTML to show bookings + free slots
"""

import json

# Constants from database
PROFESSIONAL_ID = "2eebc9bc-c2f8-46f8-9e78-7da0909fcca4"
SERVICE_ID = "0833b301-4b02-44f4-92a4-f862575f5f6c"
POSTGRES_CRED_ID = "aa8wMkQBBzGHkJzn"

# Updated HTML with availability visualization
HTML_DASHBOARD = """<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>AutoAgenda Admin 3.1</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src='https://cdn.jsdelivr.net/npm/fullcalendar@6.1.10/index.global.min.js'></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; background-color: #f8fafc; }
        .fc-event { border: none !important; border-radius: 4px; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .fc-v-event .fc-event-main { padding: 4px; }
        .evt-client { font-weight: 700; font-size: 0.85rem; line-height: 1.2; }
        .evt-pro { font-size: 0.75rem; color: #065f46; opacity: 0.9; }
        .evt-available { font-size: 0.75rem; color: #1e40af; font-weight: 600; }
    </style>
</head>
<body class="h-screen flex flex-col">

<!-- Topbar -->
<header class="bg-white border-b border-gray-200 px-6 py-3 flex justify-between items-center z-20 shadow-sm">
    <div class="flex items-center gap-3">
        <div class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white font-bold">A</div>
        <h1 class="text-lg font-bold text-gray-800">AutoAgenda <span class="text-gray-400 font-normal">| Panel Diario</span></h1>
    </div>
</header>

<div class="flex flex-1 overflow-hidden">
    <!-- Sidebar -->
    <aside class="w-72 bg-white border-r border-gray-200 flex flex-col p-6 z-10">
        <div class="mb-8">
            <h2 class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-4">Métricas del Día</h2>
            
            <div class="space-y-4">
                <div class="bg-blue-50 p-4 rounded-xl border border-blue-100">
                    <div class="text-xs text-blue-500 font-bold uppercase mb-1">Citas Reservadas</div>
                    <div class="flex items-end gap-2">
                        <div id="metric-booked" class="text-3xl font-bold text-blue-700">0</div>
                        <div class="text-sm text-blue-400 mb-1">eventos</div>
                    </div>
                </div>

                <div class="bg-green-50 p-4 rounded-xl border border-green-100">
                    <div class="text-xs text-green-500 font-bold uppercase mb-1">Slots Disponibles</div>
                    <div class="flex items-end gap-2">
                        <div id="metric-free" class="text-3xl font-bold text-green-700">--</div>
                        <div class="text-sm text-green-400 mb-1">slots</div>
                    </div>
                    <div class="w-full bg-green-200 rounded-full h-1.5 mt-3">
                        <div id="prog-free" class="bg-green-500 h-1.5 rounded-full transition-all duration-500" style="width: 100%"></div>
                    </div>
                </div>
            </div>
        </div>
    </aside>

    <!-- Calendar -->
    <main class="flex-1 p-6 bg-gray-50 overflow-hidden flex flex-col">
        <div class="flex-1 bg-white rounded-xl shadow-sm border border-gray-200 p-4 overflow-hidden relative">
            <div id='calendar' class="h-full"></div>
        </div>
    </main>
</div>

<script>
    const API = window.location.origin + '/webhook/api';
    let calendar;

    document.addEventListener('DOMContentLoaded', () => {
        const calendarEl = document.getElementById('calendar');
        calendar = new FullCalendar.Calendar(calendarEl, {
            initialView: 'timeGridDay',
            headerToolbar: {
                left: 'prev,next today',
                center: 'title',
                right: 'dayGridMonth,timeGridWeek,timeGridDay'
            },
            locale: 'es',
            slotMinTime: '08:00:00',
            slotMaxTime: '20:00:00',
            allDaySlot: false,
            height: '100%',
            
            events: async function(info, successCallback, failureCallback) {
                try {
                    // Extract date from current view
                    const viewDate = info.start.toISOString().split('T')[0];
                    
                    // Fetch bookings
                    const bookingsUrl = `${API}/calendar?start=${info.startStr}&end=${info.endStr}`;
                    const bookingsRes = await fetch(bookingsUrl);
                    const bookings = await bookingsRes.json();
                    
                    // Fetch availability for current day
                    const availUrl = `${API}/availability?date=${viewDate}`;
                    const availRes = await fetch(availUrl);
                    const availData = await availRes.json();
                    
                    // Map bookings (green solid events)
                    const bookingEvents = bookings.map(e => ({
                        id: e.id,
                        title: e.client_name || 'Cliente Desconocido',
                        start: e.start,
                        end: e.end,
                        backgroundColor: '#d1fae5',
                        borderColor: '#10b981',
                        textColor: '#065f46',
                        extendedProps: { pro: e.pro_name, type: 'booking' }
                    }));
                    
                    // Map availability (blue background events)
                    let availEvents = [];
                    if (availData.status === 'success' && Array.isArray(availData.slots)) {
                        availEvents = availData.slots.map(slot => ({
                            id: `avail-${slot.start}`,
                            title: 'Disponible',
                            start: slot.start_iso,
                            end: slot.end_iso,
                            backgroundColor: '#dbeafe',
                            borderColor: '#3b82f6',
                            textColor: '#1e40af',
                            display: 'background',
                            extendedProps: { type: 'available' }
                        }));
                    }
                    
                    // Merge and update metrics
                    const allEvents = [...bookingEvents, ...availEvents];
                    updateMetrics(bookingEvents, availEvents);
                    
                    successCallback(allEvents);
                } catch (err) {
                    console.error('Calendar fetch error:', err);
                    failureCallback(err);
                }
            },

            eventContent: function(arg) {
                if (arg.event.extendedProps.type === 'booking') {
                    return {
                        html: `
                            <div class="flex flex-col h-full justify-center px-1">
                                <div class="evt-client">${arg.event.title}</div>
                                <div class="evt-pro">${arg.event.extendedProps.pro}</div>
                            </div>
                        `
                    };
                } else {
                    return {
                        html: `<div class="evt-available text-center">${arg.event.title}</div>`
                    };
                }
            }
        });
        calendar.render();
    });

    function updateMetrics(bookings, availability) {
        const bookedCount = bookings.length;
        const freeCount = availability.length;
        const totalSlots = bookedCount + freeCount;
        const percentFree = totalSlots > 0 ? (freeCount / totalSlots) * 100 : 0;

        document.getElementById('metric-booked').innerText = bookedCount;
        document.getElementById('metric-free').innerText = freeCount;
        document.getElementById('prog-free').style.width = `${percentFree}%`;
    }
</script>
</body>
</html>
"""

def build_workflow():
    """Build the complete BB_06 workflow with availability endpoint"""
    
    workflow = {
        "name": "BB_06_Admin_Dashboard",
        "nodes": [
            # Node 1: GET /admin (HTML Dashboard)
            {
                "parameters": {
                    "httpMethod": "GET",
                    "path": "admin",
                    "responseMode": "responseNode",
                    "options": {}
                },
                "id": "web_admin",
                "name": "GET /admin",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [9344, 880],
                "webhookId": "d8c8e9f0-b881-4a3e-a440-c695ade77956"
            },
            # Node 2: Serve HTML
            {
                "parameters": {
                    "respondWith": "text",
                    "responseBody": HTML_DASHBOARD,
                    "options": {
                        "responseHeaders": {
                            "entries": [
                                {"name": "Content-Type", "value": "text/html"}
                            ]
                        }
                    }
                },
                "id": "serve_html",
                "name": "Serve HTML",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1,
                "position": [9600, 880]
            },
            # Node 3: GET /api/calendar
            {
                "parameters": {
                    "httpMethod": "GET",
                    "path": "api/calendar",
                    "responseMode": "responseNode",
                    "options": {}
                },
                "id": "web_cal",
                "name": "GET /api/calendar",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [9344, 1280],
                "webhookId": "f20677f4-9822-4002-ab47-92a8c4bbd792"
            },
            # Node 4: Extract Calendar Params
            {
                "parameters": {
                    "jsCode": """// Extract query parameters from the webhook request
const input = items[0].json;

// Extract start and end from query parameters
const queryParams = input.query || {};

const startParam = queryParams.start || new Date(Date.now() - 30*24*60*60*1000).toISOString();
const endParam = queryParams.end || new Date(Date.now() + 60*24*60*60*1000).toISOString();

// Validate dates
const startDate = new Date(startParam);
const endDate = new Date(endParam);

if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
    throw new Error('Invalid date format provided');
}

if (startDate > endDate) {
    throw new Error('Start date cannot be after end date');
}

// Return the parameters to be used in the next node
return [{
    json: {
        start_date: startParam,
        end_date: endParam
    }
}];"""
                },
                "id": "extract_params",
                "name": "Extract Params",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [9600, 1280]
            },
            # Node 5: DB Calendar Query
            {
                "parameters": {
                    "operation": "executeQuery",
                    "query": """
SELECT 
    b.id,
    b.start_time,
    b.end_time,
    b.status,
    COALESCE(u.first_name, '') AS first_name,
    COALESCE(u.last_name, '') AS last_name,
    COALESCE(p.name, 'Sin profesional') AS pro_name
FROM bookings b
JOIN users u ON b.user_id = u.id
JOIN professionals p ON b.professional_id = p.id
WHERE b.status != 'cancelled'
  AND b.start_time >= $1::timestamptz
  AND b.end_time   <= $2::timestamptz
ORDER BY b.start_time
LIMIT 500;
""",
                    "options": {
                        "queryParameters": "={{ [ $json.start_date, $json.end_date ] }}"
                    }
                },
                "id": "db_cal",
                "name": "DB: Calendar",
                "type": "n8n-nodes-base.postgres",
                "typeVersion": 2.4,
                "position": [9856, 1280],
                "credentials": {
                    "postgres": {
                        "id": POSTGRES_CRED_ID,
                        "name": "Postgres Neon"
                    }
                },
                "alwaysOutputData": True,
                "continueOnFail": True
            },
            # Node 6: Format Calendar
            {
                "parameters": {
                    "jsCode": """// Versión más segura y tolerante a diferentes formatos que devuelve Postgres en n8n

const inputItems = $input.all();

let events = [];

// Caso 1: No hay items → devolvemos array vacío
if (!inputItems || inputItems.length === 0) {
  return [{ json: [] }];
}

// Caso 2: Hay items, pero vienen en formatos diferentes
for (const item of inputItems) {
  // Posibles estructuras reales que vemos en diferentes versiones
  let data = null;

  if (item.json && typeof item.json === 'object' && !Array.isArray(item.json)) {
    data = item.json;
  }
  else if (item.json && Array.isArray(item.json)) {
    // Caso raro: postgres devolvió array directamente
    events.push(...item.json.map(record => formatRecord(record)));
    continue;
  }
  else if (item.json === null || item.json === undefined) {
    // Item vacío (típico cuando 0 rows + alwaysOutputData)
    continue;
  }
  else if (typeof item === 'object' && Object.keys(item).length > 0) {
    // Último recurso: el dato está directamente en el item (sucede en algunas versiones)
    data = item;
  }

  if (data) {
    const formatted = formatRecord(data);
    if (formatted) events.push(formatted);
  }
}

// Función auxiliar de formateo
function formatRecord(i) {
  if (!i || !i.id || !i.start_time || !i.end_time) {
    return null; // registro inválido
  }

  const clientName = `${i.first_name || ''} ${i.last_name || ''}`.trim() || 'Cliente';

  return {
    id: i.id,
    title: clientName,
    client_name: clientName,
    pro_name: i.pro_name || 'Profesional',
    start: new Date(i.start_time).toISOString(),
    end: new Date(i.end_time).toISOString(),
    status: i.status || 'unknown',
    type: 'booking'
  };
}

// Siempre devolvemos exactamente UN ítem con array
return [{ json: events }];"""
                },
                "id": "fmt_cal",
                "name": "Format Calendar",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [10112, 1280]
            },
            # Node 7: Respond Calendar
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": "={{ $json }}",
                    "options": {}
                },
                "id": "resp_cal",
                "name": "Respond Calendar",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1,
                "position": [10368, 1280]
            },
            # Node 8: GET /api/availability (NEW)
            {
                "parameters": {
                    "httpMethod": "GET",
                    "path": "api/availability",
                    "responseMode": "responseNode",
                    "options": {}
                },
                "id": "web_avail",
                "name": "GET /api/availability",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [9344, 1680],
                "webhookId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            },
            # Node 9: Extract Availability Params (NEW)
            {
                "parameters": {
                    "jsCode": """// PATTERN A: String Validation + PATTERN D: Safe Object Navigation
const input = items[0].json || {};
const queryParams = input.query || {};

// Extract and validate date (PATTERN A)
const rawDate = queryParams.date;
if (rawDate == null) {
    return [{ json: { error: true, message: "Missing 'date' parameter", status: 400 } }];
}
const dateStr = String(rawDate).trim();
if (dateStr.length === 0) {
    return [{ json: { error: true, message: "Empty 'date' parameter", status: 400 } }];
}

// Validate date format (YYYY-MM-DD)
const dateObj = new Date(dateStr);
if (isNaN(dateObj.getTime())) {
    return [{ json: { error: true, message: "Invalid date format. Use YYYY-MM-DD", status: 400 } }];
}

// Hardcoded professional and service IDs (from test data)
const professionalId = '""" + PROFESSIONAL_ID + """';
const serviceId = '""" + SERVICE_ID + """';

return [{
    json: {
        error: false,
        date: dateStr,
        professional_id: professionalId,
        service_id: serviceId
    }
}];"""
                },
                "id": "extract_avail_params",
                "name": "Extract Avail Params",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [9600, 1680]
            },
            # Node 10: Check Params Valid (NEW)
            {
                "parameters": {
                    "dataType": "boolean",
                    "value1": "={{ $json.error }}",
                    "rules": {
                        "rules": [
                            {
                                "value2": True,
                                "outputKey": "error"
                            }
                        ]
                    },
                    "fallbackOutput": 1
                },
                "id": "check_avail",
                "name": "Valid Params?",
                "type": "n8n-nodes-base.switch",
                "typeVersion": 1,
                "position": [9856, 1680]
            },
            # Node 11: Respond Error (NEW)
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": "={{ $json }}",
                    "options": {
                        "responseCode": 400
                    }
                },
                "id": "resp_avail_err",
                "name": "Respond Error",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1,
                "position": [10112, 1830]
            },
            # Node 12: Call BB_03 (NEW)
            {
                "parameters": {
                    "method": "POST",
                    "url": "http://localhost:5678/webhook/availability-v2",
                    "sendBody": True,
                    "specifyBody": "json",
                    "jsonBody": """={
  "professional_id": "{{ $json.professional_id }}",
  "service_id": "{{ $json.service_id }}",
  "date": "{{ $json.date }}"
}""",
                    "options": {}
                },
                "id": "call_bb03",
                "name": "Call BB_03",
                "type": "n8n-nodes-base.httpRequest",
                "typeVersion": 4.2,
                "position": [10112, 1530],
                "continueOnFail": True
            },
            # Node 13: Respond Availability (NEW)
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": "={{ $json }}",
                    "options": {}
                },
                "id": "resp_avail",
                "name": "Respond Availability",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1,
                "position": [10368, 1530]
            },
            # Node 14: GET /api/stats (existing)
            {
                "parameters": {
                    "httpMethod": "GET",
                    "path": "api/stats",
                    "responseMode": "responseNode",
                    "options": {}
                },
                "id": "web_stats",
                "name": "GET /api/stats",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [9344, 1088],
                "webhookId": "78ebb4d4-9eda-4bc5-9296-7c22ffbb3194"
            },
            # Node 15: DB Stats (existing)
            {
                "parameters": {
                    "operation": "executeQuery",
                    "query": """
SELECT 
    (SELECT COUNT(*) FROM bookings WHERE start_time::date = CURRENT_DATE) as today_bookings,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT row_to_json(c) FROM (SELECT reminder_1_hours, reminder_2_hours, is_active FROM notification_configs LIMIT 1) c) as config;
""",
                    "options": {}
                },
                "id": "db_stats",
                "name": "DB: Config",
                "type": "n8n-nodes-base.postgres",
                "typeVersion": 2.4,
                "position": [9600, 1088],
                "credentials": {
                    "postgres": {
                        "id": POSTGRES_CRED_ID,
                        "name": "Postgres Neon"
                    }
                }
            },
            # Node 16: Respond Stats (existing)
            {
                "parameters": {
                    "respondWith": "json",
                    "responseBody": "={{ { stats: { today_bookings: $json.today_bookings, total_users: $json.total_users }, config: $json.config } }}",
                    "options": {}
                },
                "id": "resp_stats",
                "name": "Respond Stats",
                "type": "n8n-nodes-base.respondToWebhook",
                "typeVersion": 1,
                "position": [9808, 1088]
            }
        ],
        "connections": {
            "GET /admin": {
                "main": [[{"node": "Serve HTML", "type": "main", "index": 0}]]
            },
            "GET /api/calendar": {
                "main": [[{"node": "Extract Params", "type": "main", "index": 0}]]
            },
            "Extract Params": {
                "main": [[{"node": "DB: Calendar", "type": "main", "index": 0}]]
            },
            "DB: Calendar": {
                "main": [[{"node": "Format Calendar", "type": "main", "index": 0}]]
            },
            "Format Calendar": {
                "main": [[{"node": "Respond Calendar", "type": "main", "index": 0}]]
            },
            "GET /api/availability": {
                "main": [[{"node": "Extract Avail Params", "type": "main", "index": 0}]]
            },
            "Extract Avail Params": {
                "main": [[{"node": "Valid Params?", "type": "main", "index": 0}]]
            },
            "Valid Params?": {
                "main": [
                    [{"node": "Respond Error", "type": "main", "index": 0}],
                    [{"node": "Call BB_03", "type": "main", "index": 0}]
                ]
            },
            "Call BB_03": {
                "main": [[{"node": "Respond Availability", "type": "main", "index": 0}]]
            },
            "GET /api/stats": {
                "main": [[{"node": "DB: Config", "type": "main", "index": 0}]]
            },
            "DB: Config": {
                "main": [[{"node": "Respond Stats", "type": "main", "index": 0}]]
            }
        },
        "pinData": {},
        "meta": {
            "templateCredsSetupCompleted": True,
            "instanceId": "2498a5873e9e7997621f19aa18febf20755921f48573d014a16ac286a56de675"
        }
    }
    
    return workflow

if __name__ == "__main__":
    workflow = build_workflow()
    output_path = "/home/manager/Sync/N8N Projects/basic-booking/workflows/BB_06_Admin_Dashboard.json"
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)
    
    print(f"✅ BB_06_Admin_Dashboard.json generated successfully")
    print(f"📍 Location: {output_path}")
    print(f"📊 Nodes: {len(workflow['nodes'])}")
    print(f"🔗 Connections: {len(workflow['connections'])}")
    print(f"\n🎯 New Features:")
    print(f"   - GET /api/availability endpoint")
    print(f"   - Calls BB_03 Availability Engine")
    print(f"   - Updated HTML with availability visualization")
    print(f"   - Professional ID: {PROFESSIONAL_ID}")
    print(f"   - Service ID: {SERVICE_ID}")
