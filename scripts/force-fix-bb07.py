#!/usr/bin/env python3
import os

bb07_path = 'workflows/BB_07_Notification_Retry_Worker.json'

with open(bb07_path, 'r') as f:
    content = f.read()

# Exact chunk from view_file, hopefully whitespace matches
bad_chunk = """          failed: results.filter(r => !r.success).length
      success: false,"""

good_chunk = """          failed: results.filter(r => !r.success).length,
      success: true,"""

if bad_chunk in content:
    new_content = content.replace(bad_chunk, good_chunk)
    with open(bb07_path, 'w') as f:
        f.write(new_content)
    print("Fixed BB_07")
else:
    print("Could not find chunk in BB_07")
    # Debug: print what we have locally
    start_idx = content.find("failed: results")
    if start_idx != -1:
        print("Found similar content:")
        print(content[start_idx:start_idx+100])
