#!/usr/bin/env python3
"""
Advanced compliance fixer - Completes standard contract and adds _meta
This script intelligently modifies return statements to include all 5 required fields
"""
import json
import os
import re

def analyze_return_statement(code):
    """Analyze what fields are present in return statements"""
    fields = {
        'success': 'success:' in code or '"success":' in code,
        'error_code': 'error_code:' in code or '"error_code":' in code,
        'error_message': 'error_message:' in code or '"error_message":' in code,
        'data': 'data:' in code or '"data":' in code,
        '_meta': '_meta:' in code or '"_meta":' in code
    }
    return fields

def fix_code_node_returns(code, workflow_id, node_name):
    """Fix return statements to include all required fields"""
    
    # Check what's missing
    fields = analyze_return_statement(code)
    missing = [k for k, v in fields.items() if not v]
    
    if not missing:
        return code, []
    
    # Strategy: Add missing fields to existing return statements
    # This is complex, so we'll use a targeted approach
    
    modifications = []
    lines = code.split('\n')
    new_lines = []
    
    in_return = False
    return_buffer = []
    
    for i, line in enumerate(lines):
        # Detect return statements
        if 'return [' in line and '{' in line:
            in_return = True
            return_buffer = [line]
            
            # Check if it's a single-line return
            if '}]' in line:
                # Single line return - try to fix it
                fixed_line = fix_single_line_return(line, missing, workflow_id)
                if fixed_line != line:
                    new_lines.append(fixed_line)
                    modifications.extend(missing)
                else:
                    new_lines.append(line)
                in_return = False
                return_buffer = []
            continue
        
        if in_return:
            return_buffer.append(line)
            if '}]' in line or '});' in line:
                # End of return statement
                fixed_return = fix_multiline_return(return_buffer, missing, workflow_id)
                if fixed_return != return_buffer:
                    new_lines.extend(fixed_return)
                    modifications.extend(missing)
                else:
                    new_lines.extend(return_buffer)
                in_return = False
                return_buffer = []
                continue
        
        new_lines.append(line)
    
    return '\n'.join(new_lines), modifications

def fix_single_line_return(line, missing, workflow_id):
    """Fix a single-line return statement"""
    if not missing:
        return line
    
    # Find the closing }]
    if '}]' not in line:
        return line
    
    # Build additions
    additions = []
    
    if 'success' in missing:
        # Determine if this looks like an error or success
        if 'error' in line.lower() or 'fail' in line.lower():
            additions.append("success: false")
        else:
            additions.append("success: true")
    
    if 'error_code' in missing:
        if 'error' in line.lower():
            additions.append("error_code: 'PROCESSING_ERROR'")
        else:
            additions.append("error_code: null")
    
    if 'error_message' in missing:
        if 'error' in line.lower():
            additions.append("error_message: 'Processing error'")
        else:
            additions.append("error_message: null")
    
    if 'data' in missing:
        additions.append("data: null")
    
    if '_meta' in missing:
        meta = f"_meta: {{ source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }}"
        additions.append(meta)
    
    # Add before }]
    addition_str = ', ' + ', '.join(additions)
    return line.replace('}]', addition_str + ' }]')

def fix_multiline_return(lines, missing, workflow_id):
    """Fix a multi-line return statement"""
    if not missing:
        return lines
    
    # Find where to insert (before the last })
    insert_pos = -1
    for i in range(len(lines) - 1, -1, -1):
        if '}' in lines[i]:
            insert_pos = i
            break
    
    if insert_pos == -1:
        return lines
    
    # Build additions
    additions = []
    indent = '      '  # Standard indent
    
    if 'success' in missing:
        additions.append(f"{indent}success: true,")
    
    if 'error_code' in missing:
        additions.append(f"{indent}error_code: null,")
    
    if 'error_message' in missing:
        additions.append(f"{indent}error_message: null,")
    
    if 'data' in missing:
        additions.append(f"{indent}data: null,")
    
    if '_meta' in missing:
        additions.append(f"{indent}_meta: {{")
        additions.append(f"{indent}  source: 'subworkflow',")
        additions.append(f"{indent}  timestamp: new Date().toISOString(),")
        additions.append(f"{indent}  workflow_id: WORKFLOW_ID")
        additions.append(f"{indent}}},")
    
    # Insert before closing brace
    new_lines = lines[:insert_pos] + additions + lines[insert_pos:]
    return new_lines

def process_code_node(node, workflow_id):
    """Process a Code Node to add missing fields"""
    if node.get('type') != 'n8n-nodes-base.code':
        return False, []
    
    js_code = node.get('parameters', {}).get('jsCode', '')
    if not js_code:
        return False, []
    
    node_name = node.get('name', 'Unknown')
    
    # Fix the code
    new_code, modifications = fix_code_node_returns(js_code, workflow_id, node_name)
    
    if modifications:
        node['parameters']['jsCode'] = new_code
        return True, modifications
    
    return False, []

def process_workflow(filepath):
    """Process a workflow file"""
    filename = os.path.basename(filepath)
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', filename.replace('.json', ''))
    workflow_id = workflow_name
    
    print(f"\n{'='*60}")
    print(f"Processing: {filename}")
    print(f"{'='*60}")
    
    total_modified = 0
    all_modifications = []
    
    for node in data.get('nodes', []):
        modified, mods = process_code_node(node, workflow_id)
        if modified:
            total_modified += 1
            node_name = node.get('name', 'Unknown')
            print(f"  ✓ Fixed {node_name}: {', '.join(mods)}")
            all_modifications.extend(mods)
    
    if total_modified > 0:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"\n  ✅ Modified {total_modified} nodes")
        return total_modified
    else:
        print(f"  ✓ No modifications needed")
        return 0

def main():
    workflows_dir = 'workflows'
    
    print("Completing Standard Contract Compliance...")
    print("="*60)
    
    # Process all workflows
    workflows = [
        'BB_00_Global_Error_Handler.json',
        'BB_02_Security_Firewall.json',
        'BB_06_Admin_Dashboard.json',
        'BB_01_Telegram_Gateway.json',
        'BB_03_00_Main.json',
        'BB_03_02_ProviderData.json',
        'BB_03_03_ScheduleConfig.json',
        'BB_03_04_BookingsData.json',
    ]
    
    total = 0
    for wf in workflows:
        filepath = os.path.join(workflows_dir, wf)
        if os.path.exists(filepath):
            total += process_workflow(filepath)
    
    print("\n" + "="*60)
    print(f"Total nodes modified: {total}")
    print("="*60)
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
