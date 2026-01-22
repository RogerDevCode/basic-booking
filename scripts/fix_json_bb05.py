import re
import os
import json

def sanitize_json_file(filepath):
    print(f"Sanitizing {filepath}...")
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        output = []
        in_string = False
        escape = False
        
        for char in content:
            if in_string:
                if char == '\\':
                    escape = not escape
                    output.append(char)
                elif char == '"' and not escape:
                    in_string = False
                    output.append(char)
                elif char == '\n':
                    output.append('\\n') 
                elif char == '\r':
                    pass 
                elif char == '\t':
                    output.append('\\t')
                elif ord(char) < 0x20:
                    pass 
                else:
                    output.append(char)
                    escape = False
            else:
                if char == '"':
                    in_string = True
                output.append(char)
        
        fixed_content = "".join(output)
        
        # Validate
        json.loads(fixed_content) 
        
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(fixed_content)
        print(f"✅ Fixed {filepath}")
        return True

    except Exception as e:
        print(f"❌ Failed to fix {filepath}: {e}")
        return False

sanitize_json_file("workflows/BB_05_Notification_Engine.json")
