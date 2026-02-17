#!/usr/bin/env python3
"""
Add missing _meta fields and complete standard contract
This script intelligently adds _meta to returns that are missing it
"""
import json
import os
import re

def has_meta_field(code):
    """Check if code has _meta in returns"""
    return '_meta:' in code or '"_meta":' in code or '_meta :' in code

def add_meta_to_returns(code, workflow_id):
    """Add _meta to return statements that don't have it"""
    if has_meta_field(code):
        return code, False
    
    # Find return statements
    lines = code.split('\n')
    modified = False
    new_lines = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Look for return statements with json objects
        if 'return [' in line and 'json:' in line:
            # This is a simple one-line return
            # Check if it has _meta
            if '_meta' not in line:
                # Try to add _meta before the closing braces
                # This is a simple heuristic - may need manual review
                if '}]' in line:
                    # Add _meta before the closing
                    meta_addition = ", _meta: { source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID } }]"
                    line = line.replace('}]', meta_addition)
                    modified = True
        
        new_lines.append(line)
        i += 1
    
    if modified:
        return '\n'.join(new_lines), True
    
    return code, False

def ensure_standard_contract_fields(code):
    """Ensure all returns have the 5 required fields"""
    # This is complex - for now just flag it
    required = ['success', 'error_code', 'error_message', 'data', '_meta']
    
    # Simple check - if any field is missing, flag it
    missing = []
    for field in required:
        if f'{field}:' not in code and f'"{field}":' not in code:
            missing.append(field)
    
    return missing

def process_code_node(node, workflow_id):
    """Process a single Code Node"""
    if node.get('type') != 'n8n-nodes-base.code':
        return False
    
    js_code = node.get('parameters', {}).get('jsCode', '')
    if not js_code:
        return False
    
    node_name = node.get('name', 'Unknown')
    original_code = js_code
    modified = False
    
    # Add _meta if missing
    new_code, was_modified = add_meta_to_returns(js_code, workflow_id)
    if was_modified:
        js_code = new_code
        modified = True
        print(f"    ✓ Added _meta to: {node_name}")
    
    # Check for missing standard contract fields
    missing = ensure_standard_contract_fields(js_code)
    if missing and len(missing) < 5:  # If all 5 are missing, it's probably intentional
        print(f"    ⚠️  {node_name}: Missing fields: {', '.join(missing)}")
    
    if modified:
        node['parameters']['jsCode'] = js_code
    
    return modified

def process_workflow(filepath):
    """Process a single workflow"""
    filename = os.path.basename(filepath)
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', filename.replace('.json', ''))
    workflow_id = workflow_name
    
    print(f"\n{'='*60}")
    print(f"Processing: {filename}")
    print(f"{'='*60}")
    
    # Process all Code Nodes
    modifications = 0
    for node in data.get('nodes', []):
        if process_code_node(node, workflow_id):
            modifications += 1
    
    # Save if modified
    if modifications > 0:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"\n  ✅ Modified {modifications} nodes")
        return modifications
    else:
        print(f"\n  ✓ No modifications needed")
        return 0

def main():
    workflows_dir = 'workflows'
    
    print("Adding missing _meta fields...")
    print("="*60)
    
    # Focus on workflows with known issues
    priority_workflows = [
        'BB_00_Global_Error_Handler.json',
        'BB_02_Security_Firewall.json',
        'BB_06_Admin_Dashboard.json',
        'BB_01_Telegram_Gateway.json',
        'BB_03_00_Main.json',
        'BB_03_02_ProviderData.json',
        'BB_03_03_ScheduleConfig.json',
        'BB_03_04_BookingsData.json',
        'BB_04_Booking_Cancel.json',
        'BB_04_Booking_Create.json',
        'BB_04_Booking_Reschedule.json',
        'BB_04_Booking_Transaction.json',
        'BB_05_Notification_Engine.json',
        'BB_07_Notification_Retry_Worker.json'
    ]
    
    total_modifications = 0
    
    for filename in priority_workflows:
        filepath = os.path.join(workflows_dir, filename)
        if os.path.exists(filepath):
            mods = process_workflow(filepath)
            total_modifications += mods
    
    print("\n" + "="*60)
    print(f"Total nodes modified: {total_modifications}")
    print("="*60)
    print("\n⚠️  Note: Some nodes may still need manual review")
    print("   Run validation again to check remaining issues")
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
