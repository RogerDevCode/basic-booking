#!/usr/bin/env python3
"""
REPAIR BAD EDITS V2
Fix the syntax errors caused by the aggressive fix-all-contracts.py script.
"""
import json
import os
import re

def clean_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # The bad block pattern based on previous view
    # It seems to be indented with 6 spaces usually
    
    # Regex to match the floating block
    # We want to match this specific sequence of keys and values
    # success: true,
    # error_code: null,
    # error_message: null,
    # data: null,
    # _meta: { ... },
    
    # Pattern matching loosely on whitespace to catch all indentations
    bad_pattern = r'success: true,\s+error_code: null,\s+error_message: null,\s+data: null,\s+_meta: \{\s+source: \'subworkflow\',\s+timestamp: new Date\(\)\.toISOString\(\),\s+workflow_id: WORKFLOW_ID\s+\},\s+'
    
    # We replace it with nothing
    new_content = re.sub(bad_pattern, '', content)
    
    if new_content != content:
        print(f"  Fixed bad blocks in {os.path.basename(filepath)}")
        with open(filepath, 'w') as f:
            f.write(new_content)
        return True
    return False

def add_missing_contract(filepath):
    """Add standard contract fields correctly to return statements"""
    with open(filepath, 'r') as f:
        data = json.load(f)
        
    workflow_id = data.get('name', 'UNKNOWN')
    modified = False
    
    for node in data.get('nodes', []):
        if node.get('type') == 'n8n-nodes-base.code':
            code = node.get('parameters', {}).get('jsCode', '')
            original = code
            
            # Simple check: does it have return [{ json: ... }] but missing fields?
            # We look for the main success return which usually looks like:
            # return [{ json: { ... } }];
            
            # Pattern to find the json object in a return statement
            # This is a heuristic to fix the specific nodes we know are issues
            
            # If we don't have success: true in the code, we probably need it
            if 'success: true' not in code and 'return [{' in code:
                # Naive injection into the first return that looks like a success return
                # or just all returns that look like they return an object
                
                # Replace `return [{ json: {` with `return [{ json: { success: true, error_code: null, ...`
                # expecting the rest of the object to follow.
                
                injection = f""" success: true, error_code: null, error_message: null, data: null, _meta: {{ source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: '{workflow_id}' }}, """
                
                # Only inject if we are sure it's a return statement start
                new_code = code.replace('return [{ json: {', 'return [{ json: {' + injection)
                new_code = new_code.replace('return [{\n    json: {', 'return [{\n    json: {' + injection)
                
                if new_code != code:
                    code = new_code
                    
            if code != original:
                node['parameters']['jsCode'] = code
                modified = True
                print(f"    Added contract to {node.get('name')}")

    if modified:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    return False

def main():
    print("Repairing bad edits V2...")
    workflows = [
        'workflows/BB_03_05_CalculateSlots.json',
        'workflows/BB_04_Booking_Transaction.json',
        'workflows/BB_06_Admin_Dashboard.json',
        'workflows/BB_08_JWT_Auth_Helper.json', # Check if this helps syntax error
        'workflows/BB_07_Notification_Retry_Worker.json'
    ]
    
    for wf in workflows:
        if os.path.exists(wf):
            print(f"Processing {wf}...")
            # 1. Clean format (bad insertions)
            clean_file(wf)
            # 2. Add correct fields
            add_missing_contract(wf)

if __name__ == '__main__':
    main()
