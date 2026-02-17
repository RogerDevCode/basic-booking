#!/usr/bin/env python3
"""
Test all leaf workflows (workflows that don't call other workflows).
Excludes BB_00_Global_Error_Handler (special case).
"""

import json
import requests
import sys
from datetime import date

BASE_URL = "http://localhost:5678"

# Test cases for each leaf workflow
TEST_CASES = {
    "BB_01_Telegram_Gateway": {
        "webhook_path": "telegram-webhook",
        "tests": [
            {
                "name": "Happy path - valid message",
                "input": {"message": {"chat": {"id": 123456789}, "from": {"first_name": "Test"}, "text": "/start"}},
                "expected_success": True
            },
            {
                "name": "Error - missing chat.id",
                "input": {"message": {"from": {"first_name": "Test"}, "text": "/start"}},
                "expected_success": False
            }
        ]
    },
    "BB_02_Security_Firewall": {
        "webhook_path": "bb02-security",
        "tests": [
            {
                "name": "Happy path - valid telegram_id",
                "input": {"telegram_id": "123456789", "action": "access"},
                "expected_success": True
            },
            {
                "name": "Error - missing telegram_id",
                "input": {"action": "access"},
                "expected_success": False
            }
        ]
    },
    "BB_03_00_Main": {
        "webhook_path": "bb03-main",
        "tests": [
            {
                "name": "Happy path - valid provider_slug",
                "input": {"provider_slug": "test-provider", "target_date": str(date.today()), "days_range": 7},
                "expected_success": True
            },
            {
                "name": "Error - missing provider_slug",
                "input": {"target_date": str(date.today())},
                "expected_success": False
            }
        ]
    },
    "BB_03_01_InputValidation": {
        "webhook_path": "bb03-input-validation",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"test_field": "test_value"},
                "expected_success": True
            }
        ]
    },
    "BB_03_02_ProviderData": {
        "webhook_path": "bb03-provider-data",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"provider_slug": "test-provider"},
                "expected_success": True
            }
        ]
    },
    "BB_03_03_ScheduleConfig": {
        "webhook_path": "bb03-schedule-config",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"provider_slug": "test-provider", "target_date": str(date.today())},
                "expected_success": True
            }
        ]
    },
    "BB_03_04_BookingsData": {
        "webhook_path": "bb03-bookings-data",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"provider_slug": "test-provider", "target_date": str(date.today())},
                "expected_success": True
            }
        ]
    },
    "BB_03_05_CalculateSlots": {
        "webhook_path": "bb03-calculate-slots",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"provider_slug": "test-provider", "slots": ["09:00", "10:00"]},
                "expected_success": True
            }
        ]
    },
    "BB_03_06_ValidateConfig": {
        "webhook_path": "bb03-validate-config",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"config": {"key": "value"}},
                "expected_success": True
            }
        ]
    },
    "BB_04_Validate_Input": {
        "webhook_path": "bb04-validate",
        "tests": [
            {
                "name": "Happy path - valid input",
                "input": {"action": "booking", "user_id": "00000000-0000-0000-0000-000000000001", "provider_id": "00000000-0000-0000-0000-000000000002"},
                "expected_success": True
            },
            {
                "name": "Error - invalid action",
                "input": {"action": "invalid", "user_id": "00000000-0000-0000-0000-000000000001", "provider_id": "00000000-0000-0000-0000-000000000002"},
                "expected_success": False
            }
        ]
    },
    "BB_05_Notification_Engine": {
        "webhook_path": "notify-batch",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"notification": "test"},
                "expected_success": True
            }
        ]
    },
    "BB_06_Admin_Dashboard": {
        "webhook_path": "admin-v3",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"admin_action": "list"},
                "expected_success": True
            }
        ]
    },
    "BB_07_Notification_Retry_Worker": {
        "webhook_path": "notification-retry",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"retry": True},
                "expected_success": True
            }
        ]
    },
    "BB_08_JWT_Auth_Helper": {
        "webhook_path": "jwt-auth-helper",
        "tests": [
            {
                "name": "Error - missing Authorization header",
                "input": {},
                "expected_success": False
            }
        ]
    },
    "BB_09_Deep_Link_Redirect": {
        "webhook_path": "deep-link-redirect",
        "tests": [
            {
                "name": "Happy path - valid slug",
                "input": {"slug": "test-slug"},
                "expected_success": True
            },
            {
                "name": "Error - missing slug",
                "input": {},
                "expected_success": False
            }
        ]
    },
    "BB_04_Booking_Transaction": {
        "webhook_path": "book-transaction",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"transaction": "test"},
                "expected_success": True
            }
        ]
    },
    "BB_04_CONNECTIONS_ONLY": {
        "webhook_path": "bb04-connections",
        "tests": [
            {
                "name": "Happy path - any input",
                "input": {"test": "connections"},
                "expected_success": True
            }
        ]
    }
}

def test_workflow(wf_name, config):
    """Test a workflow with all its test cases."""
    url = f"{BASE_URL}/webhook/{config['webhook_path']}"
    results = []
    
    for test in config['tests']:
        test_name = test['name']
        input_data = test['input']
        expected = test['expected_success']
        
        try:
            response = requests.post(url, json=input_data, timeout=30)
            result = response.json()
            
            actual_success = result.get('success')
            
            if actual_success == expected:
                print(f"  ✅ {test_name}")
                results.append(True)
            else:
                print(f"  ❌ {test_name}: expected success={expected}, got {actual_success}")
                if not actual_success:
                    print(f"     error_code: {result.get('error_code')}")
                results.append(False)
                
        except Exception as e:
            print(f"  ❌ {test_name}: {type(e).__name__}: {e}")
            results.append(False)
    
    return results

def main():
    print("=" * 60)
    print("LEAF WORKFLOWS TEST SUITE")
    print(f"Date: {date.today()}")
    print("=" * 60)
    
    total_passed = 0
    total_tests = 0
    workflow_results = {}
    
    for wf_name, config in TEST_CASES.items():
        print(f"\n{wf_name}:")
        results = test_workflow(wf_name, config)
        passed = sum(results)
        total = len(results)
        total_passed += passed
        total_tests += total
        workflow_results[wf_name] = {"passed": passed, "total": total}
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    for wf_name, r in workflow_results.items():
        status = "✅" if r['passed'] == r['total'] else "⚠️"
        print(f"{status} {wf_name}: {r['passed']}/{r['total']}")
    
    print()
    print(f"Total: {total_passed}/{total_tests} tests passed")
    
    return 0 if total_passed == total_tests else 1

if __name__ == '__main__':
    sys.exit(main())
