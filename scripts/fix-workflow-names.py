#!/usr/bin/env python3
"""
Fix remaining WORKFLOW_ID mismatches
The workflow names should NOT include .json extension
"""
import json
import re

def fix_workflow_id_in_file(filepath):
    """Fix WORKFLOW_ID in a single file"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Get the correct workflow name (without .json)
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', '')
    
    # If workflow name ends with .json, that's the issue
    if '.json' in workflow_name:
        correct_name = workflow_name.replace('.json', '')
        print(f"Fixing {filepath}: '{workflow_name}' -> '{correct_name}'")
        
        # Fix in JSON data
        data['name'] = correct_name
        
        # Save
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        
        return True
    
    return False

def main():
    import os
    
    workflows_dir = 'workflows'
    fixed = 0
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.startswith('BB_') and filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            if fix_workflow_id_in_file(filepath):
                fixed += 1
    
    print(f"\n✅ Fixed {fixed} workflow names")
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
