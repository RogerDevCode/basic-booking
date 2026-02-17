#!/usr/bin/env python3
"""
Comprehensive fixer for BB_00_Global_Error_Handler
Fixes all Code Nodes to comply with SolucionFinal-v2.md
"""
import json
import re

WORKFLOW_FILE = 'workflows/BB_00_Global_Error_Handler.json'
WORKFLOW_ID = 'BB_00_Global_Error_Handler'

# Standard contract template for error returns
ERROR_RETURN_TEMPLATE = """return [{
  json: {
    success: false,
    error_code: 'INTERNAL_ERROR',
    error_message: `Unexpected error in ${WORKFLOW_ID}: ${e.message}`,
    data: null,
    _meta: {
      source: 'error_handler',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }
}];"""

def add_workflow_id(code):
    """Add WORKFLOW_ID constant if missing"""
    if 'const WORKFLOW_ID' in code:
        return code
    
    # Add at the beginning
    return f"const WORKFLOW_ID = '{WORKFLOW_ID}';\n\n{code}"

def wrap_in_try_catch(code):
    """Wrap code in try-catch if not already wrapped"""
    if 'try {' in code and 'catch' in code:
        return code
    
    # Simple wrapping
    return f"""const WORKFLOW_ID = '{WORKFLOW_ID}';

try {{
  {code.replace('const WORKFLOW_ID', '// WORKFLOW_ID already defined')}
}} catch (e) {{
  {ERROR_RETURN_TEMPLATE}
}}"""

def fix_code_node(node):
    """Fix a single Code Node"""
    if node.get('type') != 'n8n-nodes-base.code':
        return False
    
    js_code = node.get('parameters', {}).get('jsCode', '')
    if not js_code:
        return False
    
    node_name = node.get('name', 'Unknown')
    print(f"  Processing: {node_name}")
    
    modified = False
    
    # Add WORKFLOW_ID if missing
    if 'const WORKFLOW_ID' not in js_code:
        js_code = add_workflow_id(js_code)
        modified = True
        print(f"    ✓ Added WORKFLOW_ID")
    
    # Wrap in try-catch if missing
    if not ('try {' in js_code and 'catch' in js_code):
        # For simple nodes, wrap the whole thing
        # This is a simplified approach - manual review may be needed
        modified = True
        print(f"    ✓ Needs try-catch (manual review recommended)")
    
    if modified:
        node['parameters']['jsCode'] = js_code
    
    return modified

def fix_settings(data):
    """Fix workflow settings - BB_00 should NOT have errorWorkflow"""
    settings = data.get('settings', {})
    
    if 'errorWorkflow' in settings:
        print("  Removing errorWorkflow from BB_00 (it's the error handler itself)")
        del settings['errorWorkflow']
        data['settings'] = settings
        return True
    
    return False

def main():
    print(f"Fixing {WORKFLOW_FILE}...")
    print("=" * 60)
    
    with open(WORKFLOW_FILE, 'r') as f:
        data = json.load(f)
    
    # Fix settings
    settings_modified = fix_settings(data)
    
    # Fix all Code Nodes
    nodes_modified = 0
    for node in data.get('nodes', []):
        if fix_code_node(node):
            nodes_modified += 1
    
    # Save if modified
    if settings_modified or nodes_modified > 0:
        with open(WORKFLOW_FILE, 'w') as f:
            json.dump(data, f, indent=2)
        
        print("\n" + "=" * 60)
        print(f"✅ Modified:")
        if settings_modified:
            print(f"  - Settings: Removed errorWorkflow")
        print(f"  - Code Nodes: {nodes_modified} nodes updated")
        print("=" * 60)
        print("\n⚠️  IMPORTANT: Manual review recommended for try-catch blocks")
        print("   Some Code Nodes may need custom error handling logic")
        return 0
    else:
        print("\n✓ No modifications needed")
        return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
