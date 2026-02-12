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
Full Chain Test for BB_03_Availability_Engine
Calls the orchestrator and verifies the full sub-workflow sequence.
"""

import time
import requests
import json
from workflow_config import N8N_LOCAL_URL
from test_helpers import (
    print_header, print_step, print_success, print_error, print_info, print_warning,
    init_agent, verify_workflow_exists
)

def run_bb03_chain_test():
    print_header("BB_03 Availability Engine - Full Chain Test")
    
    agent = init_agent(N8N_LOCAL_URL)
    if not agent: return False
    
    # 1. Prepare Payload
    payload = {
        "provider_slug": "test-pro",
        "days_range": 3,
        "target_date": "2026-03-01"
    }
    
    print_step(1, 3, "Sending request to BB_03 Main Webhook")
    webhook_url = f"{N8N_LOCAL_URL}/webhook/bb03-main"
    print_info(f"Target: {webhook_url}")
    
    try:
        start_time = time.time()
        response = requests.post(webhook_url, json=payload, timeout=20)
        duration = time.time() - start_time
        
        print_info(f"Response received in {duration:.2f}s (Status: {response.status_code})")
        
        if response.status_code == 200:
            result = response.json()
            print_step(2, 3, "Analyzing chain result")
            
            if result.get('success'):
                print_success("Availability Engine: SUCCESS")
                
                data = result.get('data', {})
                slots = data.get('slots', [])
                print_info(f"Provider: {data.get('provider_name')} ({data.get('provider_slug')})")
                print_info(f"Slots found: {len(slots)}")
                
                if len(slots) > 0:
                    print_success(f"First slot example: {slots[0].get('start_time')}")
                else:
                    print_warning("No slots found for provider (Expected if no schedules exist)")
                
                print_step(3, 3, "Verifying response structure")
                required_keys = ['provider_id', 'provider_name', 'slots', 'timezone']
                missing = [k for k in required_keys if k not in data]
                if not missing:
                    print_success("Response structure: VALID")
                    return True
                else:
                    print_error(f"Response structure: INVALID (Missing keys: {missing})")
                    return False
            else:
                print_error(f"Availability Engine returned failure: {result.get('error_message')}")
                return False
        else:
            print_error(f"Webhook failed with status {response.status_code}")
            print_info(f"Response text: {response.text[:200]}")
            return False
            
    except Exception as e:
        print_error(f"Request failed: {str(e)}")
        return False

if __name__ == "__main__":
    try:
        success = run_bb03_chain_test()
        print("\n" + "="*40)
        if success:
            print_success("BB_03 CHAIN TEST PASSED")
        else:
            print_error("BB_03 CHAIN TEST FAILED")
        sys.exit(0 if success else 1)
    except Exception as e:
        print_error(f"Unexpected error: {str(e)}")
        sys.exit(1)
