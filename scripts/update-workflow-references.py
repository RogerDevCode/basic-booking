#!/usr/bin/env python3
"""
Update Execute Workflow references to use real workflow IDs from N8N
Handles both string IDs and resource locator objects
"""
import json
import sys
import os
import subprocess

def get_workflow_id_map():
    """Get mapping of workflow names to IDs from N8N API"""
    try:
        result = subprocess.run(
            ['python3', 'scripts-py/n8n_read_list.py', '--filter', 'BB_', '--format', 'json'],
            capture_output=True,
            text=True,
            check=True
        )
        
        workflows = json.loads(result.stdout)
        workflow_map = {}
        
        for wf in workflows:
            name = wf.get('name', '')
            wf_id = wf.get('id', '')
            if name and wf_id:
                workflow_map[name] = wf_id
        
        return workflow_map
    except Exception as e:
        print(f"Error getting workflow IDs: {e}", file=sys.stderr)
        return {}

def update_execute_workflow_references(workflow_file, id_map):
    """Update Execute Workflow node references in a workflow file"""
    try:
        with open(workflow_file, 'r') as f:
            data = json.load(f)
        
        updated = False
        
        # Find all Execute Workflow nodes
        for node in data.get('nodes', []):
            if node.get('type') == 'n8n-nodes-base.executeWorkflow':
                params = node.get('parameters', {})
                
                # Check if using workflowId
                if 'workflowId' in params:
                    workflow_ref = params['workflowId']
                    
                    # Handle resource locator object format
                    if isinstance(workflow_ref, dict):
                        old_id = workflow_ref.get('value', '')
                        
                        # Check if this ID needs updating (find matching name)
                        for name, new_id in id_map.items():
                            # If old ID doesn't match current N8N ID, update it
                            if old_id != new_id:
                                # Try to find if this node references this workflow by checking node name
                                node_name = node.get('name', '')
                                if name in node_name or name.replace('BB_', '').replace('_', ' ') in node_name:
                                    workflow_ref['value'] = new_id
                                    updated = True
                                    print(f"  Updated {node_name}: {old_id} -> {new_id} ({name})")
                                    break
                    
                    # Handle string format (legacy)
                    elif isinstance(workflow_ref, str):
                        # If it's a name (not an ID), replace with actual ID
                        if workflow_ref in id_map:
                            old_ref = workflow_ref
                            new_id = id_map[workflow_ref]
                            # Convert to resource locator format
                            params['workflowId'] = {
                                "__rl": True,
                                "value": new_id,
                                "mode": "id"
                            }
                            updated = True
                            print(f"  Updated: {old_ref} -> {new_id}")
        
        # Save if updated
        if updated:
            with open(workflow_file, 'w') as f:
                json.dump(data, f, indent=2)
            return True
        
        return False
        
    except Exception as e:
        print(f"Error updating {workflow_file}: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False

def main():
    print("Fetching workflow IDs from N8N...")
    id_map = get_workflow_id_map()
    
    if not id_map:
        print("No workflows found or error fetching IDs")
        return 1
    
    print(f"\nFound {len(id_map)} workflows:")
    for name, wf_id in sorted(id_map.items()):
        print(f"  {name}: {wf_id}")
    
    print("\nUpdating Execute Workflow references...")
    print("Note: This updates IDs to match current N8N state")
    
    workflows_dir = 'workflows'
    updated_count = 0
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.startswith('BB_') and filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            print(f"\nChecking {filename}...")
            
            if update_execute_workflow_references(filepath, id_map):
                updated_count += 1
                print(f"  ✅ Updated")
            else:
                print(f"  ⏭️  No changes needed")
    
    print(f"\n{'='*50}")
    print(f"Updated {updated_count} workflow files")
    print(f"{'='*50}")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
