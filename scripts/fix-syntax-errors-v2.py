#!/usr/bin/env python3
"""
FIX SYNTAX ERRORS V2
Surgical fix for specific syntax errors in BB_07 and BB_08
"""
import json
import os
import re

def fix_bb08_braces():
    filepath = 'workflows/BB_08_JWT_Auth_Helper.json'
    if not os.path.exists(filepath): return
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # BB_08: Missing } for data object before _meta
    # Pattern: data: { ... , _meta: {
    # We look for `validated: true` followed by `,` followed by `_meta`
    
    # Regex allow whitespace
    pattern = r'(validated: true\s*),(\s*_meta: \{)'
    replacement = r'\1},\2'
    
    if re.search(pattern, content):
        new_content = re.sub(pattern, replacement, content)
        with open(filepath, 'w') as f:
            f.write(new_content)
        print("✓ Fixed BB_08 missing braces")
    else:
        print("? BB_08 pattern not found")

def fix_bb07_comma():
    filepath = 'workflows/BB_07_Notification_Retry_Worker.json'
    if not os.path.exists(filepath): return
    
    with open(filepath, 'r') as f:
        content = f.read()
        
    # BB_07: Missing comma after length, and success: false -> true
    # Pattern: failed: results.filter(r => !r.success).length
    # followed by success: false
    
    # We want to insert comma and change false to true
    
    # Pattern
    pattern = r'(failed: results\.filter\(r => !r\.success\)\.length)(\s+success: )false,'
    replacement = r'\1,\2true,'
    
    if re.search(pattern, content):
        new_content = re.sub(pattern, replacement, content)
        with open(filepath, 'w') as f:
            f.write(new_content)
        print("✓ Fixed BB_07 comma and success flag")
    else:
        print("? BB_07 pattern not found")

def main():
    fix_bb08_braces()
    fix_bb07_comma()

if __name__ == '__main__':
    main()
