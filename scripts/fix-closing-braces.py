#!/usr/bin/env python3
"""
FIX CLOSING BRACES
Finds and removes unexpected closing braces using length-preserving comment stripping
"""
import json
import os
import re

def strip_comments_preserve_length(code):
    """Strip JS comments but replace with spaces to preserve indices"""
    # We can't use simple regex for this if we want to preserve newlines vs spaces
    # But usually just replacing non-newline chars with space is enough
    
    # Simple approach: iterate and track state
    # This is complex to write correctly in one go.
    # Let's try a simpler approach:
    # Use the regex but pass a function to replace with same-length spaces
    
    def replacer(match):
        s = match.group(0)
        return re.sub(r'[^\n]', ' ', s)
    
    # Block comments
    code = re.sub(r'/\*[\s\S]*?\*/', replacer, code)
    # Line comments
    code = re.sub(r'//.*', replacer, code)
    return code

def find_bad_brace_index(code):
    clean = strip_comments_preserve_length(code)
    stack = []
    brace_map = {'(': ')', '[': ']', '{': '}'}
    
    for i, char in enumerate(clean):
        if char in brace_map:
            stack.append((char, i))
        elif char in brace_map.values():
            if not stack:
                return i # Found it!
            opening, pos = stack.pop()
            if brace_map[opening] != char:
                # Mismatched. Usually we assume the closing one is wrong if we are fixing "unexpected closing"
                # But strictly, this is mismatch.
                return i 
    return -1

def fix_workflow(filepath):
    try:
        with open(filepath, 'r') as f:
            data = json.load(f)
    except:
        return

    modified = False
    filename = os.path.basename(filepath)
    
    for node in data.get('nodes', []):
        if node.get('type') != 'n8n-nodes-base.code':
            continue
            
        code = node.get('parameters', {}).get('jsCode', '')
        if not code: continue
        
        # Loop until fixed or max tries
        changed_this_node = False
        for _ in range(5): # Max 5 braces to remove
            bad_idx = find_bad_brace_index(code)
            if bad_idx != -1:
                # print(f"Removing brace at {bad_idx} in {filename} : {node['name']}")
                # Remove char at bad_idx
                code = code[:bad_idx] + code[bad_idx+1:]
                changed_this_node = True
            else:
                break
        
        if changed_this_node:
            node['parameters']['jsCode'] = code
            modified = True
            print(f"Fixed braces in {filename} : {node['name']}")

    if modified:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)

def main():
    workflows_dir = 'workflows'
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.endswith('.json'):
            fix_workflow(os.path.join(workflows_dir, filename))

if __name__ == '__main__':
    main()
