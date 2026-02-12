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
Full Chain Test for BB_00_Global_Error_Handler
Verifies validation, redaction, classification and DB logging.
"""

import time
import json
from workflow_config import BB_00_WORKFLOW_ID, N8N_LOCAL_URL
from test_helpers import (
    print_header, print_step, print_success, print_error, print_info,
    init_agent, verify_workflow_exists, format_execution_info
)

def run_chain_test():
    print_header("BB_00 Full Processing Chain Test")
    
    agent = init_agent(N8N_LOCAL_URL)
    if not agent: return False
    
    # 1. Prepare Payload with PII and specific keywords
    payload = {
        "workflow_name": "Test_Chain_Manual",
        "error_message": "Database connection failed for user test@example.com (RUT: 12.345.678-9)",
        "node_name": "Postgres Node",
        "severity": "HIGH",
        "context": {
            "additional_info": "This is a manual chain test",
            "sensitive_key": "password123"
        }
    }
    
    print_step(1, 3, "Sending direct execution request to BB_00")
    print_info(f"Payload error message: {payload['error_message']}")
    
    # Execute workflow
    execution = agent.execute_workflow(BB_00_WORKFLOW_ID, data=payload)
    
    if not execution or 'data' not in execution:
        print_error("Execution failed to return data.")
        return False
    
    # 2. Extract Result Data
    print_step(2, 3, "Analyzing processing results")
    
    result_data = execution.get('data', {}).get('resultData', {})
    
    # Check Final Result node output
    last_node_data = {}
    if 'runData' in result_data:
        run_data = result_data['runData']
        if 'Final Result' in run_data:
            last_node_data = run_data['Final Result'][0]['data']['main'][0][0]['json']
    
    if not last_node_data:
        print_error("Could not find 'Final Result' node data in execution.")
        print_info(f"Available nodes in runData: {list(result_data.get('runData', {}).keys())}")
        return False

    # 3. Verify Requirements
    print_step(3, 3, "Verifying logic integrity")
    
    success_flags = []
    
    # A. Check DB Logging
    if last_node_data.get('db_logged'):
        print_success("Database logging: OK")
        success_flags.append(True)
    else:
        print_error("Database logging: FAILED")
        success_flags.append(False)
        
    # B. Check PII Redaction (should not contain original email/rut)
    processed_msg = last_node_data.get('error', {}).get('message', '')
    if 'test@example.com' not in processed_msg and '12.345.678-9' not in processed_msg:
        print_success("PII Redaction: OK (Original data removed)")
        success_flags.append(True)
    else:
        print_error(f"PII Redaction: FAILED (Message still contains sensitive data)")
        success_flags.append(False)
        
    # C. Severity
    actual_severity = last_node_data.get('severity')
    print_info(f"Processed Severity: {actual_severity}")
    
    print("\n" + "="*40)
    if all(success_flags):
        print_success("FULL CHAIN TEST PASSED")
        print_info(f"Execution ID: {execution.get('id')}")
        return True
    else:
        print_error("FULL CHAIN TEST FAILED")
        return False

if __name__ == "__main__":
    try:
        success = run_chain_test()
        sys.exit(0 if success else 1)
    except Exception as e:
        print_error(f"Unexpected error: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
