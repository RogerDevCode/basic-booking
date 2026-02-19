#!/usr/bin/env python3
import os
"""
Test BB_03* workflows individually with mock data.
Tests happy path for each workflow using PRODUCTION webhooks.
"""

import json
import requests
import sys
from datetime import datetime, date

BASE_URL = os.getenv("N8N_API_URL", "http://localhost:5678")

TEST_CASES = {
    "BB_03_00_Main": {
        "webhook_path": "bb03-main",
        "input": {
            "provider_slug": "test-provider",
            "target_date": str(date.today()),
            "days_range": 7
        },
        "expected_data_fields": ["provider_slug", "target_date", "days_range"],
        "description": "Main orchestrator - validates provider_slug"
    },
    "BB_03_01_InputValidation": {
        "webhook_path": "bb03-input-validation",
        "input": {
            "test_field": "test_value",
            "number_field": 123
        },
        "expected_data_fields": ["test_field", "number_field"],
        "description": "Input validation stub - passes through data"
    },
    "BB_03_02_ProviderData": {
        "webhook_path": "bb03-provider-data",
        "input": {
            "provider_slug": "test-provider"
        },
        "expected_data_fields": ["provider_slug"],
        "description": "Provider data stub - passes through data"
    },
    "BB_03_03_ScheduleConfig": {
        "webhook_path": "bb03-schedule-config",
        "input": {
            "provider_slug": "test-provider",
            "target_date": str(date.today())
        },
        "expected_data_fields": ["provider_slug", "target_date"],
        "description": "Schedule config stub - passes through data"
    },
    "BB_03_04_BookingsData": {
        "webhook_path": "bb03-bookings-data",
        "input": {
            "provider_slug": "test-provider",
            "target_date": str(date.today())
        },
        "expected_data_fields": ["provider_slug", "target_date"],
        "description": "Bookings data stub - passes through data"
    },
    "BB_03_05_CalculateSlots": {
        "webhook_path": "bb03-calculate-slots",
        "input": {
            "provider_slug": "test-provider",
            "slots": ["09:00", "10:00", "11:00"]
        },
        "expected_data_fields": ["provider_slug", "slots"],
        "description": "Calculate slots stub - passes through data"
    },
    "BB_03_06_ValidateConfig": {
        "webhook_path": "bb03-validate-config",
        "input": {
            "config": {"key": "value"}
        },
        "expected_data_fields": ["config"],
        "description": "Validate config - passes through data"
    },
    "BB_03_Slot_Availability": {
        "webhook_path": "bb03-slot-availability",
        "input": {
            "provider_slug": "test-provider",
            "target_date": str(date.today()),
            "days_range": 7
        },
        "expected_data_fields": [],  # Returns whatever the subworkflow returns
        "description": "Slot availability orchestrator - calls subworkflows"
    }
}

def test_workflow(name, config):
    """Test a single workflow."""
    print(f"\n{'='*60}")
    print(f"TEST: {name}")
    print(f"Description: {config['description']}")
    print(f"{'='*60}")
    
    url = f"{BASE_URL}/webhook/{config['webhook_path']}"
    
    print(f"URL: {url}")
    print(f"Input: {json.dumps(config['input'], indent=2)}")
    
    try:
        response = requests.post(
            url,
            json=config['input'],
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        print(f"\nStatus: {response.status_code}")
        
        if response.status_code != 200:
            print(f"❌ FAILED: HTTP {response.status_code}")
            print(f"Response: {response.text[:500]}")
            return False, None
        
        result = response.json()
        print(f"Response: {json.dumps(result, indent=2)}")
        
        # Validate response structure
        issues = []
        
        # Check top-level required fields
        if "success" not in result:
            issues.append("Missing 'success' field")
        elif result["success"] != True:
            issues.append(f"'success' is not True: {result.get('success')}")
        
        if "error_code" not in result:
            issues.append("Missing 'error_code' field")
        elif result.get("error_code") is not None:
            issues.append(f"'error_code' should be null on success: {result.get('error_code')}")
        
        if "error_message" not in result:
            issues.append("Missing 'error_message' field")
        
        if "data" not in result:
            issues.append("Missing 'data' field")
        
        if "_meta" not in result:
            issues.append("Missing '_meta' field")
        else:
            meta = result["_meta"]
            if "source" not in meta:
                issues.append("Missing '_meta.source'")
            if "timestamp" not in meta:
                issues.append("Missing '_meta.timestamp'")
            if "workflow_id" not in meta:
                issues.append("Missing '_meta.workflow_id'")
            elif meta["workflow_id"] != name:
                issues.append(f"_meta.workflow_id mismatch: expected {name}, got {meta['workflow_id']}")
        
        # Check data fields - handle nested structure
        # The data field contains another success/data structure from the Success node
        if "data" in result and result["data"]:
            data = result["data"]
            
            # Check if data has nested structure (from Success node)
            if isinstance(data, dict) and "success" in data and "data" in data:
                # Nested structure - check inner data
                inner_data = data.get("data", {})
                for field in config["expected_data_fields"]:
                    if field not in inner_data:
                        issues.append(f"Missing expected field in data.data: {field}")
            else:
                # Direct structure
                for field in config["expected_data_fields"]:
                    if field not in data:
                        issues.append(f"Missing expected field in data: {field}")
        
        if issues:
            print(f"\n❌ FAILED: Validation errors:")
            for issue in issues:
                print(f"   - {issue}")
            return False, result
        
        print(f"\n✅ PASSED: All validations successful")
        return True, result
        
    except requests.exceptions.ConnectionError:
        print(f"❌ FAILED: Cannot connect to N8N server at {BASE_URL}")
        return False, None
    except requests.exceptions.Timeout:
        print(f"❌ FAILED: Request timed out")
        return False, None
    except json.JSONDecodeError as e:
        print(f"❌ FAILED: Invalid JSON response: {e}")
        print(f"Response text: {response.text[:500]}")
        return False, None
    except Exception as e:
        print(f"❌ FAILED: {type(e).__name__}: {e}")
        return False, None

def main():
    print("=" * 60)
    print("BB_03* WORKFLOWS TEST SUITE (PRODUCTION)")
    print(f"Date: {datetime.now().isoformat()}")
    print("=" * 60)
    
    results = {}
    passed = 0
    failed = 0
    
    for name, config in TEST_CASES.items():
        success, result = test_workflow(name, config)
        results[name] = {"success": success, "result": result}
        if success:
            passed += 1
        else:
            failed += 1
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total:  {len(results)}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    
    if failed > 0:
        print("\nFailed workflows:")
        for name, r in results.items():
            if not r["success"]:
                print(f"  - {name}")
    
    return 0 if failed == 0 else 1

if __name__ == '__main__':
    sys.exit(main())
