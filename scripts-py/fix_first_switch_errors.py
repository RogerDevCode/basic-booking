#!/usr/bin/env python3
"""
Fix all workflows to have Error Code Node after first Switch (Guard OK?).
This ensures consistent error handling per SolucionFinal-v2.md requirements.
"""

import json
import os
from pathlib import Path

WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"

def create_error_node(workflow_name, position):
    """Create an Error Code Node for the first Switch error path."""
    js_code = f"""const WORKFLOW_ID = '{workflow_name}';
const meta = () => {{ source: 'webhook', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }};
// Pass through the error from Guard (already formatted correctly)
return $input.all();"""
    
    return {
        "parameters": {
            "jsCode": js_code
        },
        "id": "error-guard",
        "name": "Error",
        "type": "n8n-nodes-base.code",
        "typeVersion": 2,
        "position": position
    }

def fix_workflow(filepath):
    """Fix a single workflow file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)
    
    workflow_name = workflow.get('name', '')
    nodes = workflow.get('nodes', [])
    connections = workflow.get('connections', {})
    
    # Find the first Switch node (Guard OK?)
    first_switch = None
    first_switch_name = None
    for node in nodes:
        if node.get('type') == 'n8n-nodes-base.switch' and 'Guard' in node.get('name', ''):
            first_switch = node
            first_switch_name = node.get('name')
            break
    
    if not first_switch:
        print(f"  [SKIP] {workflow_name}: No Guard Switch found")
        return False
    
    # Check if first Switch error output (index 0) goes directly to Output
    switch_conn = connections.get(first_switch_name, {}).get('main', [])
    if not switch_conn or len(switch_conn) < 1:
        print(f"  [SKIP] {workflow_name}: No connections from Guard Switch")
        return False
    
    error_path = switch_conn[0]  # Output 0 (error path)
    
    # Check if it goes directly to Output node
    goes_to_output = any(
        conn.get('node') == 'Output' 
        for conn in error_path
    )
    
    # Check if there's already an Error node in the error path
    has_error_node = any(
        'Error' in conn.get('node', '') or conn.get('node') == 'error'
        for conn in error_path
    )
    
    if has_error_node:
        print(f"  [OK] {workflow_name}: Already has Error node in error path")
        return False
    
    if not goes_to_output:
        print(f"  [SKIP] {workflow_name}: Error path doesn't go to Output (different pattern)")
        return False
    
    # Need to fix this workflow
    print(f"  [FIX] {workflow_name}: Adding Error Code Node...")
    
    # Find Output node position
    output_node = None
    for node in nodes:
        if node.get('name') == 'Output':
            output_node = node
            break
    
    # Calculate position for new Error node
    switch_pos = first_switch.get('position', [400, 400])
    output_pos = output_node.get('position', [800, 300]) if output_node else [600, 500]
    
    # Position Error node between Switch and Output, slightly offset
    error_pos = [
        (switch_pos[0] + output_pos[0]) // 2,
        switch_pos[1] + 100  # Below the Switch
    ]
    
    # Check if there's already an Error node we can reuse
    existing_error = None
    for node in nodes:
        if node.get('name') == 'Error' and node.get('id') in ['error', 'error-guard']:
            existing_error = node
            break
    
    if existing_error:
        # Just fix connections
        error_node_name = existing_error.get('name')
    else:
        # Create new Error node
        error_node = create_error_node(workflow_name, error_pos)
        nodes.append(error_node)
        error_node_name = 'Error'
    
    # Update connections:
    # 1. Switch output 0 → Error node
    # 2. Error node → Output
    connections[first_switch_name]['main'][0] = [{'node': error_node_name, 'type': 'main', 'index': 0}]
    
    # Add Error → Output connection
    if error_node_name not in connections:
        connections[error_node_name] = {'main': [[]]}
    connections[error_node_name]['main'][0] = [{'node': 'Output', 'type': 'main', 'index': 0}]
    
    # Save the modified workflow
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(workflow, f, indent=2, ensure_ascii=False)
    
    return True

def main():
    print("Fixing first Switch error paths in all workflows...")
    print("=" * 60)
    
    fixed_count = 0
    skipped_count = 0
    
    for filepath in sorted(WORKFLOWS_DIR.glob('BB_*.json')):
        if fix_workflow(filepath):
            fixed_count += 1
        else:
            skipped_count += 1
    
    print("=" * 60)
    print(f"Done! Fixed: {fixed_count}, Skipped: {skipped_count}")

if __name__ == '__main__':
    main()
