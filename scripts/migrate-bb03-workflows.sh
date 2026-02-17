#!/bin/bash
# migrate-bb03-workflows.sh
# Automates migration of BB_03_* workflows to v2.0 standard

set -e

WORKFLOWS_DIR="/home/manager/Sync/N8N Projects/basic-booking/workflows"
TEMP_DIR="/tmp/workflow-migration"

mkdir -p "$TEMP_DIR"

# List of workflows to migrate (BB_03_01 already done)
WORKFLOWS=(
  "BB_03_02_ProviderData"
  "BB_03_03_ScheduleConfig"
  "BB_03_04_BookingsData"
  "BB_03_05_CalculateSlots"
  "BB_03_06_ValidateConfig"
)

echo "Starting BB_03_* workflow migration..."
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
        
        # Pattern to find return statements with json objects
        # Look for: return [{ json: { ... } }];
        # And add _meta if not present
        
        if '_meta' not in js_code:
            # Replace return statements that don't have _meta
            # This is a simple pattern - may need adjustment
            
            # Pattern 1: success: false returns
            js_code = re.sub(
                r'(return \[\{\\s*json: \{\\s*success: false,\\s*error_code: [^,]+,\\s*error_message: [^,]+,\\s*data: null)(\\s*\}\\s*\}\];)',
                r"\\1,\\n        _meta: {\\n          source: 'subworkflow',\\n          timestamp: new Date().toISOString(),\\n          workflow_id: WORKFLOW_ID\\n        }\\2",
                js_code
            )
            
            # Pattern 2: success: true returns
            js_code = re.sub(
                r'(return \[\{\\s*json: \{\\s*success: true,\\s*error_code: null,\\s*error_message: null,\\s*data: \{[^\}]+\})(\\s*\}\\s*\}\];)',
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
