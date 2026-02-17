#!/usr/bin/env python3
"""
Fix nested json structures and add missing data fields
"""
import json
import re

def fix_nested_json_structure(code):
    """Fix json: { json: { ... } } to json: { ... }"""
    # Pattern: return [{\n    json: {\n    json: {
    # Replace with: return [{\n    json: {
    
    pattern1 = r'return \[\{\s*json:\s*\{\s*json:\s*\{'
    replacement1 = 'return [{\n    json: {'
    
    code = re.sub(pattern1, replacement1, code)
    
    # Fix closing braces - remove extra }
    # Pattern: }\n  ,\n      _meta:
    # Replace with: ,\n      _meta:
    pattern2 = r'\}\s*,\s*_meta:'
    replacement2 = ',\n      _meta:'
    
    code = re.sub(pattern2, replacement2, code)
    
    return code

def add_data_field(code):
    """Add data: null field if missing"""
    if 'data:' in code or '"data":' in code:
        return code
    
    # Add data before _meta
    pattern = r'(error_message:\s*[^,]+),(\s*_meta:)'
    replacement = r'\1,\n      data: null,\2'
    
    code = re.sub(pattern, replacement, code)
    
    # Also add to success cases
    pattern2 = r'(validated_config:\s*\{[^}]+\}),(\s*warnings:)'
    replacement2 = r'\1,\n      data: null,\2'
    
    code = re.sub(pattern2, replacement2, code)
    
    return code

def fix_workflow(filepath, nodes_to_fix):
    """Fix specific nodes in a workflow"""
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    modified = False
    
    for node in data.get('nodes', []):
        if node.get('name') in nodes_to_fix and node.get('type') == 'n8n-nodes-base.code':
            code = node.get('parameters', {}).get('jsCode', '')
            original = code
            
            # Fix nested structure
            code = fix_nested_json_structure(code)
            
            # Add data field
            code = add_data_field(code)
            
            if code != original:
                node['parameters']['jsCode'] = code
                modified = True
                print(f"  ✓ Fixed {node['name']}")
    
    if modified:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
    
    return modified

def main():
    print("="*60)
    print("Fixing Nested JSON Structures")
    print("="*60)
    
    workflows = [
        ('workflows/BB_03_06_ValidateConfig.json', ['Paranoid Guard', 'Apply Config Rules']),
        ('workflows/BB_07_Notification_Retry_Worker.json', ['Log Summary']),
        ('workflows/BB_05_Notification_Engine.json', ['Log Output (Respond)']),
        ('workflows/BB_04_Validate_Input.json', ['Validate Logic']),
        ('workflows/BB_04_Booking_Transaction.json', ['Guard']),
        ('workflows/BB_08_JWT_Auth_Helper.json', ['Extract Token', 'Verify Token']),
    ]
    
    total = 0
    for filepath, nodes in workflows:
        print(f"\n{filepath}:")
        if fix_workflow(filepath, nodes):
            total += 1
    
    print("\n" + "="*60)
    print(f"Fixed {total} workflows")
    print("="*60)
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
