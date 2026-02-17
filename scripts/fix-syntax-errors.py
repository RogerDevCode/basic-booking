#!/usr/bin/env python3
"""
FIX SYNTAX ERRORS
Surgical fix for missing braces in BB_08
"""
import json
import os

def fix_bb08():
    filepath = 'workflows/BB_08_JWT_Auth_Helper.json'
    if not os.path.exists(filepath): return
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Pattern: missing brace before _meta in data object
    # The view showed:
    #       ,
    #       _meta: {
    
    # We want to change that comma to },
    
    # We use a specific enough string to avoid false positives
    bad_string = "      ,\n      _meta: {"
    good_string = "      },\n      _meta: {"
    
    if bad_string in content:
        new_content = content.replace(bad_string, good_string)
        with open(filepath, 'w') as f:
            f.write(new_content)
        print("Fixed BB_08 missing braces")

def main():
    fix_bb08()

if __name__ == '__main__':
    main()
