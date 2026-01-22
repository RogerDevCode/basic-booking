import json

TARGET_FILE = "workflows/BB_05_Notification_Engine.json"

NEW_SQL = """
WITH config_json AS (
    SELECT public.get_tenant_config_json('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') as data
),
config AS (
    SELECT 
        (data->>'reminder_1_hours')::int * INTERVAL '1 hour' as r1_delta,
        (data->>'reminder_2_hours')::int * INTERVAL '1 hour' as r2_delta,
        (data->>'is_active')::boolean as is_active
    FROM config_json
)
SELECT b.id as booking_id, u.telegram_id, u.first_name, b.start_time, p.name as pro_name,
    CASE 
        WHEN b.reminder_1_sent_at IS NULL AND b.start_time <= (NOW() + c.r1_delta) AND b.start_time > (NOW() + c.r2_delta) THEN 'r1'
        WHEN b.reminder_2_sent_at IS NULL AND b.start_time <= (NOW() + c.r2_delta) THEN 'r2'
    END as r_type
FROM bookings b
JOIN users u ON b.user_id = u.id
JOIN professionals p ON b.professional_id = p.id
CROSS JOIN config c
WHERE c.is_active = TRUE AND b.status = 'confirmed' AND b.start_time > NOW()
AND ((b.reminder_1_sent_at IS NULL AND b.start_time <= (NOW() + c.r1_delta))
     OR (b.reminder_2_sent_at IS NULL AND b.start_time <= (NOW() + c.r2_delta)))
LIMIT 50;
"""

try:
    with open(TARGET_FILE, 'r') as f:
        wf = json.load(f)
    
    fetch_node = next((n for n in wf['nodes'] if n['name'] == 'Fetch'), None)
    
    if fetch_node:
        print("Found 'Fetch' node. Updating query...")
        fetch_node['parameters']['query'] = NEW_SQL
    
    with open(TARGET_FILE, 'w') as f:
        json.dump(wf, f, indent=2)
        
    print("✅ BB_05 Updated Successfully.")

except Exception as e:
    print(f"❌ Error: {e}")
