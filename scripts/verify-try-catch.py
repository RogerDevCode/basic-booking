#!/usr/bin/env python3
"""
Verify that all Code Nodes have try-catch blocks
"""
import json
import os
import sys

def check_code_node(node, workflow_name):
    """Check if Code Node has try-catch"""
    if node.get('type') != 'n8n-nodes-base.code':
        return None
    
    node_name = node.get('name', 'Unknown')
    js_code = node.get('parameters', {}).get('jsCode', '')
    
    has_try = 'try {' in js_code or 'try{' in js_code
    has_catch = 'catch' in js_code
    
    if not (has_try and has_catch):
        return {
            'workflow': workflow_name,
            'node': node_name,
            'has_try': has_try,
            'has_catch': has_catch
        }
    
    return None

def verify_workflow(filepath):
    """Verify a single workflow"""
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', os.path.basename(filepath))
    issues = []
    
    for node in data.get('nodes', []):
        issue = check_code_node(node, workflow_name)
        if issue:
            issues.append(issue)
    
    return issues

def main():
    workflows_dir = 'workflows'
    all_issues = []
    
    print("Verifying Try-Catch Compliance...")
    print("=" * 60)
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.startswith('BB_') and filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            issues = verify_workflow(filepath)
            all_issues.extend(issues)
    
    # Report
    if all_issues:
        print(f"\n❌ Found {len(all_issues)} Code Nodes without try-catch:\n")
        
        current_workflow = None
        for issue in all_issues:
            if issue['workflow'] != current_workflow:
                current_workflow = issue['workflow']
                print(f"\n{current_workflow}:")
            
            status = []
            if not issue['has_try']:
                status.append('missing try')
            if not issue['has_catch']:
                status.append('missing catch')
            
            print(f"  - Node '{issue['node']}': {', '.join(status)}")
        
        return 1
    else:
        print("\n✅ All Code Nodes have try-catch blocks!")
        return 0

if __name__ == '__main__':
    sys.exit(main())
