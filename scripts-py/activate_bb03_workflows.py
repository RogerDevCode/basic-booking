#!/usr/bin/env python3
"""
Activate all BB_03* workflows in N8N.
"""

import sys
from pathlib import Path

# Add scripts-py to path
sys.path.insert(0, str(Path(__file__).parent))

import requests
from config import N8NConfig

WORKFLOW_IDS = {
    "BB_03_00_Main": "qhy8QQ0gd9XZeDUV",
    "BB_03_01_InputValidation": "BsHbYxtHTsusMHCF",
    "BB_03_02_ProviderData": "H47K7umoexfwokXJ",
    "BB_03_03_ScheduleConfig": "Mk0zVcooUrAoF1dT",
    "BB_03_04_BookingsData": "tDj8KqzNcI6BehTJ",
    "BB_03_05_CalculateSlots": "A0rZWiKvALsbupmh",
    "BB_03_06_ValidateConfig": "zrNPDEhnjaNShaog",
    "BB_03_Slot_Availability": "CBJ578zUIyfapPzA",
}

def activate_workflow(config, name, wf_id):
    """Activate a workflow."""
    url = f"{config.base_endpoint}/workflows/{wf_id}"
    
    # First get current state
    response = requests.get(url, headers=config.headers)
    if response.status_code != 200:
        print(f"  [ERROR] {name}: Cannot get workflow - {response.status_code}")
        print(f"         Response: {response.text[:200]}")
        return False
    
    workflow = response.json()
    
    # Check if archived
    if workflow.get('isArchived', False):
        print(f"  [SKIP] {name}: Workflow is archived")
        return False
    
    # Check if already active
    if workflow.get('active', False):
        print(f"  [OK] {name}: Already active")
        return True
    
    # Activate it
    activate_url = f"{config.base_endpoint}/workflows/{wf_id}/activate"
    response = requests.post(activate_url, headers=config.headers)
    
    if response.status_code == 200:
        print(f"  [ACTIVATED] {name}")
        return True
    else:
        print(f"  [ERROR] {name}: {response.status_code} - {response.text[:200]}")
        return False

def main():
    config = N8NConfig()
    
    print("Activating BB_03* workflows...")
    print("=" * 60)
    
    activated = 0
    for name, wf_id in WORKFLOW_IDS.items():
        if activate_workflow(config, name, wf_id):
            activated += 1
    
    print("=" * 60)
    print(f"Activated: {activated}/{len(WORKFLOW_IDS)}")

if __name__ == '__main__':
    main()
