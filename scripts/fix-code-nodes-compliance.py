#!/usr/bin/env python3
"""
Automated compliance fixer for Code Nodes
Adds WORKFLOW_ID, _meta, try-catch, and standard contract fields

Usage:
    python3 fix-code-nodes-compliance.py <workflow_file.json>
"""
import json
import sys
import re
from typing import Dict, List

def extract_workflow_id(workflow_name: str) -> str:
    """Extract workflow ID from workflow name"""
    # BB_03_01_InputValidation -> BB_03_01_InputValidation
    return workflow_name

def has_workflow_id_constant(code: str) -> bool:
    """Check if code has WORKFLOW_ID constant"""
    return 'const WORKFLOW_ID' in code

def has_try_catch(code: str) -> bool:
    """Check if code is wrapped in try-catch"""
    return 'try {' in code and 'catch' in code

def add_workflow_id_constant(code: str, workflow_id: str) -> str:
    """Add WORKFLOW_ID constant at the beginning of code"""
    if has_workflow_id_constant(code):
        return code
    
    # Add after comments if any, otherwise at the beginning
    lines = code.split('\n')
    insert_pos = 0
    
    # Skip initial comments
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('/**') or stripped.startswith('/*'):
            # Find end of comment block
            for j in range(i, len(lines)):
                if '*/' in lines[j]:
                    insert_pos = j + 1
                    break
            break
        elif stripped.startswith('//'):
            insert_pos = i + 1
        else:
            break
    
    workflow_id_line = f"const WORKFLOW_ID = '{workflow_id}';\n"
    lines.insert(insert_pos, workflow_id_line)
    
    return '\n'.join(lines)

def wrap_in_try_catch(code: str, workflow_id: str) -> str:
    """Wrap code in try-catch if not already wrapped"""
    if has_try_catch(code):
        return code
    
    lines = code.split('\n')
    
    # Find where to start try block (after WORKFLOW_ID and comments)
    try_start = 0
    for i, line in enumerate(lines):
        if 'const WORKFLOW_ID' in line:
            try_start = i + 1
            break
    
    # Build new code
    new_lines = lines[:try_start]
    new_lines.append('\ntry {')
    
    # Indent existing code
    for line in lines[try_start:]:
        if line.strip():
            new_lines.append('  ' + line)
        else:
            new_lines.append(line)
    
    # Add catch block
    new_lines.append('')
    new_lines.append('} catch (e) {')
    new_lines.append('  return [{')
    new_lines.append('    json: {')
    new_lines.append('      success: false,')
    new_lines.append("      error_code: 'INTERNAL_ERROR',")
    new_lines.append('      error_message: `Unexpected error in ${WORKFLOW_ID}: ${e.message}`,')
    new_lines.append('      data: null,')
    new_lines.append('      _meta: {')
    new_lines.append("        source: 'subworkflow',")
    new_lines.append('        timestamp: new Date().toISOString(),')
    new_lines.append('        workflow_id: WORKFLOW_ID')
    new_lines.append('      }')
    new_lines.append('    }')
    new_lines.append('  }];')
    new_lines.append('}')
    
    return '\n'.join(new_lines)

def ensure_meta_in_returns(code: str) -> str:
    """Ensure all return statements have _meta field"""
    # This is a complex transformation, for now we'll flag it
    # Manual review recommended
    return code

def fix_code_node(node: Dict, workflow_id: str) -> bool:
    """Fix a single Code Node to be compliant"""
    if node.get('type') != 'n8n-nodes-base.code':
        return False
    
    js_code = node.get('parameters', {}).get('jsCode', '')
    if not js_code:
        return False
    
    original_code = js_code
    modified = False
    
    # Step 1: Add WORKFLOW_ID constant
    if not has_workflow_id_constant(js_code):
        js_code = add_workflow_id_constant(js_code, workflow_id)
        modified = True
        print(f"  ✓ Added WORKFLOW_ID to node: {node.get('name')}")
    
    # Step 2: Wrap in try-catch
    if not has_try_catch(js_code):
        js_code = wrap_in_try_catch(js_code, workflow_id)
        modified = True
        print(f"  ✓ Added try-catch to node: {node.get('name')}")
    
    # Update node
    if modified:
        node['parameters']['jsCode'] = js_code
    
    return modified

def process_workflow(filepath: str) -> int:
    """Process a single workflow file"""
    print(f"\nProcessing: {filepath}")
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', '')
    workflow_id = extract_workflow_id(workflow_name)
    
    print(f"Workflow: {workflow_name}")
    print(f"Workflow ID: {workflow_id}")
    
    # Fix all Code Nodes
    modifications = 0
    for node in data.get('nodes', []):
        if fix_code_node(node, workflow_id):
            modifications += 1
    
    # Save if modified
    if modifications > 0:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"\n✅ Modified {modifications} Code Nodes")
        return modifications
    else:
        print(f"\n✓ No modifications needed")
        return 0

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix-code-nodes-compliance.py <workflow_file.json>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    try:
        modifications = process_workflow(filepath)
        print(f"\n{'='*60}")
        print(f"Total modifications: {modifications}")
        print(f"{'='*60}")
        return 0
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == '__main__':
    sys.exit(main())
