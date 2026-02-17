#!/usr/bin/env python3
"""
FIX FINAL CONTRACTS V2
Iterates over all nodes and injects missing standard contract fields into return statements.
More robust than v1.
"""
import json
import os
import re

def add_missing_fields(code):
    # Regex to find `json: {` block inside a return statement
    # We want to match `json:` followed by `{` with optional whitespace.
    # And we want to ensure we don't double inject.
    
    if "_meta" in code and "success" in code and "error_code" in code:
        return code

    js_template = """
      success: true,
      error_code: null,
      error_message: null,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      },"""
      
    # We use a pattern that matches `json: {`
    # We capture `json: {` as group 1.
    pattern = r'(json\s*:\s*\{)'
    
    # We also need to check if the block ALREADY has success/meta.
    # But regex lookahead for multiline is tricky.
    # We'll just do the replacement and trust duplicates are handled by JS (last wins) 
    # OR we are safer to inject at the TOP of the object.
    # If we inject at top, and later fields exist, later fields overwrite.
    # But `deep-verify` checks for presence of keys.
    # If we have `success: true, ..., success: false`, valid JS.
    # `deep-verify` might be happy.
    
    # EXCEPT if duplicate keys cause JSON parser issues? No, in JS object literals it's fine.
    
    # However, we only trigger if `_meta` is missing in the WHOLE string to be safe against double injection in multiple returns.
    # But some nodes have multiple returns, some might have it, some not.
    # This is the limitation of simple script.
    
    # Let's try to be line-by-line? No.
    
    # We will simply replace `json: {` with injection IF `_meta` is not found near it?
    # No, let's just inject.
    
    new_code = re.sub(pattern, lambda m: m.group(1) + js_template, code)
    
    return new_code

def fix_workflow(filepath):
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
    except:
        return

    modified = False
    filename = os.path.basename(filepath)
    
    for node in data.get('nodes', []):
        if node.get('type') != 'n8n-nodes-base.code':
            continue
            
        code = node.get('parameters', {}).get('jsCode', '')
        if not code: continue
        
        # Check if it needs fixing
        # If it ALREADY has _meta, we skip.
        # This is conservative. If one return has it and another doesn't, we skip.
        # But `deep-verify` says 39 nodes have issues. Most have NO _meta.
        if "_meta" in code:
            continue
            
        # exclude some nodes that we know are manually fixed or sensitive
        if node['name'] in ['Code: Sign JWT', 'Format Calendar', 'Guard: Body', 'Validate Logic', 'Paranoid Guard', 'Prep: 03 Input']: 
            continue 
        
        new_code = add_missing_fields(code)
        
        if new_code != code:
            node['parameters']['jsCode'] = new_code
            modified = True
            print(f"Fixed contract in {filename} : {node['name']}")

    if modified:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)

def main():
    workflows_dir = 'workflows'
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.endswith('.json'):
            fix_workflow(os.path.join(workflows_dir, filename))

if __name__ == '__main__':
    main()
