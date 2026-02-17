#!/usr/bin/env python3
"""
Fix Execute Workflow nodes - use 'id' mode with just the ID value.
"""

import json
from pathlib import Path

WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"

# Workflow name to ID mapping
WORKFLOW_IDS = {
    "BB_00_Global_Error_Handler": "lDCN0NU7YKNqpHYM",
    "BB_01_Telegram_Gateway": "pCJIr9DZYmXTt6qv",
    "BB_02_Security_Firewall": "acjwJV3G2k31wO0a",
    "BB_03_00_Main": "qhy8QQ0gd9XZeDUV",
    "BB_03_01_InputValidation": "BsHbYxtHTsusMHCF",
    "BB_03_02_ProviderData": "H47K7umoexfwokXJ",
    "BB_03_03_ScheduleConfig": "Mk0zVcooUrAoF1dT",
    "BB_03_04_BookingsData": "tDj8KqzNcI6BehTJ",
    "BB_03_05_CalculateSlots": "A0rZWiKvALsbupmh",
    "BB_03_06_ValidateConfig": "zrNPDEhnjaNShaog",
    "BB_03_Slot_Availability": "CBJ578zUIyfapPzA",
    "BB_04_Booking_Cancel": "oj4cVHSsCjYPILFy",
    "BB_04_Booking_Create": "LzPayzz5wPZ21H0f",
    "BB_04_Booking_Reschedule": "xiPaXD3CVPGwpfLt",
    "BB_04_Booking_Transaction": "FY0Y1vZj7BEa9zgY",
    "BB_04_CONNECTIONS_ONLY": "R7FDsxVjGAOgwGcs",
    "BB_04_Main_Orchestrator": "fHDafwJuRv3nIGPK",
    "BB_04_Validate_Input": "xYmaPDRb4o8alyAk",
    "BB_05_Notification_Engine": "6ldi3987czpzm4sU",
    "BB_06_Admin_Dashboard": "tSMiMqwuUldqic5K",
    "BB_07_Notification_Retry_Worker": "V0P9YLtfF2afndLU",
    "BB_08_JWT_Auth_Helper": "BtDrWD7pmkuCaNKv",
    "BB_09_Deep_Link_Redirect": "W9ha9Z765PMxU0y0",
    "BB_10_Macro_Workflow_Blueprint": "tC3QXTDISyL9568t",
}

def fix_workflow(filepath):
    """Fix Execute Workflow nodes in a workflow."""
    with open(filepath, 'r', encoding='utf-8') as f:
        workflow = json.load(f)
    
    workflow_name = workflow.get('name', '')
    nodes = workflow.get('nodes', [])
    
    fixed = False
    for node in nodes:
        if node.get('type') == 'n8n-nodes-base.executeWorkflow':
            params = node.get('parameters', {})
            wf_ref = params.get('workflowId', {})
            
            # Get the current workflow reference
            current_name = wf_ref.get('cachedResultName', '')
            current_id = wf_ref.get('value', '')
            
            # Determine the ID
            if current_name in WORKFLOW_IDS:
                wf_id = WORKFLOW_IDS[current_name]
            elif current_id in WORKFLOW_IDS.values():
                wf_id = current_id
            else:
                continue
            
            # Set to id mode with just the ID
            params['workflowId'] = wf_id  # Direct string, not an object
            
            fixed = True
            print(f"  [FIX] {workflow_name}: {node.get('name')} -> ID {wf_id}")
    
    if fixed:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(workflow, f, indent=2, ensure_ascii=False)
    
    return fixed

def main():
    print("Fixing Execute Workflow references to use direct ID...")
    print("=" * 60)
    
    fixed_count = 0
    for filepath in sorted(WORKFLOWS_DIR.glob('BB_*.json')):
        if fix_workflow(filepath):
            fixed_count += 1
    
    print("=" * 60)
    print(f"Fixed: {fixed_count} workflows")

if __name__ == '__main__':
    main()
