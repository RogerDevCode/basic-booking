#!/usr/bin/env python3
"""
COMPLETE STANDARD CONTRACT FIXER
Fix ALL 67 remaining issues - 100% compliance required
"""
import json
import os
import re

def analyze_return_statement(ret_lines):
    """Analyze what fields are present in a return statement"""
    code = '\n'.join([line for _, line in ret_lines])
    
    fields = {
        'success': 'success:' in code or '"success":' in code,
        'error_code': 'error_code:' in code or '"error_code":' in code,
        'error_message': 'error_message:' in code or '"error_message":' in code,
        'data': 'data:' in code or '"data":' in code,
        '_meta': '_meta:' in code or '"_meta":' in code
    }
    
    return fields

def extract_all_returns(code):
    """Extract all return statements with line numbers"""
    lines = code.split('\n')
    returns = []
    
    in_return = False
    return_buffer = []
    brace_count = 0
    
    for i, line in enumerate(lines, 1):
        if 'return' in line and not in_return:
            in_return = True
            return_buffer = [(i, line)]
            brace_count = line.count('{') - line.count('}')
            
            # Check if single-line return
            if brace_count <= 0 and (';' in line or ']' in line):
                returns.append(return_buffer)
                in_return = False
                return_buffer = []
                brace_count = 0
        elif in_return:
            return_buffer.append((i, line))
            brace_count += line.count('{') - line.count('}')
            
            if brace_count <= 0 and (';' in line or ']' in line):
                returns.append(return_buffer)
                in_return = False
                return_buffer = []
                brace_count = 0
    
    return returns

def fix_return_statement(ret_lines, workflow_id):
    """Fix a return statement to have all required fields"""
    fields = analyze_return_statement(ret_lines)
    missing = [k for k, v in fields.items() if not v]
    
    if not missing:
        return ret_lines, False
    
    # Build the complete return
    lines = [line for _, line in ret_lines]
    code = '\n'.join(lines)
    
    # Strategy: Find where to insert missing fields
    # Look for the last field before closing braces
    
    new_lines = []
    modified = False
    
    for i, (line_num, line) in enumerate(ret_lines):
        # Check if this is near the end of the return
        if i == len(ret_lines) - 1 or i == len(ret_lines) - 2:
            # This is one of the last lines
            # Add missing fields before the closing braces
            
            if 'success' in missing and 'success:' not in line:
                # Determine if this looks like an error
                is_error = 'error' in code.lower() or 'fail' in code.lower()
                indent = '      '
                new_lines.append((line_num, f"{indent}success: {str(not is_error).lower()},"))
                missing.remove('success')
                modified = True
            
            if 'error_code' in missing and 'error_code:' not in line:
                indent = '      '
                if 'error' in code.lower():
                    new_lines.append((line_num, f"{indent}error_code: 'PROCESSING_ERROR',"))
                else:
                    new_lines.append((line_num, f"{indent}error_code: null,"))
                missing.remove('error_code')
                modified = True
            
            if 'error_message' in missing and 'error_message:' not in line:
                indent = '      '
                if 'error' in code.lower():
                    new_lines.append((line_num, f"{indent}error_message: 'Processing error',"))
                else:
                    new_lines.append((line_num, f"{indent}error_message: null,"))
                missing.remove('error_message')
                modified = True
            
            if 'data' in missing and 'data:' not in line:
                indent = '      '
                new_lines.append((line_num, f"{indent}data: null,"))
                missing.remove('data')
                modified = True
            
            if '_meta' in missing and '_meta:' not in line:
                indent = '      '
                new_lines.append((line_num, f"{indent}_meta: {{"))
                new_lines.append((line_num, f"{indent}  source: 'subworkflow',"))
                new_lines.append((line_num, f"{indent}  timestamp: new Date().toISOString(),"))
                new_lines.append((line_num, f"{indent}  workflow_id: WORKFLOW_ID"))
                new_lines.append((line_num, f"{indent}}},"))
                missing.remove('_meta')
                modified = True
        
        new_lines.append((line_num, line))
    
    return new_lines, modified

def fix_code_node(node, workflow_id):
    """Fix all return statements in a Code Node"""
    if node.get('type') != 'n8n-nodes-base.code':
        return False, 0
    
    code = node.get('parameters', {}).get('jsCode', '')
    if not code:
        return False, 0
    
    # Extract all returns
    returns = extract_all_returns(code)
    
    if not returns:
        return False, 0
    
    # Fix each return
    all_new_lines = []
    current_line = 1
    fixes_applied = 0
    
    lines = code.split('\n')
    
    for ret in returns:
        first_line = ret[0][0]
        last_line = ret[-1][0]
        
        # Add lines before this return
        while current_line < first_line:
            all_new_lines.append(lines[current_line - 1])
            current_line += 1
        
        # Fix this return
        fixed_ret, was_modified = fix_return_statement(ret, workflow_id)
        
        if was_modified:
            # Add the fixed return
            for _, line in fixed_ret:
                all_new_lines.append(line)
            fixes_applied += 1
        else:
            # Add original return
            for _, line in ret:
                all_new_lines.append(line)
        
        current_line = last_line + 1
    
    # Add remaining lines
    while current_line <= len(lines):
        all_new_lines.append(lines[current_line - 1])
        current_line += 1
    
    if fixes_applied > 0:
        node['parameters']['jsCode'] = '\n'.join(all_new_lines)
        return True, fixes_applied
    
    return False, 0

def fix_workflow(filepath):
    """Fix all Code Nodes in a workflow"""
    filename = os.path.basename(filepath)
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', filename.replace('.json', ''))
    
    total_nodes_fixed = 0
    total_returns_fixed = 0
    
    for node in data.get('nodes', []):
        was_modified, fixes = fix_code_node(node, workflow_name)
        if was_modified:
            total_nodes_fixed += 1
            total_returns_fixed += fixes
            print(f"    ✓ {node.get('name', 'Unknown')}: {fixes} returns fixed")
    
    if total_nodes_fixed > 0:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        return total_nodes_fixed, total_returns_fixed
    
    return 0, 0

def main():
    print("="*70)
    print("100% STANDARD CONTRACT COMPLIANCE FIXER")
    print("="*70)
    print("\nFixing ALL 67 remaining issues...")
    print("Target: Every return must have all 5 fields")
    print("="*70)
    
    workflows_dir = 'workflows'
    
    total_workflows_fixed = 0
    total_nodes_fixed = 0
    total_returns_fixed = 0
    
    for filename in sorted(os.listdir(workflows_dir)):
        if not filename.endswith('.json'):
            continue
        
        filepath = os.path.join(workflows_dir, filename)
        print(f"\n{filename}:")
        
        nodes_fixed, returns_fixed = fix_workflow(filepath)
        
        if nodes_fixed > 0:
            total_workflows_fixed += 1
            total_nodes_fixed += nodes_fixed
            total_returns_fixed += returns_fixed
            print(f"  ✅ {nodes_fixed} nodes, {returns_fixed} returns fixed")
        else:
            print(f"  ✓ Already compliant")
    
    print("\n" + "="*70)
    print(f"RESULTS:")
    print(f"  Workflows modified: {total_workflows_fixed}")
    print(f"  Nodes fixed: {total_nodes_fixed}")
    print(f"  Returns fixed: {total_returns_fixed}")
    print("="*70)
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
