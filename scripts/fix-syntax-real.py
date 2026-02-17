#!/usr/bin/env python3
"""
REWRITE BB_08 & FIX BB_07
"""
import json
import os

def fix_bb07():
    path = 'workflows/BB_07_Notification_Retry_Worker.json'
    with open(path, 'r') as f:
        content = f.read()
    
    # We match from "failed:" to "success: false," ignoring indentation before "failed"
    # The debug output showed: failed: results.filter(r => !r.success).length\n      success: false,
    
    bad = "failed: results.filter(r => !r.success).length\n      success: false,"
    good = "failed: results.filter(r => !r.success).length,\n      success: true,"
    
    if bad in content:
        new_content = content.replace(bad, good)
        with open(path, 'w') as f:
            f.write(new_content)
        print("✓ Fixed BB_07")
    else:
        print("? BB_07 bad chunk not found (exact match failed)")

def fix_bb08():
    path = 'workflows/BB_08_JWT_Auth_Helper.json'
    
    # We construct the valid JSON structure based on what we saw
    # We can't easily "repair" the file because it has invalid syntax inside the stringified JS code
    # But wait, the syntax error is IN the JS code which is a STRING value in JSON.
    # The JSON file itself is valid JSON (mostly, unless JS code string was broken with unescaped chars).
    # The errors "Mismatched braces" from deep-verify are checking the JS CODE.
    # Deep-verify parses the 'jsCode' string.
    
    print("Rewriting BB_08 via Python dict manipulation...")
    
    with open(path, 'r') as f:
        data = json.load(f)

    # 1. Extract Token
    for node in data['nodes']:
        if node['name'] == 'Extract Token':
             code = node['parameters']['jsCode']
             # Fix missing }
             # Find: validated: true \n , \n _meta
             # We want: validated: true \n }, \n _meta
             
             # Use replace on the jsCode string
             if 'validated: true' in code and ', \n      _meta' not in code:
                 # Try to be flexible
                 code = code.replace("validated: true\n      ,\n      _meta", "validated: true\n      },\n      _meta")
                 # Try variant from previous step view
                 code = code.replace("validated: true\n      ,\n      _meta", "validated: true\n      },\n      _meta") 
                 # Try manual reconstruction if replace fails
                 # The view showed:
                 # token: token,
                 # validated: true
                 # ,
                 # _meta: {
                 
                 pattern_bad = "validated: true\n      ,\n      _meta"
                 pattern_good = "validated: true\n      },\n      _meta"
                 
                 # Let's try to match the whitespace from the view
                 # View:
                 #         token: token,
                 #         validated: true
                 #       ,
                 #       _meta: {
                 
                 # It seems there is indentation.
                 pass

             # Hardcode the known fix if simpler fails
             # New Code end:
             # data: {
             #   token: token,
             #   validated: true
             # },
             # _meta: { ... }
             
             # Regex replace on the code string
             import re
             code = re.sub(r'(validated: true)\s*,\s*(_meta)', r'\1\n      },\n      \2', code)
             node['parameters']['jsCode'] = code
             
        if node['name'] == 'Verify Token':
             code = node['parameters']['jsCode']
             # Fix missing }
             # token_exp: payload.exp \n , \n _meta
             import re
             code = re.sub(r'(token_exp: payload\.exp)\s*,\s*(_meta)', r'\1\n      },\n      \2', code)
             node['parameters']['jsCode'] = code

    with open(path, 'w') as f:
        json.dump(data, f, indent=2)
    print("✓ Rewrote BB_08")

def main():
    fix_bb07()
    fix_bb08()

if __name__ == '__main__':
    main()
