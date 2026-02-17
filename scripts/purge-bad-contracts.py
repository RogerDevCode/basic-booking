#!/usr/bin/env python3
"""
PURGE BAD CONTRACTS
Removes the specific 'success: false' block that was incorrectly injected into code blocks.
"""
import json
import os
import re

def purge_bad_blocks(filepath):
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
    except:
        return

    modified = False
    filename = os.path.basename(filepath)
    
    # The block to remove. It matches strict indentation and content.
    # We'll use a regex that matches the flexible indentation.
    
    # Pattern:
    # success: false,
    # error_code: 'PROCESSING_ERROR',
    # error_message: 'Processing error',
    # data: null,
    # _meta: {
    #   source: 'subworkflow',
    #   timestamp: new Date().toISOString(),
    #   workflow_id: WORKFLOW_ID
    # },
    
    pattern = r'(?m)^\s+success: false,\s*\n\s+error_code: \'PROCESSING_ERROR\',\s*\n\s+error_message: \'Processing error\',\s*\n\s+data: null,\s*\n\s+_meta: \{\s*\n\s+source: \'subworkflow\',\s*\n\s+timestamp: new Date\(\)\.toISOString\(\),\s*\n\s+workflow_id: WORKFLOW_ID\s*\n\s+\},?\s*\n'
    
    for node in data.get('nodes', []):
        if node.get('type') != 'n8n-nodes-base.code':
            continue
            
        code = node.get('parameters', {}).get('jsCode', '')
        if not code: continue
        
        # Check if we have this pattern
        if 'error_code: \'PROCESSING_ERROR\'' in code:
            new_code = re.sub(pattern, '', code)
            
            # Also clean up the "hanging properties" in Redact PII if possible
            # redact_error: 'NO_INPUT', \n
            # This is harder to regex generically.
            
            if new_code != code:
                node['parameters']['jsCode'] = new_code
                modified = True
                print(f"Purged bad contract from {filename} : {node['name']}")
                
    if modified:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)

def main():
    workflows_dir = 'workflows'
    path = os.path.join(workflows_dir, 'BB_00_Global_Error_Handler.json')
    if os.path.exists(path):
        purge_bad_blocks(path)

if __name__ == '__main__':
    main()
