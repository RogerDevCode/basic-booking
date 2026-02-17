#!/usr/bin/env python3
"""
Fix Switch V3 configuration in all workflows.
The fallbackOutput must be 0 (not 1) for Switch V3 with rules mode.
"""

import json
from pathlib import Path

WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"

def fix_workflow(filepath):
    """Fix Switch V3 configuration in a workflow."""
    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)
    
    workflow_name = workflow.get('name', '')
    nodes = workflow.get('nodes', [])
    connections = workflow.get('connections', {})
    
    fixed = False
    for node in nodes:
        if node.get('type') == 'n8n-nodes-base.switch' and node.get('typeVersion') == 3:
            params = node.get('parameters', {})
            options = params.get('options', {})
            
            # Check if fallbackOutput is incorrectly set to 1
            if options.get('fallbackOutput') == 1:
                # Change to 0 (extra output)
                options['fallbackOutput'] = 0
                fixed = True
                print(f"  [FIX] {workflow_name}: Changed fallbackOutput from 1 to 0 in Switch V3")
                
                # Also need to swap connections
                # In Switch V3 with fallbackOutput: 0:
                # - Output 0 = fallback (success path)
                # - Output 1 = matching rule (error path)
                
                # Current connections are:
                # Output 0 → Error (error path) - WRONG for fallback=0
                # Output 1 → Success (success path) - WRONG for fallback=0
                
                # After fix with fallback=0:
                # Output 0 → should go to Success (fallback = success path)
                # Output 1 → should go to Error (matching rule = error path)
                
                switch_name = node.get('name')
                if switch_name in connections:
                    conn = connections[switch_name].get('main', [])
                    if len(conn) >= 2:
                        # Swap the connections
                        connections[switch_name]['main'] = [conn[1], conn[0]]
                        print(f"  [FIX] {workflow_name}: Swapped Switch output connections")
    
    if fixed:
        workflow['connections'] = connections
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)
    
    return fixed

def main():
    print("Fixing Switch V3 configuration in all workflows...")
    print("=" * 60)
    
    fixed_count = 0
    for filepath in sorted(WORKFLOWS_DIR.glob('BB_*.json')):
        if fix_workflow(filepath):
            fixed_count += 1
    
    print("=" * 60)
    print(f"Fixed: {fixed_count} workflows")

if __name__ == '__main__':
    main()
