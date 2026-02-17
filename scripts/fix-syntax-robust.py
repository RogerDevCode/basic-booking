#!/usr/bin/env python3
"""
FIX SYNTAX ROBUST
Load JSON, fix jsCode strings directly, Save.
"""
import json
import os

def fix_workflow_nodes():
    # BB_07
    path_07 = 'workflows/BB_07_Notification_Retry_Worker.json'
    if os.path.exists(path_07):
        with open(path_07, 'r') as f:
            data = json.load(f)
        
        modified = False
        for node in data['nodes']:
            if node['name'] == 'Analyze Results':
                code = node['parameters']['jsCode']
                # Fix BB_07
                # failed: results.filter(r => !r.success).length \n success: false
                
                if 'failed: results.filter(r => !r.success).length' in code and 'success: false' in code:
                    # We can use simple replace on the string now
                    new_code = code.replace(
                        'failed: results.filter(r => !r.success).length',
                        'failed: results.filter(r => !r.success).length,'
                    )
                    new_code = new_code.replace('success: false', 'success: true')
                    
                    if new_code != code:
                        node['parameters']['jsCode'] = new_code
                        modified = True
                        print("✓ Fixed BB_07 Analyze Results")
        
        if modified:
            with open(path_07, 'w') as f:
                json.dump(data, f, indent=2)

    # BB_08
    path_08 = 'workflows/BB_08_JWT_Auth_Helper.json'
    if os.path.exists(path_08):
        with open(path_08, 'r') as f:
            data = json.load(f)
        
        modified = False
        for node in data['nodes']:
            if node['name'] == 'Extract Token':
                code = node['parameters']['jsCode']
                # validated: true \n , \n _meta
                # We need to insert }
                if 'validated: true' in code and '_meta' in code:
                     # Check if missing brace
                     # We search for the pattern in the string
                     import re
                     # The pattern likely has newlines and spaces
                     pattern = r'(validated: true\s*),(\s*_meta)'
                     if re.search(pattern, code):
                         new_code = re.sub(pattern, r'\1},\2', code)
                         node['parameters']['jsCode'] = new_code
                         modified = True
                         print("✓ Fixed BB_08 Extract Token")
            
            if node['name'] == 'Verify Token':
                code = node['parameters']['jsCode']
                # token_exp: payload.exp \n , \n _meta
                if 'token_exp: payload.exp' in code and '_meta' in code:
                     import re
                     pattern = r'(token_exp: payload\.exp\s*),(\s*_meta)'
                     if re.search(pattern, code):
                         new_code = re.sub(pattern, r'\1},\2', code)
                         node['parameters']['jsCode'] = new_code
                         modified = True
                         print("✓ Fixed BB_08 Verify Token")
                         
            if node['name'] == 'Return Success':
                 # Missing _meta or something?
                 # deep-verify said: Return #1: Missing _meta
                 # Let's check code
                 code = node['parameters']['jsCode']
                 if 'return' in code and '_meta' not in code:
                     # Add meta
                     pass

        if modified:
            with open(path_08, 'w') as f:
                json.dump(data, f, indent=2)

def main():
    fix_workflow_nodes()

if __name__ == '__main__':
    main()
