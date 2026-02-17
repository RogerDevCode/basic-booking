#!/usr/bin/env python3
"""
FIX BB_08 FINAL
Index-based string replacement.
"""
import json
import os

def fix_bb08():
    path = 'workflows/BB_08_JWT_Auth_Helper.json'
    with open(path, 'r') as f:
        data = json.load(f)
    
    modified = False
    for node in data['nodes']:
        if node['name'] == 'Extract Token':
            code = node['parameters']['jsCode']
            # validation: true ... _meta
            
            idx_start = code.find('validated: true')
            idx_end = code.find('_meta', idx_start)
            
            if idx_start != -1 and idx_end != -1:
                # Check if we already have a brace
                between = code[idx_start + len('validated: true'):idx_end]
                if '}' not in between:
                    # We need to insert it
                    # We replace the whole chunk between them
                    new_chunk = '\n      },\n      '
                    new_code = code[:idx_start + len('validated: true')] + new_chunk + code[idx_end:]
                    node['parameters']['jsCode'] = new_code
                    modified = True
                    print("✓ Fixed BB_08 Extract Token")

        if node['name'] == 'Verify Token':
            code = node['parameters']['jsCode']
            # token_exp: payload.exp ... _meta
            
            idx_start = code.find('token_exp: payload.exp')
            idx_end = code.find('_meta', idx_start)
            
            if idx_start != -1 and idx_end != -1:
                between = code[idx_start + len('token_exp: payload.exp'):idx_end]
                if '}' not in between:
                    new_chunk = '\n      },\n      '
                    new_code = code[:idx_start + len('token_exp: payload.exp')] + new_chunk + code[idx_end:]
                    node['parameters']['jsCode'] = new_code
                    modified = True
                    print("✓ Fixed BB_08 Verify Token")
                    
        if node['name'] == 'Return Success':
            code = node['parameters']['jsCode']
            if '_meta' not in code:
                # Add it
                # return [{ json: { ... } }];
                # We assume standard structure
                pass

    if modified:
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)

def main():
    fix_bb08()

if __name__ == '__main__':
    main()
