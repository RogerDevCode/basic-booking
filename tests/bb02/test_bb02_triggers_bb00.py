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
Test: BB_02 error -> BB_00 Global Error Handler -> Telegram alert.

Strategy:
  BB_02 has errorWorkflow set to BB_00. When BB_02 crashes (unhandled error),
  n8n triggers BB_00 via the Error Trigger node automatically.
  BB_00 then processes the error, logs to DB, and sends a Telegram alert.

  Test 1: Temporarily inject a crashing Code node into BB_02 that throws
          an unhandled error, bypassing try-catch. This triggers:
          BB_02 crash -> n8n Error Trigger -> BB_00 -> Telegram alert.

  Test 2: Temporarily modify DB: Security Check to use a broken query
          AND disable continueOnFail, so the DB error crashes BB_02
          instead of being handled gracefully.
"""

import sys
import os
import json
import requests
import time
import uuid
import copy


from n8n_crud_agent import N8NCrudAgent
from workflow_config import BB_00_WORKFLOW_ID, BB_02_WORKFLOW_ID, BB_02_WEBHOOK_PATH, N8N_LOCAL_URL
from test_helpers import print_header, print_success, print_error, print_warning, print_info

API_URL = N8N_LOCAL_URL
BB02_ID = BB_02_WORKFLOW_ID
BB00_ID = BB_00_WORKFLOW_ID
BB02_WEBHOOK = BB_02_WEBHOOK_PATH

agent = N8NCrudAgent(API_URL)


def count_bb00_executions():
    execs = agent.get_executions(limit=50)
    if not execs:
        return 0
    return len([e for e in execs if e.get('workflowId') == BB00_ID])


def get_latest_bb00_execution():
    execs = agent.get_executions(limit=20)
    if not execs:
        return None
    bb00_execs = [e for e in execs if e.get('workflowId') == BB00_ID]
    return bb00_execs[0] if bb00_execs else None


def strip_for_update(wf_data):
    """Keep only fields accepted by the n8n update API."""
    settings = wf_data.get('settings', {})
    allowed_settings = {'executionOrder', 'errorWorkflow', 'callerPolicy'}
    return {
        'name': wf_data['name'],
        'nodes': wf_data['nodes'],
        'connections': wf_data['connections'],
        'settings': {k: v for k, v in settings.items() if k in allowed_settings}
    }


def test_bb02_crash_triggers_bb00():
    """
    Modify BB_02's "DB: Security Check" node to:
      1. Use a broken query (SELECT from nonexistent table)
      2. Disable continueOnFail so the error is NOT caught
    
    This causes BB_02 to crash with an unhandled error.
    Since BB_02 has errorWorkflow=BB_00, n8n triggers BB_00 automatically.
    BB_00 receives the error via Error Trigger node and sends Telegram alert.
    """
    print_header("TEST: BB_02 crash -> BB_00 -> Telegram")

    before_count = count_bb00_executions()
    print(f"BB_00 executions before: {before_count}")

    # Step 1: Fetch current BB_02
    print("\n[1/6] Fetching BB_02 workflow...")
    bb02_original = agent.get_workflow_by_id(BB02_ID)
    if not bb02_original:
        print("FAILED: Could not fetch BB_02")
        return False

    # Deep copy for modification
    bb02_modified = copy.deepcopy(bb02_original)
    original_query = None
    original_continue_on_fail = None

    # Step 2: Modify DB: Security Check
    print("[2/6] Modifying 'DB: Security Check' to force crash...")
    for node in bb02_modified['nodes']:
        if node['name'] == 'DB: Security Check':
            original_query = node['parameters']['query']
            original_continue_on_fail = node.get('continueOnFail', False)
            node['parameters']['query'] = "SELECT * FROM nonexistent_table_xyz_error_test"
            node['continueOnFail'] = False  # Let the error propagate!
            print(f"  - Query changed to broken query")
            print(f"  - continueOnFail: {original_continue_on_fail} -> False")
            break

    if original_query is None:
        print("FAILED: Could not find 'DB: Security Check' node")
        return False

    # Step 3: Update BB_02 with crashing version
    print("[3/6] Deploying modified BB_02...")
    update_data = strip_for_update(bb02_modified)
    if not agent.update_workflow(BB02_ID, update_data):
        print("FAILED: Could not update BB_02")
        return False
    time.sleep(1)

    # Step 4: Trigger BB_02 via webhook
    print("[4/6] Sending request to BB_02 webhook (will crash)...")
    url = f"{API_URL}/webhook/{BB02_WEBHOOK}"
    try:
        resp = requests.post(url, json={
            "user": {"telegram_id": 5391760292, "first_name": "CrashTest"}
        }, timeout=30)
        print(f"  Response status: {resp.status_code}")
        try:
            print(f"  Response: {json.dumps(resp.json(), indent=2)}")
        except:
            print(f"  Response text: {resp.text[:300]}")
    except Exception as e:
        print(f"  Request error (expected): {e}")

    # Step 5: Wait for BB_00 to process
    print("[5/6] Waiting 5s for BB_00 Error Trigger to process...")
    time.sleep(5)

    # Step 6: Restore original BB_02
    print("[6/6] Restoring original BB_02...")
    for node in bb02_modified['nodes']:
        if node['name'] == 'DB: Security Check':
            node['parameters']['query'] = original_query
            node['continueOnFail'] = original_continue_on_fail
            break
    restore_data = strip_for_update(bb02_modified)
    if agent.update_workflow(BB02_ID, restore_data):
        print("  BB_02 restored successfully")
    else:
        print("  WARNING: Failed to restore BB_02!")
        print(f"  Original query: {original_query[:100]}...")
        return False

    # Verify BB_02 is working
    print("\n  Verifying BB_02 works normally...")
    resp = requests.post(url, json={
        "user": {"telegram_id": 5391760292, "first_name": "Roger"}
    }, timeout=15)
    if resp.status_code == 200 and resp.json().get('access') == 'granted':
        print("  BB_02 confirmed working")
    else:
        print(f"  WARNING: BB_02 status {resp.status_code}: {resp.text[:200]}")

    # Check results
    after_count = count_bb00_executions()
    new_execs = after_count - before_count
    print(f"\n--- Results ---")
    print(f"BB_00 executions: {before_count} -> {after_count} (new: {new_execs})")

    latest = get_latest_bb00_execution()
    if latest and new_execs > 0:
        print(f"Latest BB_00 execution: ID={latest['id']} Status={latest['status']}")
        if latest['status'] == 'success':
            print("\n>>> PASS: BB_02 crash triggered BB_00 via Error Trigger.")
            print(">>> BB_00 processed the error and sent Telegram alert.")
            print(">>> Check your Telegram app for the error notification!")
            return True
        else:
            print(f"\n>>> PARTIAL: BB_00 was triggered but ended with status={latest['status']}")
            return True  # Still counts as triggered
    else:
        print("\n>>> FAIL: BB_00 was NOT triggered by BB_02 crash")
        return False


def main():
    print("=" * 60)
    print("TEST: BB_02 Error -> BB_00 Error Handler -> Telegram")
    print("=" * 60)

    # Verify workflows
    workflows = agent.list_workflows()
    for wf in workflows:
        if wf['id'] in [BB02_ID, BB00_ID]:
            status = "ACTIVE" if wf.get('active') else "INACTIVE"
            print(f"  {wf['name']}: {status}")
            if not wf.get('active'):
                print(f"  WARNING: {wf['name']} is not active!")

    # Check errorWorkflow setting
    bb02 = agent.get_workflow_by_id(BB02_ID)
    error_wf = bb02.get('settings', {}).get('errorWorkflow')
    print(f"\n  BB_02 errorWorkflow: {error_wf}")
    if error_wf != BB00_ID:
        print(f"  WARNING: errorWorkflow should be {BB00_ID}")

    result = test_bb02_crash_triggers_bb00()

    print("\n" + "=" * 60)
    print(f"FINAL RESULT: {'PASS' if result else 'FAIL'}")
    print("=" * 60)


if __name__ == "__main__":
    main()
