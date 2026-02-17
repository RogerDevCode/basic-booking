#!/usr/bin/env python3
"""
Deep verification script to check for:
1. Malformed return statements (missing braces, syntax errors)
2. Incomplete _meta structures in error paths
3. Inconsistent object properties
"""
import json
import os
import re

def strip_comments(code):
    """Strip JS comments from code"""
    # Regex for block comments /* ... */
    code = re.sub(r'/\*[\s\S]*?\*/', '', code)
    # Regex for line comments // ...
    code = re.sub(r'//.*', '', code)
    return code

def check_brace_balance(code):
    """Check if braces are balanced"""
    # Strip comments first to avoid false positives in JSDoc
    clean_code = strip_comments(code)
    
    stack = []
    brace_map = {'(': ')', '[': ']', '{': '}'}
    
    for i, char in enumerate(clean_code):
        if char in brace_map:
            stack.append((char, i))
        elif char in brace_map.values():
            if not stack:
                return False, f"Unexpected closing brace at position {i}"
            opening, pos = stack.pop()
            if brace_map[opening] != char:
                return False, f"Mismatched braces: {opening} at {pos} vs {char} at {i}"
    
    if stack:
        return False, f"Unclosed braces: {stack}"
    
    return True, "OK"

def extract_return_statements(code):
    """Extract all return statements from code"""
    # Pattern to match return statements
    pattern = r'return\s+\[?\{[^}]*\}[^\]]*\]?;?'
    
    returns = []
    lines = code.split('\n')
    
    in_return = False
    return_buffer = []
    brace_count = 0
    
    for i, line in enumerate(lines, 1):
        if 'return' in line and not in_return:
            in_return = True
            return_buffer = [(i, line)]
            brace_count = line.count('{') - line.count('}')
        elif in_return:
            return_buffer.append((i, line))
            brace_count += line.count('{') - line.count('}')
            
            if brace_count <= 0 and (';' in line or ']' in line):
                returns.append(return_buffer)
                in_return = False
                return_buffer = []
                brace_count = 0
    
    return returns

def check_meta_completeness(return_statement):
    """Check if _meta has all required fields"""
    code = '\n'.join([line for _, line in return_statement])
    
    if '_meta' not in code:
        return False, "Missing _meta"
    
    required_fields = ['source', 'timestamp', 'workflow_id']
    missing = []
    
    for field in required_fields:
        if field not in code:
            missing.append(field)
    
    if missing:
        return False, f"Missing _meta fields: {', '.join(missing)}"
    
    return True, "Complete"

def check_standard_contract(return_statement):
    """Check if return has all standard contract fields"""
    code = '\n'.join([line for _, line in return_statement])
    
    required_fields = ['success', 'error_code', 'error_message', 'data', '_meta']
    missing = []
    
    for field in required_fields:
        if f'{field}:' not in code and f'"{field}":' not in code:
            missing.append(field)
    
    if missing:
        return False, f"Missing fields: {', '.join(missing)}"
    
    return True, "Complete"

def analyze_code_node(node, workflow_name):
    """Analyze a single Code Node"""
    if node.get('type') != 'n8n-nodes-base.code':
        return None
    
    node_name = node.get('name', 'Unknown')
    code = node.get('parameters', {}).get('jsCode', '')
    
    if not code:
        return None
    
    issues = []
    
    # Check brace balance
    balanced, msg = check_brace_balance(code)
    if not balanced:
        issues.append(f"🔴 SYNTAX: {msg}")
    
    # Extract and analyze return statements
    returns = extract_return_statements(code)
    
    if not returns:
        issues.append(f"⚠️  No return statements found")
    else:
        for idx, ret in enumerate(returns, 1):
            ret_code = '\n'.join([line for _, line in ret])
            line_nums = [num for num, _ in ret]
            
            # Check _meta completeness
            meta_ok, meta_msg = check_meta_completeness(ret)
            if not meta_ok:
                issues.append(f"🔴 Return #{idx} (lines {line_nums[0]}-{line_nums[-1]}): {meta_msg}")
            
            # Check standard contract
            contract_ok, contract_msg = check_standard_contract(ret)
            if not contract_ok:
                issues.append(f"🟠 Return #{idx} (lines {line_nums[0]}-{line_nums[-1]}): {contract_msg}")
            
            # Check for malformed structures
            if 'json: {' in ret_code and 'json: {' in ret_code:
                # Check for nested json: { json: { pattern
                if ret_code.count('json: {') > 1:
                    issues.append(f"⚠️  Return #{idx}: Possible nested json structure")
    
    if issues:
        return {
            'workflow': workflow_name,
            'node': node_name,
            'issues': issues,
            'return_count': len(returns)
        }
    
    return None

def analyze_workflow(filepath):
    """Analyze all Code Nodes in a workflow"""
    filename = os.path.basename(filepath)
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', filename.replace('.json', ''))
    
    problems = []
    
    for node in data.get('nodes', []):
        result = analyze_code_node(node, workflow_name)
        if result:
            problems.append(result)
    
    return problems

def main():
    workflows_dir = 'workflows'
    
    print("="*70)
    print("DEEP CODE VERIFICATION")
    print("="*70)
    print("\nChecking for:")
    print("  1. Malformed return statements")
    print("  2. Incomplete _meta structures")
    print("  3. Missing standard contract fields")
    print("="*70)
    
    all_problems = []
    
    for filename in sorted(os.listdir(workflows_dir)):
        if not filename.endswith('.json'):
            continue
        
        filepath = os.path.join(workflows_dir, filename)
        problems = analyze_workflow(filepath)
        
        if problems:
            all_problems.extend(problems)
    
    # Report
    if not all_problems:
        print("\n✅ NO ISSUES FOUND - All Code Nodes are well-formed!")
        return 0
    
    print(f"\n🔍 Found issues in {len(all_problems)} nodes:\n")
    
    for problem in all_problems:
        print(f"\n{'='*70}")
        print(f"Workflow: {problem['workflow']}")
        print(f"Node: {problem['node']}")
        print(f"Return statements: {problem['return_count']}")
        print(f"{'='*70}")
        
        for issue in problem['issues']:
            print(f"  {issue}")
    
    print(f"\n{'='*70}")
    print(f"Total nodes with issues: {len(all_problems)}")
    print(f"{'='*70}")
    
    return 1

if __name__ == '__main__':
    import sys
    sys.exit(main())
