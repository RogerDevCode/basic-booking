#!/usr/bin/env python3
"""
Final manual fix for BB_08, BB_07, BB_05
These nodes already have the correct structure but validator is detecting false positives
Let's verify and add any truly missing fields
"""
import json

def check_and_fix_node(filepath, node_name):
    """Check a specific node and report its structure"""
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    for node in data.get('nodes', []):
        if node.get('name') == node_name:
            code = node.get('parameters', {}).get('jsCode', '')
            
            print(f"\n{filepath} - {node_name}:")
            print(f"  Has 'success:': {'success:' in code}")
            print(f"  Has 'error_code:': {'error_code:' in code}")
            print(f"  Has 'error_message:': {'error_message:' in code}")
            print(f"  Has 'data:': {'data:' in code}")
            print(f"  Has '_meta:': {'_meta:' in code}")
            
            # Count return statements
            returns = code.count('return [{')
            print(f"  Return statements: {returns}")
            
            return code
    
    return None

def main():
    print("="*60)
    print("Checking Remaining Nodes")
    print("="*60)
    
    nodes_to_check = [
        ('workflows/BB_08_JWT_Auth_Helper.json', 'Extract Token'),
        ('workflows/BB_08_JWT_Auth_Helper.json', 'Verify Token'),
        ('workflows/BB_07_Notification_Retry_Worker.json', 'Log Summary'),
        ('workflows/BB_05_Notification_Engine.json', 'Log Output (Respond)'),
    ]
    
    for filepath, node_name in nodes_to_check:
        check_and_fix_node(filepath, node_name)
    
    print("\n" + "="*60)
    print("Analysis complete")
    print("="*60)
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
