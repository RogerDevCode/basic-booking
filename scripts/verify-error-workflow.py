#!/usr/bin/env python3
"""
Verify that all workflows have errorWorkflow configured correctly
(All workflows except BB_00 should have errorWorkflow = BB_00_Global_Error_Handler)
"""
import json
import os
import sys

def verify_workflow(filepath):
    """Verify a single workflow"""
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', os.path.basename(filepath))
    settings = data.get('settings', {})
    error_workflow = settings.get('errorWorkflow')
    
    # BB_00 should NOT have errorWorkflow
    if workflow_name == 'BB_00_Global_Error_Handler':
        if error_workflow:
            return {
                'workflow': workflow_name,
                'issue': 'should_not_have_error_workflow',
                'current': error_workflow
            }
    else:
        # All other workflows should have errorWorkflow = BB_00_Global_Error_Handler
        if not error_workflow:
            return {
                'workflow': workflow_name,
                'issue': 'missing_error_workflow'
            }
        elif error_workflow != 'BB_00_Global_Error_Handler':
            return {
                'workflow': workflow_name,
                'issue': 'wrong_error_workflow',
                'current': error_workflow,
                'expected': 'BB_00_Global_Error_Handler'
            }
    
    return None

def main():
    workflows_dir = 'workflows'
    issues = []
    
    print("Verifying errorWorkflow Configuration...")
    print("=" * 60)
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.startswith('BB_') and filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            issue = verify_workflow(filepath)
            if issue:
                issues.append(issue)
    
    # Report
    if issues:
        print(f"\n❌ Found {len(issues)} errorWorkflow configuration issues:\n")
        
        for issue in issues:
            if issue['issue'] == 'missing_error_workflow':
                print(f"  - {issue['workflow']}: Missing errorWorkflow setting")
            elif issue['issue'] == 'wrong_error_workflow':
                print(f"  - {issue['workflow']}: Wrong errorWorkflow ('{issue['current']}' instead of '{issue['expected']}')")
            elif issue['issue'] == 'should_not_have_error_workflow':
                print(f"  - {issue['workflow']}: Should NOT have errorWorkflow (currently set to '{issue['current']}')")
        
        return 1
    else:
        print("\n✅ All workflows have correct errorWorkflow configuration!")
        return 0

if __name__ == '__main__':
    sys.exit(main())
