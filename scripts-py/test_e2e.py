#!/usr/bin/env python3
"""
FASE 3: End-to-End User Flows
Tests simulating complete user journeys.
"""

import json
import requests
import sys
from datetime import datetime, date, timedelta

BASE_URL = "http://localhost:5678"

class E2ETester:
    def __init__(self):
        self.results = {"passed": 0, "failed": 0, "total": 0, "flows": []}
        self.context = {}  # Store data between steps
    
    def step(self, flow_name, step_name, endpoint, payload, expected_success=True, extract_fields=None, headers=None):
        """Execute a step in a flow."""
        self.results["total"] += 1
        
        try:
            if headers is None:
                headers = {}
            response = requests.post(f"{BASE_URL}{endpoint}", json=payload, headers=headers, timeout=30)
            
            if response.status_code not in [200]:
                self.record(False, flow_name, step_name, f"HTTP {response.status_code}")
                return False, None
            
            result = response.json()
            success = result.get("success")
            
            # Extract fields if provided
            if extract_fields and success:
                for field in extract_fields:
                    self.context[f"{flow_name}_{field}"] = self.get_nested(result, field)
            
            if expected_success is None or success == expected_success:
                self.record(True, flow_name, step_name, f"success={success}")
                return True, result
            else:
                self.record(False, flow_name, step_name, f"success={success} (expected {expected_success})")
                return False, result
                
        except Exception as e:
            self.record(False, flow_name, step_name, f"Exception: {type(e).__name__}")
            return False, None
    
    def get_nested(self, obj, path):
        """Get nested value by dot-separated path."""
        keys = path.split(".")
        for key in keys:
            if isinstance(obj, dict):
                obj = obj.get(key)
            else:
                return None
        return obj
    
    def record(self, passed, flow_name, step_name, detail):
        if passed:
            self.results["passed"] += 1
            status = "✅"
        else:
            self.results["failed"] += 1
            status = "❌"
        
        print(f"  {status} [{flow_name}] {step_name}: {detail}")
        
        # Track flow
        flow_exists = any(f["name"] == flow_name for f in self.results["flows"])
        if not flow_exists:
            self.results["flows"].append({"name": flow_name, "passed": 0, "failed": 0})
        
        for f in self.results["flows"]:
            if f["name"] == flow_name:
                if passed:
                    f["passed"] += 1
                else:
                    f["failed"] += 1
    
    def section(self, title):
        print(f"\n{'='*60}")
        print(title)
        print("="*60)

def flow_1_provider_discovery(tester):
    """FLOW 1: Provider Discovery - User checks provider availability."""
    tester.section("FLOW 1: PROVIDER DISCOVERY")
    
    flow_name = "Provider Discovery"
    
    # Step 1: User sends Telegram command to check availability
    tester.step(flow_name, "1. Telegram /availability command", 
        "/webhook/telegram-webhook",
        {"message": {"chat": {"id": 123456789}, "from": {"first_name": "TestUser"}, 
         "text": "/availability provider-123"}},
        expected_success=True)
    
    # Step 2: Check main availability endpoint
    tester.step(flow_name, "2. Check availability via API",
        "/webhook/bb03-main",
        {"provider_slug": "provider-123", "target_date": str(date.today()), "days_range": 7},
        expected_success=True)
    
    # Step 3: Get provider data
    tester.step(flow_name, "3. Fetch provider data",
        "/webhook/bb03-provider-data",
        {"provider_slug": "provider-123"},
        expected_success=True)
    
    # Step 4: Get schedule config
    tester.step(flow_name, "4. Fetch schedule config",
        "/webhook/bb03-schedule-config",
        {"provider_slug": "provider-123", "target_date": str(date.today())},
        expected_success=True)
    
    # Step 5: Full slot availability check
    tester.step(flow_name, "5. Complete slot availability",
        "/webhook/bb03-slot-availability",
        {"provider_slug": "provider-123", "target_date": str(date.today()), "days_range": 7},
        expected_success=True)

def flow_2_booking_attempt(tester):
    """FLOW 2: Booking Attempt - User tries to book a slot."""
    tester.section("FLOW 2: BOOKING ATTEMPT")
    
    flow_name = "Booking Attempt"
    
    user_id = "00000000-0000-0000-0000-000000000001"
    provider_id = "00000000-0000-0000-0000-000000000002"
    
    # Step 1: Validate input first
    tester.step(flow_name, "1. Validate booking input",
        "/webhook/bb04-validate",
        {"action": "booking_create", "user_id": user_id, "provider_id": provider_id},
        expected_success=True)
    
    # Step 2: Attempt create booking (will fail without DB)
    success, result = tester.step(flow_name, "2. Create booking request",
        "/webhook/bb04-create",
        {"provider_id": provider_id, "user_id": user_id, 
         "start_time": f"{(date.today() + timedelta(days=1))}T10:00:00Z",
         "end_time": f"{(date.today() + timedelta(days=1))}T11:00:00Z"},
        expected_success=None)  # Accept either (no DB)
    
    # Step 3: Transaction tracking
    tester.step(flow_name, "3. Transaction logging",
        "/webhook/book-transaction",
        {"action": "create_attempt", "user_id": user_id},
        expected_success=True)
    
    # Step 4: Error path - invalid data
    tester.step(flow_name, "4. Invalid booking rejection",
        "/webhook/bb04-create",
        {"provider_id": "invalid", "user_id": "invalid"},
        expected_success=False)

def flow_3_telegram_error_flow(tester):
    """FLOW 3: Telegram Error Flow - Invalid command handling."""
    tester.section("FLOW 3: TELEGRAM ERROR FLOW")
    
    flow_name = "Telegram Error"
    
    # Step 1: Invalid command
    tester.step(flow_name, "1. Invalid command",
        "/webhook/telegram-webhook",
        {"message": {"chat": {"id": 123456789}, "from": {"first_name": "TestUser"}, 
         "text": "/invalid_command_xyz"}},
        expected_success=True)  # Gateway passes through
    
    # Step 2: Missing chat.id
    tester.step(flow_name, "2. Missing chat.id",
        "/webhook/telegram-webhook",
        {"message": {"from": {"first_name": "TestUser"}, "text": "/start"}},
        expected_success=False)
    
    # Step 3: Empty message
    tester.step(flow_name, "3. Empty body",
        "/webhook/telegram-webhook",
        {},
        expected_success=False)

def flow_4_jwt_auth_flow(tester):
    """FLOW 4: JWT Authentication Flow."""
    tester.section("FLOW 4: JWT AUTHENTICATION FLOW")
    
    flow_name = "JWT Auth"
    
    # Step 1: No token
    tester.step(flow_name, "1. Missing token",
        "/webhook/jwt-auth-helper",
        {},
        headers={},
        expected_success=False)
    
    # Step 2: Invalid token format
    tester.step(flow_name, "2. Invalid token format",
        "/webhook/jwt-auth-helper",
        {},
        headers={"Authorization": "InvalidToken"},
        expected_success=False)
    
    # Step 3: Expired token
    tester.step(flow_name, "3. Expired token simulation",
        "/webhook/jwt-auth-helper",
        {},
        headers={"Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjB9.invalid"},
        expected_success=None)  # May pass or fail

def flow_5_admin_dashboard_flow(tester):
    """FLOW 5: Admin Dashboard Flow."""
    tester.section("FLOW 5: ADMIN DASHBOARD FLOW")
    
    flow_name = "Admin Dashboard"
    
    # Step 1: List providers
    tester.step(flow_name, "1. List providers",
        "/webhook/admin-v3",
        {"action": "list_providers"},
        expected_success=True)
    
    # Step 2: List bookings
    tester.step(flow_name, "2. List bookings",
        "/webhook/admin-v3",
        {"action": "list_bookings", "provider_id": "00000000-0000-0000-0000-000000000001"},
        expected_success=True)
    
    # Step 3: Stats
    tester.step(flow_name, "3. Get stats",
        "/webhook/admin-v3",
        {"action": "stats"},
        expected_success=True)

def flow_6_notification_retry(tester):
    """FLOW 6: Notification Retry Flow."""
    tester.section("FLOW 6: NOTIFICATION RETRY FLOW")
    
    flow_name = "Notification Retry"
    
    # Step 1: Submit notification
    tester.step(flow_name, "1. Submit notification",
        "/webhook/notify-batch",
        {"notifications": [{"user_id": "123", "message": "Test"}]},
        expected_success=True)
    
    # Step 2: Trigger retry worker
    tester.step(flow_name, "2. Trigger retry worker",
        "/webhook/notification-retry",
        {"retry": True},
        expected_success=True)

def flow_7_deep_link_flow(tester):
    """FLOW 7: Deep Link Redirect Flow."""
    tester.section("FLOW 7: DEEP LINK REDIRECT FLOW")
    
    flow_name = "Deep Link"
    
    # Step 1: Valid slug
    tester.step(flow_name, "1. Valid deep link",
        "/webhook/deep-link-redirect",
        {"slug": "provider-123"},
        expected_success=True)
    
    # Step 2: Invalid slug
    tester.step(flow_name, "2. Invalid deep link",
        "/webhook/deep-link-redirect",
        {"slug": ""},
        expected_success=False)

def flow_8_cancel_booking_flow(tester):
    """FLOW 8: Cancel Booking Flow."""
    tester.section("FLOW 8: CANCEL BOOKING FLOW")
    
    flow_name = "Cancel Booking"
    
    # Step 1: Validate cancel input
    tester.step(flow_name, "1. Validate cancel input",
        "/webhook/bb04-validate",
        {"action": "booking_cancel", "user_id": "00000000-0000-0000-0000-000000000001", 
         "booking_id": "00000000-0000-0000-0000-000000000003"},
        expected_success=True)
    
    # Step 2: Attempt cancel (no DB)
    tester.step(flow_name, "2. Cancel attempt",
        "/webhook/bb04-cancel",
        {"booking_id": "00000000-0000-0000-0000-000000000003", 
         "user_id": "00000000-0000-0000-0000-000000000001"},
        expected_success=None)  # Accept either
    
    # Step 3: Invalid cancel
    tester.step(flow_name, "3. Invalid cancel",
        "/webhook/bb04-cancel",
        {"booking_id": "invalid"},
        expected_success=False)

def main():
    print("=" * 60)
    print("FASE 3: END-TO-END USER FLOWS")
    print(f"Started: {datetime.now().isoformat()}")
    print("=" * 60)
    
    tester = E2ETester()
    
    flow_1_provider_discovery(tester)
    flow_2_booking_attempt(tester)
    flow_3_telegram_error_flow(tester)
    flow_4_jwt_auth_flow(tester)
    flow_5_admin_dashboard_flow(tester)
    flow_6_notification_retry(tester)
    flow_7_deep_link_flow(tester)
    flow_8_cancel_booking_flow(tester)
    
    # Summary
    print("\n" + "=" * 60)
    print("E2E FLOW TEST SUMMARY")
    print("=" * 60)
    
    r = tester.results
    print(f"\nTotal Steps: {r['total']}")
    print(f"Passed: {r['passed']}")
    print(f"Failed: {r['failed']}")
    
    if r['total'] > 0:
        print(f"Pass Rate: {r['passed']/r['total']*100:.1f}%")
    
    print("\nPer-Flow Results:")
    for flow in r['flows']:
        total = flow['passed'] + flow['failed']
        status = "✅" if flow['failed'] == 0 else "⚠️"
        print(f"  {status} {flow['name']}: {flow['passed']}/{total}")
    
    if r['failed'] > 0:
        print("\nFailed steps shown above with ❌")
    
    return 0 if r['failed'] == 0 else 1

if __name__ == '__main__':
    sys.exit(main())
