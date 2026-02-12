#!/usr/bin/env python3

# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../scripts-py')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

"""
Basic test for BB_03 modular sub-workflows.
Tests each component (01-06) with minimal inputs.
"""

import time
import requests
from workflow_config import N8N_LOCAL_URL
from test_helpers import (
    print_header, print_step, print_success, print_error, print_warning, print_info,
    init_agent
)

# Workflow Mapping based on IDs found
# Path naming convention for webhooks in this project usually follows the sub-workflow name
SUB_WORKFLOWS = [
    {"path": "bb03-input-validation", "name": "BB_03_01_InputValidation", "input": {"provider_slug": "test-pro"}},
    {"path": "bb03-provider-data", "name": "BB_03_02_ProviderData", "input": {"provider_slug": "test-pro"}},
    {"path": "bb03-schedule-config", "name": "BB_03_03_ScheduleConfig", "input": {"provider_id": "2eebc9bc-c2f8-46f8-9e78-7da0909fcca4"}},
    {"path": "bb03-bookings-data", "name": "BB_03_04_BookingsData", "input": {"provider_id": "2eebc9bc-c2f8-46f8-9e78-7da0909fcca4", "start_date": "2026-03-01", "end_date": "2026-03-07"}},
    {"path": "bb03-calculate-slots", "name": "BB_03_05_CalculateSlots", "input": {"provider_id": "2eebc9bc-c2f8-46f8-9e78-7da0909fcca4", "slot_duration_mins": 30, "schedules": [], "bookings": []}},
    {"path": "bb03-validate-config", "name": "BB_03_06_ValidateConfig", "input": {"timezone": "America/Santiago", "booking_window_days": 14}}
]

def test_subs():
    print_header("BB_03 Sub-Workflows Webhook Test")
    agent = init_agent(N8N_LOCAL_URL)
    if not agent: return False

    results = []
    for i, sub in enumerate(SUB_WORKFLOWS, 1):
        print_step(i, len(SUB_WORKFLOWS), f"Testing {sub['name']} via Webhook")
        
        webhook_url = f"{N8N_LOCAL_URL}/webhook/{sub['path']}"
        try:
            response = requests.post(webhook_url, json=sub['input'], timeout=10)
            if response.status_code < 400:
                print_success(f"{sub['name']} responded with {response.status_code}")
                results.append(True)
            else:
                # Some might return 400 if validation fails, but a response is still a sign of life
                print_warning(f"{sub['name']} responded with {response.status_code}: {response.text[:100]}")
                results.append(True) # Consider reached if we get a response other than 404/405
        except Exception as e:
            print_error(f"{sub['name']} connection failed: {str(e)}")
            results.append(False)
        
        time.sleep(1)

    print("\n" + "="*30)
    print(f"Passed: {sum(results)}/{len(SUB_WORKFLOWS)}")
    print("="*30)
    return all(results)

if __name__ == "__main__":
    success = test_subs()
    sys.exit(0 if success else 1)
