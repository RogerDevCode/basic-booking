#!/usr/bin/env python3
"""
Fix Switch logic in BB_01_Telegram_Gateway.
The rule should match success === true, not success === false.
"""

import json
from pathlib import Path

WORKFLOWS_DIR = Path(__file__).parent.parent / 'workflows'

def fix_bb01():
    filepath = WORKFLOWS_DIR / 'BB_01_Telegram_Gateway.json'
    with open(filepath) as f:
        wf = json.load(f)
    
    # Find and fix the Switch node
    for node in wf['nodes']:
        if node['type'] == 'n8n-nodes-base.switch' and 'Guard' in node['name']:
            print(f"Fixing Switch node: {node['name']}")
            
            # Change the rule: success === true (instead of false)
            # This way:
            # - Rule matches (success === true) → output 0 → Success
            # - Fallback (success === false) → output 1 → Error
            node['parameters']['rules']['values'][0]['conditions']['conditions'][0]['operator']['operation'] = 'true'
            node['parameters']['rules']['values'][0]['outputKey'] = 'success'
            
            print("  Rule changed: success === true → output 0 (Success)")
            print("  Fallback: success === false → output 1 (Error)")
    
    # Verify connections are correct
    conns = wf['connections'].get('Guard OK?', {}).get('main', [])
    print(f"\nConnections:")
    print(f"  Output 0: {conns[0]}")  # Should be Success
    print(f"  Output 1: {conns[1]}")  # Should be Error
    
    # Save
    with open(filepath, 'w') as f:
        json.dump(wf, f, indent=2, ensure_ascii=False)
    
    print("\nFile saved.")

if __name__ == '__main__':
    fix_bb01()
