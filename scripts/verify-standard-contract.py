#!/usr/bin/env python3
"""
Verify that all Code Nodes return the standard contract
{success, error_code, error_message, data, _meta}
"""
import json
import os
import sys

def check_code_node(node, workflow_name):
    """Check if Code Node returns standard contract"""
    if node.get('type') != 'n8n-nodes-base.code':
        return []
    
    node_name = node.get('name', 'Unknown')
    js_code = node.get('parameters', {}).get('jsCode', '')
    
    issues = []
    
    # Check for required fields in returns
    required_fields = ['success', 'error_code', 'error_message', 'data', '_meta']
    
    for field in required_fields:
        # Check both formats: field: and "field":
        if f'{field}:' not in js_code and f'"{field}":' not in js_code:
            issues.append({
                'workflow': workflow_name,
                'node': node_name,
                'missing_field': field
            })
    
    # Check _meta structure
    if '_meta' in js_code:
        meta_fields = ['source', 'timestamp', 'workflow_id']
        for meta_field in meta_fields:
            if meta_field not in js_code:
                issues.append({
                    'workflow': workflow_name,
                    'node': node_name,
                    'missing_field': f'_meta.{meta_field}'
                })
    
    return issues

def verify_workflow(filepath):
    """Verify a single workflow"""
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', os.path.basename(filepath))
    issues = []
    
    for node in data.get('nodes', []):
        issues.extend(check_code_node(node, workflow_name))
    
    return issues

def main():
    workflows_dir = 'workflows'
    all_issues = []
    
    print("Verifying Standard Contract Compliance...")
    print("=" * 60)
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.startswith('BB_') and filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            issues = verify_workflow(filepath)
            all_issues.extend(issues)
    
    # Report
    if all_issues:
        print(f"\n❌ Found {len(all_issues)} standard contract violations:\n")
        
        current_workflow = None
        for issue in all_issues:
            if issue['workflow'] != current_workflow:
                current_workflow = issue['workflow']
                print(f"\n{current_workflow}:")
            print(f"  - Node '{issue['node']}': Missing {issue['missing_field']}")
        
        return 1
    else:
        print("\n✅ All Code Nodes return standard contract!")
        return 0

if __name__ == '__main__':
    sys.exit(main())
