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
Automated Test for BB_00_Global_Error_Handler
Triggers an error in a test workflow and verifies BB_00 execution.
"""

import time
import requests
from workflow_config import BB_00_WORKFLOW_ID, TEST_BB00_WORKFLOW_ID, N8N_LOCAL_URL
from test_helpers import (
    print_header, print_step, print_success, print_error, print_info, print_warning,
    init_agent, verify_workflow_exists, count_executions, get_latest_execution
)

def run_auto_test():
    print_header("BB_00 Automated Integration Test")
    
    # 1. Connect
    print_step(1, 5, "Connecting to n8n")
    agent = init_agent(N8N_LOCAL_URL)
    if not agent:
        return False
    
    # 2. Verify BB_00
    print_step(2, 5, "Verifying BB_00_Global_Error_Handler")
    bb00 = verify_workflow_exists(agent, BB_00_WORKFLOW_ID, "BB_00_Global_Error_Handler")
    if not bb00 or not bb00.get('active'):
        print_error("BB_00 is missing or INACTIVE. Please activate it first.")
        return False
    
    # 3. Verify Test Workflow
    print_step(3, 5, "Verifying Test_BB00 workflow")
    test_wf = verify_workflow_exists(agent, TEST_BB00_WORKFLOW_ID, "Test_BB00")
    if not test_wf:
        print_error(f"Test workflow {TEST_BB00_WORKFLOW_ID} not found.")
        return False
    
    # 4. Baseline Latest Execution
    print_step(4, 5, "Getting baseline latest execution for BB_00")
    latest_before = get_latest_execution(agent, BB_00_WORKFLOW_ID)
    before_id = latest_before.get('id') if latest_before else None
    print_info(f"Baseline ID: {before_id}")
    
    # 5. Trigger Specialized Chain Error via Webhook
    print_step(5, 5, "Triggering chain test error via Test_BB00 proxy")
    webhook_url = f"{N8N_LOCAL_URL}/webhook/test-bb00"
    try:
        payload = {
            "mode": "single",
            "test_id": "manual_with_pii"
        }
        response = requests.post(webhook_url, json=payload, timeout=10)
        print_info(f"Webhook response: {response.status_code}")
    except Exception as e:
        print_info(f"Note: Webhook call result: {str(e)}")
    
    print_info("Wait 5 seconds for BB_00 to process...")
    time.sleep(5)
    
    # 6. Verify Result
    latest_after = get_latest_execution(agent, BB_00_WORKFLOW_ID)
    after_id = latest_after.get('id') if latest_after else None
    print_info(f"Final latest ID: {after_id}")
    
    if after_id and after_id != before_id:
        print_success("✅ BB_00 captured the error!")
        
        # 7. Deep inspection
        print_step(6, 5, "Inspecting processing logic")
        latest = agent.get_execution_by_id(after_id)
        if latest and 'data' in latest:
            try:
                run_data = latest['data']['resultData']['runData']
                if 'Final Result' in run_data:
                    final_output = run_data['Final Result'][0]['data']['main'][0][0]['json']
                    
                    if final_output.get('db_logged'):
                        print_success("Database logging: OK")
                    else:
                        print_warning("Database logging: FAILED (Check DB connection)")
                        
                    metrics = final_output.get('metrics', {})
                    print_info(f"Metrics: DB={metrics.get('db_logged')}, Telegram={metrics.get('telegram_sent')}")
                    return True
            except Exception as e:
                print_warning(f"Could not parse deep inspection data: {str(e)}")
                return True
        return True
    else:
        print_error("❌ BB_00 did not record a new execution.")
        return False

if __name__ == "__main__":
    try:
        success = run_auto_test()
        print("\n" + "="*40)
        if success:
            print_success("TEST COMPLETED SUCCESSFULLY")
        else:
            print_error("TEST FAILED")
        sys.exit(0 if success else 1)
    except Exception as e:
        print_error(f"Execution error: {str(e)}")
        sys.exit(1)
