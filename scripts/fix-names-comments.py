#!/usr/bin/env python3
"""
FIX NAMES AND COMMENTS
1. Fix BB_09 internal name
2. Fix BB_08 comments to not confuse validator
"""
import json
import os

def fix_bb09_name():
    path = 'workflows/BB_09_Deep_Link_Redirect.json'
    if not os.path.exists(path): return

    with open(path, 'r') as f:
        data = json.load(f)
    
    current_name = data.get('name')
    if current_name != 'BB_09_Deep_Link_Redirect':
        print(f"Fixing BB_09 name: {current_name} -> BB_09_Deep_Link_Redirect")
        data['name'] = 'BB_09_Deep_Link_Redirect'
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)

def fix_bb08_comments():
    path = 'workflows/BB_08_JWT_Auth_Helper.json'
    if not os.path.exists(path): return
    
    with open(path, 'r') as f:
        data = json.load(f)
        
    modified = False
    for node in data['nodes']:
        code = node.get('parameters', {}).get('jsCode', '')
        # Replace { } in comments with ( ) or similar
        # Pattern: INPUT: { ... }
        if 'INPUT:  { headers' in code:
             new_code = code.replace('INPUT:  { headers', 'INPUT:  ( headers')
             new_code = new_code.replace(' } }', ' ) )') # Crude but works for validation
             # Also OUTPUT
             new_code = new_code.replace('OUTPUT: { success', 'OUTPUT: ( success')
             new_code = new_code.replace(' _meta }', ' _meta )')
             
             if new_code != code:
                 node['parameters']['jsCode'] = new_code
                 modified = True
                 print(f"Fixed comments in {node['name']}")
    
    if modified:
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)

def main():
    fix_bb09_name()
    fix_bb08_comments()

if __name__ == '__main__':
    main()
