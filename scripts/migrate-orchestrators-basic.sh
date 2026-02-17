#!/bin/bash
# migrate-orchestrators-basic.sh
# Adds basic v2.0 compliance to orchestrator workflows
# NOTE: Switch nodes after Execute Workflow calls must be added manually

set -e

WORKFLOWS_DIR="/home/manager/Sync/N8N Projects/basic-booking/workflows"
TEMP_DIR="/tmp/workflow-migration"

mkdir -p "$TEMP_DIR"

WORKFLOWS=(
  "BB_03_00_Main"
  "BB_04_Booking_Transaction"
  "BB_04_Main_Orchestrator"
  "BB_06_Admin_Dashboard"
)

echo "Starting Orchestrator workflows basic migration..."
echo "=================================================="
echo "NOTE: This adds WORKFLOW_ID, _meta, and errorWorkflow"
echo "      Switch nodes after Execute Workflow calls need manual addition"
echo ""

for workflow in "${WORKFLOWS[@]}"; do
  echo "Processing: $workflow"
  
  FILE="$WORKFLOWS_DIR/${workflow}.json"
  
  if [ ! -f "$FILE" ]; then
    echo "  ❌ File not found: $FILE"
    continue
  fi
  
  # Step 1: Add WORKFLOW_ID constant
  echo "  → Adding WORKFLOW_ID constant..."
  python3 << EOF
import json

with open('$FILE', 'r') as f:
    data = json.load(f)

workflow_id = '$workflow'

for node in data.get('nodes', []):
    if node.get('type') == 'n8n-nodes-base.code':
        js_code = node.get('parameters', {}).get('jsCode', '')
        
        if 'const WORKFLOW_ID' not in js_code:
            if '/**' in js_code:
                lines = js_code.split('\n')
                insert_idx = 0
                for i, line in enumerate(lines):
                    if '*/' in line:
                        insert_idx = i + 1
                        break
                
                lines.insert(insert_idx, f"const WORKFLOW_ID = '{workflow_id}';")
                lines.insert(insert_idx + 1, '')
                js_code = '\n'.join(lines)
                node['parameters']['jsCode'] = js_code

with open('$FILE', 'w') as f:
    json.dump(data, f, indent=2)

print(f"  ✅ Added WORKFLOW_ID")
EOF
  
  # Step 2: Add _meta fields
  echo "  → Adding _meta fields..."
  python3 << EOF
import json
import re

with open('$FILE', 'r') as f:
    data = json.load(f)

for node in data.get('nodes', []):
    if node.get('type') == 'n8n-nodes-base.code':
        js_code = node.get('parameters', {}).get('jsCode', '')
        
        if '_meta' not in js_code and 'WORKFLOW_ID' in js_code:
            js_code = re.sub(
                r'(data: null)(\\s*}\\s*}\\s*\\]\\s*;)',
                r"\\1,\\n        _meta: {\\n          source: 'orchestrator',\\n          timestamp: new Date().toISOString(),\\n          workflow_id: WORKFLOW_ID\\n        }\\2",
                js_code
            )
            
            js_code = re.sub(
                r'(data: \\{[^}]+\\})(\\s*}\\s*}\\s*\\]\\s*;)',
                r"\\1,\\n        _meta: {\\n          source: 'orchestrator',\\n          timestamp: new Date().toISOString(),\\n          workflow_id: WORKFLOW_ID\\n        }\\2",
                js_code,
                flags=re.DOTALL
            )
            
            node['parameters']['jsCode'] = js_code

with open('$FILE', 'w') as f:
    json.dump(data, f, indent=2)

print(f"  ✅ Added _meta fields")
EOF
  
  # Step 3: Add errorWorkflow
  echo "  → Adding errorWorkflow configuration..."
  jq '. + {settings: {executionOrder: "v1", saveManualExecutions: true, callerPolicy: "workflowsFromSameOwner", errorWorkflow: "BB_00_Global_Error_Handler"}}' "$FILE" > "$TEMP_DIR/temp.json"
  mv "$TEMP_DIR/temp.json" "$FILE"
  
  echo "  ✅ Completed basic migration: $workflow"
  echo ""
done

echo "=================================================="
echo "Basic orchestrator migration complete!"
echo ""
echo "⚠️  IMPORTANT: Each orchestrator needs Switch nodes added"
echo "    after Execute Workflow calls to handle success/error"
echo "    This must be done manually or with a custom script"
