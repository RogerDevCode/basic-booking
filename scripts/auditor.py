import json
import os
import re

WORKFLOWS = [
    "workflows/BB_03_Availability_Engine.json",
    "workflows/BB_04_Booking_Transaction.json",
    "workflows/BB_05_Notification_Engine.json",
    "workflows/BB_06_Admin_Dashboard.json"
]

def audit_workflow(path):
    print(f"\n🔍 Auditing {path}...")
    try:
        with open(path, 'r') as f:
            wf = json.load(f)
    except json.JSONDecodeError as e:
        print(f"  ❌ FATAL: Invalid JSON syntax: {e}")
        return False

    nodes = wf.get('nodes', [])
    node_names = [n['name'] for n in nodes]
    
    # 1. Check Guard Presence (Input Validation)
    guards = [n for n in nodes if "Guard" in n['name'] or "Prep" in n['name'] or "Format" in n['name']]
    if not guards:
        print(f"  ⚠️  WARNING: No explicit 'Guard' or 'Prep' node found.")
    else:
        print(f"  ✅ Guard Node found: {[n['name'] for n in guards]}")
        # Deep check JS code for validation patterns
        for g in guards:
            code = g['parameters'].get('jsCode', '')
            if 'error: true' in code or 'throw new Error' in code:
                print(f"    - '{g['name']}' implements Error Reporting.")
            else:
                print(f"    - ⚠️  '{g['name']}' might lack explicit error reporting.")
            
            if '!input' in code or 'length === 0' in code or 'typeof' in code:
                 print(f"    - '{g['name']}' implements Null/Type checks.")
            else:
                 print(f"    - ⚠️  '{g['name']}' might lack strict type checks.")

    # 2. Check Logging Presence
    loggers = [n for n in nodes if "Log Output" in n['name']]
    if not loggers:
        print(f"  ❌ FAIL: No Logging nodes found.")
    else:
        print(f"  ✅ Logging Nodes: {len(loggers)} found.")

    # 3. Check for Dangerous Patterns (Throwing errors directly instead of returning JSON)
    for n in nodes:
        if n['type'] == 'n8n-nodes-base.code':
            code = n['parameters'].get('jsCode', '')
            if 'throw new Error' in code and 'try {' not in code:
                 print(f"  ⚠️  WARNING: Node '{n['name']}' throws Error without Try-Catch (Potential Crash).")

    return True

print("=== AUTOAGENDA FINAL AUDIT ===")
for w in WORKFLOWS:
    if os.path.exists(w):
        audit_workflow(w)
    else:
        print(f"\n❌ File not found: {w}")