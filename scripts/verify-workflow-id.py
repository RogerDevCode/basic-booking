#!/usr/bin/env python3
"""
Verify that all Code Nodes have WORKFLOW_ID constant
"""
import json
import os
import sys

def check_code_node(node, workflow_name):
    """Check if Code Node has WORKFLOW_ID constant"""
    if node.get('type') != 'n8n-nodes-base.code':
        return None
    
    node_name = node.get('name', 'Unknown')
    js_code = node.get('parameters', {}).get('jsCode', '')
    
    has_workflow_id = 'const WORKFLOW_ID' in js_code
    
    if not has_workflow_id:
        return {
            'workflow': workflow_name,
            'node': node_name
        }
    
    # Check if WORKFLOW_ID matches workflow name
    if has_workflow_id:
        # Extract the value
        import re
        match = re.search(r"const WORKFLOW_ID\s*=\s*['\"]([^'\"]+)['\"]", js_code)
        if match:
            workflow_id_value = match.group(1)
            if workflow_id_value != workflow_name:
                return {
                    'workflow': workflow_name,
                    'node': node_name,
                    'mismatch': True,
                    'expected': workflow_name,
                    'actual': workflow_id_value
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
    
    print("Verifying WORKFLOW_ID Compliance...")
    print("=" * 60)
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.startswith('BB_') and filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            issues = verify_workflow(filepath)
            all_issues.extend(issues)
    
    # Report
    if all_issues:
        print(f"\n❌ Found {len(all_issues)} WORKFLOW_ID issues:\n")
        
        current_workflow = None
        for issue in all_issues:
            if issue['workflow'] != current_workflow:
                current_workflow = issue['workflow']
                print(f"\n{current_workflow}:")
            
            if issue.get('mismatch'):
                print(f"  - Node '{issue['node']}': MISMATCH - expected '{issue['expected']}', got '{issue['actual']}'")
            else:
                print(f"  - Node '{issue['node']}': Missing WORKFLOW_ID constant")
        
        return 1
    else:
        print("\n✅ All Code Nodes have correct WORKFLOW_ID!")
        return 0

if __name__ == '__main__':
    sys.exit(main())
