#!/usr/bin/env python3
"""
FIX SYNTAX FINAL
Absolute surgical fix using regex with lax whitespace for BB_07 and BB_08
"""
import json
import os
import re

def fix_workflow_content(filepath, replacements):
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        return

    with open(filepath, 'r') as f:
        content = f.read()
    
    new_content = content
    for pattern, replacement in replacements:
        # Use re.sub with multiline flag if needed, but patterns are simple
        if str(pattern).startswith('r'):
             # It's a regex string, use re
             new_content = re.sub(pattern, replacement, new_content)
        else:
             new_content = new_content.replace(pattern, replacement)
    
    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"✓ Fixed {os.path.basename(filepath)}")
    else:
        print(f"? No patterns matched in {os.path.basename(filepath)}")

def main():
    # BB_07 Fixes
    # 1. Add comma after length
    # 2. Change success: false to success: true
    # 3. Change data: null to data: results (optional, but let's stick to syntax fix first)
    
    # We match the specific boundary between the old code and the inserted block
    bb07_replacements = [
        (r'failed: results\.filter\(r => !r\.success\)\.length\s+success: false,', 
         r'failed: results.filter(r => !r.success).length,\n      success: true,')
    ]
    fix_workflow_content('workflows/BB_07_Notification_Retry_Worker.json', bb07_replacements)

    # BB_08 Fixes
    # 1. Extract Token: validated: true , _meta -> validated: true }, _meta
    # 2. Verify Token: token_exp: payload.exp , _meta -> token_exp: payload.exp }, _meta
    
    bb08_replacements = [
        (r'validated: true\s*,\s*_meta:', r'validated: true\n      },\n      _meta:'),
        (r'token_exp: payload\.exp\s*,\s*_meta:', r'token_exp: payload.exp\n      },\n      _meta:')
    ]
    fix_workflow_content('workflows/BB_08_JWT_Auth_Helper.json', bb08_replacements)

if __name__ == '__main__':
    main()
