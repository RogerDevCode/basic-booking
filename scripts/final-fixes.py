#!/usr/bin/env python3
"""
Final fixes for remaining workflows
"""
import json
import os

def fix_workflow(filepath, nodes_to_fix):
    """Fix specific nodes in a workflow"""
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', '')
    modified = False
    
    for node in data.get('nodes', []):
        node_name = node.get('name', '')
        if node_name in nodes_to_fix and node.get('type') == 'n8n-nodes-base.code':
            code = node.get('parameters', {}).get('jsCode', '')
            
            # Add missing fields to all returns
            if '_meta' not in code:
                # Simple approach: add to end of returns
                code = code.replace(
                    'return [{',
                    'return [{\n    json: {'
                ).replace(
                    '}];',
                    ',\n      _meta: { source: "subworkflow", timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }\n    }\n  }];'
                )
                
                node['parameters']['jsCode'] = code
                modified = True
                print(f"  ✓ Fixed {node_name}")
    
    if modified:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
    
    return modified

def main():
    workflows_dir = 'workflows'
    
    # Specific fixes needed
    fixes = {
        'BB_08_JWT_Auth_Helper.json': ['Extract Token', 'Verify Token'],
        'BB_03_06_ValidateConfig.json': ['Paranoid Guard', 'Apply Config Rules'],
        'BB_07_Notification_Retry_Worker.json': ['Log Summary'],
        'BB_05_Notification_Engine.json': ['Log Output (Respond)'],
        'BB_04_Validate_Input.json': ['Validate Logic'],
        'BB_04_Booking_Transaction.json': ['Guard']
    }
    
    print("Applying final fixes...")
    print("="*60)
    
    for filename, nodes in fixes.items():
        filepath = os.path.join(workflows_dir, filename)
        if os.path.exists(filepath):
            print(f"\nProcessing: {filename}")
            if fix_workflow(filepath, nodes):
                print(f"  ✅ Modified")
            else:
                print(f"  ✓ Already fixed")
    
    print("\n" + "="*60)
    print("Final fixes complete!")
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
