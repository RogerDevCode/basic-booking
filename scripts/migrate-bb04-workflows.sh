#!/bin/bash
# migrate-bb04-workflows.sh
# Automates migration of BB_04_* workflows to v2.0 standard

set -e

WORKFLOWS_DIR="/home/manager/Sync/N8N Projects/basic-booking/workflows"
TEMP_DIR="/tmp/workflow-migration"

mkdir -p "$TEMP_DIR"

# List of BB_04 workflows to migrate
WORKFLOWS=(
  "BB_04_Validate_Input"
  "BB_04_Booking_Create"
  "BB_04_Booking_Cancel"
  "BB_04_Booking_Reschedule"
)

echo "Starting BB_04_* workflow migration..."
echo "======================================"

for workflow in "${WORKFLOWS[@]}"; do
  echo ""
  echo "Processing: $workflow"
  
  FILE="$WORKFLOWS_DIR/${workflow}.json"
  
  if [ ! -f "$FILE" ]; then
    echo "  ❌ File not found: $FILE"
    continue
  fi
  
  # Step 1: Add WORKFLOW_ID constant to all Code nodes
  echo "  → Adding WORKFLOW_ID constant..."
  python3 << EOF
import json
import re

with open('$FILE', 'r') as f:
    data = json.load(f)

workflow_id = '$workflow'

# Process all nodes
for node in data.get('nodes', []):
    if node.get('type') == 'n8n-nodes-base.code':
        js_code = node.get('parameters', {}).get('jsCode', '')
        
        # Check if WORKFLOW_ID already exists
        if 'const WORKFLOW_ID' not in js_code:
            # Add WORKFLOW_ID after the comment block
            if '/**' in js_code:
                # Find end of comment block
                lines = js_code.split('\\n')
                insert_idx = 0
                for i, line in enumerate(lines):
                    if '*/' in line:
                        insert_idx = i + 1
                        break
                
                # Insert WORKFLOW_ID
                lines.insert(insert_idx, f"const WORKFLOW_ID = '{workflow_id}';")
                lines.insert(insert_idx + 1, '')
                js_code = '\\n'.join(lines)
                node['parameters']['jsCode'] = js_code

with open('$FILE', 'w') as f:
    json.dump(data, f, indent=2)

print(f"  ✅ Added WORKFLOW_ID to {workflow_id}")
EOF
  
  # Step 2: Add _meta field to all return statements
  echo "  → Adding _meta fields..."
  python3 << EOF
import json
import re

with open('$FILE', 'r') as f:
    data = json.load(f)

workflow_id = '$workflow'

# Process all Code nodes
for node in data.get('nodes', []):
    if node.get('type') == 'n8n-nodes-base.code':
        js_code = node.get('parameters', {}).get('jsCode', '')
        
        # Only add _meta if not already present
        if '_meta' not in js_code and 'WORKFLOW_ID' in js_code:
            # Pattern to find return statements with json objects
            # Replace data: null} with data: null, _meta: {...}}
            js_code = re.sub(
                r'(data: null)(\\s*}\\s*}\\s*\]\\s*;)',
                r"\\1,\\n        _meta: {\\n          source: 'subworkflow',\\n          timestamp: new Date().toISOString(),\\n          workflow_id: WORKFLOW_ID\\n        }\\2",
                js_code
            )
            
            # Replace data: {...}} with data: {...}, _meta: {...}}
            # This is trickier - need to find closing brace of data object
            js_code = re.sub(
                r'(data: \{[^}]+\})(\\s*}\\s*}\\s*\]\\s*;)',
                r"\\1,\\n        _meta: {\\n          source: 'subworkflow',\\n          timestamp: new Date().toISOString(),\\n          workflow_id: WORKFLOW_ID\\n        }\\2",
                js_code,
                flags=re.DOTALL
            )
            
            node['parameters']['jsCode'] = js_code

with open('$FILE', 'w') as f:
    json.dump(data, f, indent=2)

print(f"  ✅ Added _meta fields to {workflow_id}")
EOF
  
  # Step 3: Add errorWorkflow configuration
  echo "  → Adding errorWorkflow configuration..."
  jq '. + {settings: {executionOrder: "v1", saveManualExecutions: true, callerPolicy: "workflowsFromSameOwner", errorWorkflow: "BB_00_Global_Error_Handler"}}' "$FILE" > "$TEMP_DIR/temp.json"
  mv "$TEMP_DIR/temp.json" "$FILE"
  
  echo "  ✅ Completed: $workflow"
done

echo ""
echo "======================================"
echo "Migration complete!"
echo ""
echo "Migrated workflows:"
for workflow in "${WORKFLOWS[@]}"; do
  echo "  ✅ $workflow"
done
