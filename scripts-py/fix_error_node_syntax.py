#!/usr/bin/env python3
"""
Fix syntax error in Error Code Nodes.
The meta() function was missing parentheses for object literal.
"""

import json
import re
from pathlib import Path

WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"

def fix_workflow(filepath):
    """Fix the Error node syntax in a workflow."""
    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)
    
    workflow_name = workflow.get('name', '')
    nodes = workflow.get('nodes', [])
    
    fixed = False
    for node in nodes:
        if node.get('name') == 'Error' and node.get('type') == 'n8n-nodes-base.code':
            old_code = node.get('parameters', {}).get('jsCode', '')
            
            # Check if it has the syntax error (missing parentheses)
            if "() => { source:" in old_code and "() => ({ source:" not in old_code:
                # Fix the code by adding parentheses
                new_code = old_code.replace(
                    "() => { source:",
                    "() => ({ source:"
                ).replace(
                    "workflow_id: WORKFLOW_ID };",
                    "workflow_id: WORKFLOW_ID });"
                )
                node['parameters']['jsCode'] = new_code
                fixed = True
                print(f"  [FIX] {workflow_name}: Corrected meta() syntax in Error node")
    
    if fixed:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)
    
    return fixed

def main():
    print("Fixing Error node syntax in all workflows...")
    print("=" * 60)
    
    fixed_count = 0
    for filepath in sorted(WORKFLOWS_DIR.glob('BB_*.json')):
        if fix_workflow(filepath):
            fixed_count += 1
    
    print("=" * 60)
    print(f"Fixed: {fixed_count} workflows")

if __name__ == '__main__':
    main()
