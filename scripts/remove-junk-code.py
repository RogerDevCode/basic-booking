#!/usr/bin/env python3
"""
REMOVE JUNK CODE
Line-by-line stripper for the bad block inserted by fix-all-contracts.py
"""
import json
import os

def remove_junk_from_file(filepath):
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    modified = False
    
    # Signatures of junk lines (trimmed)
    junk_signatures = [
        "success: true,",
        "error_code: null,",
        "error_message: null,",
        "data: null,",
        "_meta: {",
        "source: 'subworkflow',",
        "timestamp: new Date().toISOString(),",
        "workflow_id: WORKFLOW_ID",
        "workflow_id: '", # variant
        "},"
    ]
    
    for node in data.get('nodes', []):
        if node.get('type') == 'n8n-nodes-base.code':
            code = node.get('parameters', {}).get('jsCode', '')
            if not code:
                continue
            
            lines = code.split('\n')
            new_lines = []
            skip_count = 0
            
            for i, line in enumerate(lines):
                if skip_count > 0:
                    skip_count -= 1
                    continue
                
                stripped = line.strip()
                
                # Check for start of junk block
                if stripped == "success: true,":
                    # Check next few lines to confirm it's the junk block
                    is_junk = True
                    # Check at least the next 3 lines
                    if i + 3 < len(lines):
                        if lines[i+1].strip() != "error_code: null,": is_junk = False
                        if lines[i+2].strip() != "error_message: null,": is_junk = False
                        if lines[i+3].strip() != "data: null,": is_junk = False
                    else:
                        is_junk = False
                        
                    if is_junk:
                        # Found junk block start
                        # It usually spans ~9 lines. 
                        # We blindly skip until we see the closing "}," or we run out of "junk-looking" lines?
                        # Let's count how many lines to skip.
                        # The block is:
                        # 1. success: true,
                        # 2. error_code: null,
                        # 3. error_message: null,
                        # 4. data: null,
                        # 5. _meta: {
                        # 6.   source: ...
                        # 7.   timestamp: ...
                        # 8.   workflow_id: ...
                        # 9. },
                        
                        # We skip 9 lines if they match the pattern roughly
                        skip_count = 8 # Skip this one (implicit) + 8 more
                        modified = True
                        print(f"    Removed junk block at line {i+1} in {node.get('name')}")
                        continue
                
                new_lines.append(line)
            
            if modified:
                node['parameters']['jsCode'] = '\n'.join(new_lines)
    
    if modified:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        return True
    return False

def main():
    print("Removing junk code blocks...")
    workflows_dir = 'workflows'
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            if remove_junk_from_file(filepath):
                print(f"  ✓ Cleaned {filename}")

if __name__ == '__main__':
    main()
