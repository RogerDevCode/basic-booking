#!/usr/bin/env python3
"""
Fix all Switch V3 nodes in workflows.
Pattern: fallbackOutput: "extra" creates an extra output for non-matching items.
"""

import json
from pathlib import Path

WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"

def fix_switch_v3(filepath):
    """Fix Switch V3 configuration in a workflow."""
    with open(filepath, 'r', encoding='utf-8') as f:
        wf = json.load(f)
    
    workflow_name = wf.get('name', '')
    fixed = False
    
    for node in wf['nodes']:
        if node.get('type') == 'n8n-nodes-base.switch' and node.get('typeVersion') == 3:
            params = node.get('parameters', {})
            options = params.get('options', {})
            
            # Only fix if fallbackOutput is a number (0 or 1)
            if isinstance(options.get('fallbackOutput'), int):
                # Get current connections
                node_name = node.get('name')
                conns = wf.get('connections', {}).get(node_name, {}).get('main', [])
                
                if len(conns) >= 2:
                    # Set fallbackOutput to 'extra'
                    options['fallbackOutput'] = 'extra'
                    
                    # Ensure connections are correct:
                    # Output 0 = rule matches (success === false) → Error
                    # Output 1 = extra (success === true) → Success
                    
                    # Check if we need to swap
                    # Output 0 should go to Error, Output 1 should go to Success
                    output0_targets = [c['node'] for c in conns[0]]
                    output1_targets = [c['node'] for c in conns[1]]
                    
                    has_error_0 = any('Error' in t for t in output0_targets)
                    has_success_1 = any('Success' in t for t in output1_targets)
                    
                    if not (has_error_0 and has_success_1):
                        # Need to swap
                        wf['connections'][node_name]['main'] = [conns[1], conns[0]]
                        print(f"  [FIX] {workflow_name}: Swapped connections")
                    
                    fixed = True
                    print(f"  [FIX] {workflow_name}: Set fallbackOutput='extra' in {node_name}")
    
    if fixed:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(wf, f, indent=2, ensure_ascii=False)
    
    return fixed

def main():
    print("Fixing Switch V3 configuration in all workflows...")
    print("=" * 60)
    
    fixed_count = 0
    for filepath in sorted(WORKFLOWS_DIR.glob('BB_*.json')):
        if fix_switch_v3(filepath):
            fixed_count += 1
    
    print("=" * 60)
    print(f"Fixed: {fixed_count} workflows")

if __name__ == '__main__':
    main()
