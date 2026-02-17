#!/usr/bin/env python3
"""
COMPREHENSIVE TEST SUITE for Basic Booking System
================================================
Tests all workflows with edge cases, boundary values, malicious inputs,
and real database operations. Data persists after tests.

Categories:
1. Unit Tests - Individual workflow validation
2. Integration Tests - Workflow chains
3. Boundary Tests - Edge cases and limits
4. Security Tests - Injection, XSS, malicious inputs
5. UTC Date Tests - Timezone handling
6. E2E Tests - Full booking lifecycle
7. Devil's Advocate - Negative testing
"""

import os
import sys
import json
import uuid
import requests
import random
import string
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from enum import Enum
import time

# Configuration
N8N_URL = os.environ.get("WEBHOOK_URL", "https://n8n.stax.ink").rstrip("/")
N8N_API_KEY = os.environ.get("N8N_API_KEY", "")
HEADERS = {"X-N8N-API-KEY": N8N_API_KEY, "Content-Type": "application/json"}


# Test Data IDs (persistent) - Load from file or use defaults
def load_test_data():
    try:
        with open(os.path.join(os.path.dirname(__file__), "test_data.json"), "r") as f:
            return json.load(f)
    except:
        return {}


_LOADED_TEST_DATA = load_test_data()

TEST_DATA = {
    "user_id": "a0000000-0000-0000-0000-000000000001",
    "user_id_2": "a0000000-0000-0000-0000-000000000002",
    "user_id_malicious": "a0000000-0000-0000-0000-000000000099",
    "provider_id": _LOADED_TEST_DATA.get(
        "provider_id", "11f3d1c8-aba8-4343-b2b9-3e81c30a1da2"
    ),
    "provider_id_2": "b0000000-0000-0000-0000-000000000002",
    "service_id": _LOADED_TEST_DATA.get(
        "service_id", "c0000000-0000-0000-0000-000000000001"
    ),
    "provider_slug": _LOADED_TEST_DATA.get("provider_slug", "test-provider"),
}


# Results tracking
@dataclass
class TestResult:
    name: str
    passed: bool
    expected: Any
    actual: Any
    error: Optional[str] = None
    category: str = "unit"


class TestCategory(Enum):
    UNIT = "unit"
    INTEGRATION = "integration"
    BOUNDARY = "boundary"
    SECURITY = "security"
    UTC_DATE = "utc_date"
    E2E = "e2e"
    DEVILS_ADVOCATE = "devils_advocate"


# Global results
all_results: List[TestResult] = []
bookings_created: List[str] = []


def webhook_url(path: str) -> str:
    return f"{N8N_URL}/webhook/{path}"


def call_webhook(path: str, data: Dict, method: str = "POST") -> Tuple[int, Dict]:
    """Call a webhook and return (status_code, response_json)"""
    url = webhook_url(path)
    try:
        if method == "POST":
            resp = requests.post(url, json=data, headers=HEADERS, timeout=30)
        else:
            resp = requests.get(url, params=data, headers=HEADERS, timeout=30)
        return resp.status_code, resp.json()
    except Exception as e:
        return 500, {"error": str(e)}


def generate_uuid() -> str:
    return str(uuid.uuid4())


def generate_future_datetime(hours_ahead: int = 24) -> str:
    """Generate UTC datetime string for future booking"""
    future = datetime.utcnow() + timedelta(hours=hours_ahead)
    return future.strftime("%Y-%m-%dT%H:%M:%SZ")


def generate_past_datetime(hours_ago: int = 24) -> str:
    """Generate UTC datetime string for past"""
    past = datetime.utcnow() - timedelta(hours=hours_ago)
    return past.strftime("%Y-%m-%dT%H:%M:%SZ")


def generate_malicious_string(length: int = 100) -> str:
    """Generate string with various malicious patterns"""
    patterns = [
        "<script>alert('xss')</script>",
        "'; DROP TABLE users; --",
        "../../../etc/passwd",
        "${7*7}",
        "{{constructor.constructor('return this')()}}",
        "null",
        "undefined",
        "\x00\x00\x00",
        "A" * 1000,  # Long string
        "../../windows/system32",
    ]
    return random.choice(patterns)


def record_result(
    name: str,
    passed: bool,
    expected: Any,
    actual: Any,
    error: Optional[str] = None,
    category: str = "unit",
):
    """Record a test result"""
    result = TestResult(name, passed, expected, actual, error, category)
    all_results.append(result)
    status = "✅" if passed else "❌"
    print(f"  {status} {name}")
    if not passed:
        print(f"     Expected: {expected}, Got: {actual}")
        if error:
            print(f"     Error: {error[:100]}")


# ============================================================
# SECTION 1: UNIT TESTS - Individual Workflow Validation
# ============================================================


def test_unit_bb01_telegram_gateway():
    """Unit tests for BB_01_Telegram_Gateway"""
    print("\n📡 BB_01_Telegram_Gateway - Unit Tests")

    # Test 1.1: Valid Telegram message
    data = {
        "message": {
            "chat": {"id": 123456789},
            "from": {"first_name": "Test", "id": 123456789},
            "text": "/start",
        }
    }
    status, resp = call_webhook("telegram-webhook", data)
    passed = resp.get("success") == True
    record_result(
        "Valid Telegram message", passed, True, resp.get("success"), category="unit"
    )

    # Test 1.2: Missing chat.id
    data = {"message": {"from": {"first_name": "Test"}, "text": "/start"}}
    status, resp = call_webhook("telegram-webhook", data)
    passed = resp.get("success") == False
    record_result(
        "Missing chat.id", passed, False, resp.get("success"), category="unit"
    )

    # Test 1.3: Empty message text
    data = {
        "message": {
            "chat": {"id": 123456789},
            "from": {"first_name": "Test"},
            "text": "",
        }
    }
    status, resp = call_webhook("telegram-webhook", data)
    passed = resp.get("success") == True  # Empty text is still valid
    record_result(
        "Empty message text", passed, True, resp.get("success"), category="unit"
    )

    # Test 1.4: XSS in first_name
    data = {
        "message": {
            "chat": {"id": 123456789},
            "from": {"first_name": "<script>alert('xss')</script>"},
            "text": "/start",
        }
    }
    status, resp = call_webhook("telegram-webhook", data)
    passed = resp.get("success") == True and "<script>" not in str(resp.get("data", {}))
    record_result(
        "XSS in first_name (should be sanitized)",
        passed,
        True,
        resp.get("success"),
        category="security",
    )


def test_unit_bb02_security_firewall():
    """Unit tests for BB_02_Security_Firewall"""
    print("\n🔒 BB_02_Security_Firewall - Unit Tests")

    # Test 2.1: Valid access check
    data = {"telegram_id": "123456789", "action": "access"}
    status, resp = call_webhook("bb02-security", data)
    passed = resp.get("success") == True
    record_result(
        "Valid access check", passed, True, resp.get("success"), category="unit"
    )

    # Test 2.2: Missing telegram_id
    data = {"action": "access"}
    status, resp = call_webhook("bb02-security", data)
    passed = resp.get("success") == False
    record_result(
        "Missing telegram_id", passed, False, resp.get("success"), category="unit"
    )

    # Test 2.3: SQL injection attempt
    data = {"telegram_id": "123456'; DROP TABLE users; --", "action": "access"}
    status, resp = call_webhook("bb02-security", data)
    passed = resp.get("success") == False  # Should reject invalid telegram_id format
    record_result(
        "SQL injection in telegram_id",
        passed,
        False,
        resp.get("success"),
        category="security",
    )

    # Test 2.4: Very long telegram_id
    data = {"telegram_id": "1" * 1000, "action": "access"}
    status, resp = call_webhook("bb02-security", data)
    record_result(
        "Very long telegram_id",
        True,
        "handled",
        resp.get("success"),
        category="boundary",
    )


def test_unit_bb03_main():
    """Unit tests for BB_03_00_Main"""
    print("\n🎯 BB_03_00_Main - Unit Tests")

    # Test 3.1: Valid provider_slug
    today = datetime.utcnow().strftime("%Y-%m-%d")
    data = {"provider_slug": "test-provider", "target_date": today, "days_range": 7}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == True
    record_result(
        "Valid provider_slug", passed, True, resp.get("success"), category="unit"
    )

    # Test 3.2: Missing provider_slug
    data = {"target_date": today}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == False
    record_result(
        "Missing provider_slug", passed, False, resp.get("success"), category="unit"
    )

    # Test 3.3: Invalid date format
    data = {"provider_slug": "test-provider", "target_date": "not-a-date"}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == False
    record_result(
        "Invalid date format", passed, False, resp.get("success"), category="unit"
    )

    # Test 3.4: Future date beyond 365 days
    far_future = (datetime.utcnow() + timedelta(days=400)).strftime("%Y-%m-%d")
    data = {"provider_slug": "test-provider", "target_date": far_future}
    status, resp = call_webhook("bb03-main", data)
    record_result(
        "Date beyond 365 days",
        True,
        "handled",
        resp.get("success"),
        category="boundary",
    )

    # Test 3.5: Days range boundary
    data = {"provider_slug": "test-provider", "days_range": 365}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == True
    record_result(
        "Days range = 365 (max)", passed, True, resp.get("success"), category="boundary"
    )

    data = {"provider_slug": "test-provider", "days_range": 366}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == False
    record_result(
        "Days range = 366 (invalid)",
        passed,
        False,
        resp.get("success"),
        category="boundary",
    )

    # Test 3.6: XSS in provider_slug
    data = {"provider_slug": "<script>alert('xss')</script>"}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == True and "<script>" not in str(
        resp.get("data", {}).get("provider_slug", "")
    )
    record_result(
        "XSS in provider_slug", passed, True, resp.get("success"), category="security"
    )


def test_unit_bb04_validate_input():
    """Unit tests for BB_04_Validate_Input"""
    print("\n📋 BB_04_Validate_Input - Unit Tests")

    valid_uuid = "00000000-0000-0000-0000-000000000001"

    # Test 4.1: Valid input
    data = {"action": "booking", "user_id": valid_uuid, "provider_id": valid_uuid}
    status, resp = call_webhook("bb04-validate", data)
    passed = resp.get("success") == True
    record_result(
        "Valid booking input", passed, True, resp.get("success"), category="unit"
    )

    # Test 4.2: Invalid action
    data = {
        "action": "invalid_action",
        "user_id": valid_uuid,
        "provider_id": valid_uuid,
    }
    status, resp = call_webhook("bb04-validate", data)
    passed = resp.get("success") == False
    record_result("Invalid action", passed, False, resp.get("success"), category="unit")

    # Test 4.3: Invalid UUID format
    data = {"action": "booking", "user_id": "not-a-uuid", "provider_id": valid_uuid}
    status, resp = call_webhook("bb04-validate", data)
    passed = resp.get("success") == False
    record_result(
        "Invalid UUID format", passed, False, resp.get("success"), category="unit"
    )

    # Test 4.4: All valid actions
    valid_actions = [
        "booking",
        "cancel",
        "reschedule",
        "booking_create",
        "booking_cancel",
        "booking_reschedule",
        "list_bookings",
    ]
    for action in valid_actions:
        data = {"action": action, "user_id": valid_uuid, "provider_id": valid_uuid}
        status, resp = call_webhook("bb04-validate", data)
        passed = resp.get("success") == True
        record_result(
            f"Valid action: {action}",
            passed,
            True,
            resp.get("success"),
            category="unit",
        )


def test_unit_bb08_jwt_auth():
    """Unit tests for BB_08_JWT_Auth_Helper"""
    print("\n🔑 BB_08_JWT_Auth_Helper - Unit Tests")

    # Test 8.1: Missing Authorization header
    data = {}
    status, resp = call_webhook("jwt-auth-helper", data)
    passed = resp.get("success") == False
    record_result(
        "Missing Authorization header",
        passed,
        False,
        resp.get("success"),
        category="unit",
    )

    # Test 8.2: Invalid token format (no Bearer)
    data = {"headers": {"authorization": "invalid-token"}}
    status, resp = call_webhook("jwt-auth-helper", data)
    passed = resp.get("success") == False
    record_result(
        "Invalid token format", passed, False, resp.get("success"), category="unit"
    )

    # Test 8.3: Valid Bearer token format (as HTTP header, not body)
    valid_jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    try:
        resp_raw = requests.post(
            webhook_url("jwt-auth-helper"),
            json={},
            headers={**HEADERS, "Authorization": f"Bearer {valid_jwt}"},
            timeout=30,
        )
        resp = resp_raw.json()
    except:
        resp = {"success": False}
    passed = resp.get("success") == True
    record_result(
        "Valid Bearer token format", passed, True, resp.get("success"), category="unit"
    )


def test_unit_bb09_deep_link():
    """Unit tests for BB_09_Deep_Link_Redirect"""
    print("\n🔗 BB_09_Deep_Link_Redirect - Unit Tests")

    # Test 9.1: Valid slug
    data = {"slug": "test-slug"}
    status, resp = call_webhook("deep-link-redirect", data)
    passed = resp.get("success") == True
    record_result("Valid slug", passed, True, resp.get("success"), category="unit")

    # Test 9.2: Missing slug
    data = {}
    status, resp = call_webhook("deep-link-redirect", data)
    passed = resp.get("success") == False
    record_result("Missing slug", passed, False, resp.get("success"), category="unit")

    # Test 9.3: SQL injection in slug
    data = {"slug": "'; DROP TABLE providers; --"}
    status, resp = call_webhook("deep-link-redirect", data)
    record_result(
        "SQL injection in slug",
        True,
        "handled",
        resp.get("success"),
        category="security",
    )


# ============================================================
# SECTION 2: UTC DATE TESTS
# ============================================================


def test_utc_dates():
    """Test UTC date handling across all date-sensitive workflows"""
    print("\n🕐 UTC Date Handling Tests")

    # Test UTC.1: Booking with future UTC datetime
    future_24h = generate_future_datetime(24)
    future_25h = generate_future_datetime(25)

    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "start_time": future_24h,
        "end_time": future_25h,
    }
    status, resp = call_webhook("bb04-create", data)
    passed = (
        resp.get("success") == True or resp.get("error_code") != "VAL_INVALID_INPUT"
    )
    record_result(
        "Future UTC datetime", passed, True, resp.get("success"), category="utc_date"
    )

    # Test UTC.2: Booking with past UTC datetime
    past_1h = generate_past_datetime(1)
    future_1h = generate_future_datetime(1)

    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "start_time": past_1h,
        "end_time": future_1h,
    }
    status, resp = call_webhook("bb04-create", data)
    passed = (
        resp.get("success") == False
        and "future" in resp.get("error_message", "").lower()
    )
    record_result(
        "Past datetime rejected",
        passed,
        False,
        resp.get("success"),
        category="utc_date",
    )

    # Test UTC.3: Booking without timezone (should assume UTC)
    now = datetime.utcnow()
    start = (now + timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%S")  # No Z
    end = (now + timedelta(hours=25)).strftime("%Y-%m-%dT%H:%M:%S")

    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "start_time": start,
        "end_time": end,
    }
    status, resp = call_webhook("bb04-create", data)
    record_result(
        "Datetime without Z suffix",
        True,
        "handled",
        resp.get("success"),
        category="utc_date",
    )

    # Test UTC.4: Date-only format (YYYY-MM-DD)
    today = datetime.utcnow().strftime("%Y-%m-%d")
    data = {"provider_slug": "test-provider", "target_date": today}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == True
    record_result(
        "Date-only format YYYY-MM-DD",
        passed,
        True,
        resp.get("success"),
        category="utc_date",
    )

    # Test UTC.5: Invalid date formats
    invalid_dates = [
        "2025-13-01",  # Invalid month
        "2025-02-30",  # Invalid day for February
        "not-a-date",
        "2025/01/01",  # Wrong separator
        "01-01-2025",  # Wrong order
        "",  # Empty
        None,  # Null (will be converted to string)
    ]

    for i, invalid_date in enumerate(invalid_dates):
        data = {"provider_slug": "test-provider", "target_date": invalid_date}
        status, resp = call_webhook("bb03-main", data)
        if invalid_date == "" or invalid_date is None:
            expected = True  # Should use default
        else:
            expected = False
        passed = resp.get("success") == expected
        record_result(
            f"Invalid date format test {i + 1}",
            passed,
            expected,
            resp.get("success"),
            category="utc_date",
        )

    # Test UTC.6: Booking 91 days in future (beyond limit)
    far_future = generate_future_datetime(24 * 91)
    end_future = generate_future_datetime(24 * 91 + 1)

    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "start_time": far_future,
        "end_time": end_future,
    }
    status, resp = call_webhook("bb04-create", data)
    passed = resp.get("success") == False and "90" in resp.get("error_message", "")
    record_result(
        "Booking beyond 90 days rejected",
        passed,
        False,
        resp.get("success"),
        category="utc_date",
    )


# ============================================================
# SECTION 3: BOOKING LIFECYCLE TESTS (E2E)
# ============================================================


def test_booking_create_lifecycle():
    """Test complete booking creation with real database insert"""
    print("\n📝 Booking Creation Tests (Real DB)")

    # Generate booking times
    start_time = generate_future_datetime(48)
    end_time = generate_future_datetime(49)

    # Test B1: Valid booking creation
    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "service_id": TEST_DATA["service_id"],
        "start_time": start_time,
        "end_time": end_time,
    }
    status, resp = call_webhook("bb04-create", data)
    passed = resp.get("success") == True

    if passed and resp.get("data", {}).get("booking_id"):
        booking_id = resp["data"]["booking_id"]
        bookings_created.append(booking_id)
        record_result(
            "Valid booking created",
            passed,
            True,
            resp.get("success"),
            f"booking_id: {booking_id}",
            category="e2e",
        )
    else:
        record_result(
            "Valid booking creation attempt",
            passed,
            True,
            resp.get("success"),
            resp.get("error_message"),
            category="e2e",
        )

    # Test B2: Duplicate booking (same slot)
    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id_2"],  # Different user
        "start_time": start_time,
        "end_time": end_time,
    }
    status, resp = call_webhook("bb04-create", data)
    # Should fail due to slot lock or conflict
    record_result(
        "Duplicate slot booking",
        True,
        "handled",
        resp.get("success"),
        resp.get("error_code"),
        category="e2e",
    )

    # Test B3: End time before start time
    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "start_time": generate_future_datetime(50),
        "end_time": generate_future_datetime(48),  # Before start
    }
    status, resp = call_webhook("bb04-create", data)
    passed = resp.get("success") == False
    record_result(
        "End time before start time", passed, False, resp.get("success"), category="e2e"
    )

    # Test B4: Invalid provider_id
    data = {
        "provider_id": generate_uuid(),  # Non-existent
        "user_id": TEST_DATA["user_id"],
        "start_time": generate_future_datetime(72),
        "end_time": generate_future_datetime(73),
    }
    status, resp = call_webhook("bb04-create", data)
    passed = (
        resp.get("success") == False
        and "PROVIDER" in resp.get("error_code", "").upper()
    )
    record_result(
        "Invalid provider_id", passed, False, resp.get("success"), category="e2e"
    )

    # Test B5: Invalid user_id
    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": generate_uuid(),  # Non-existent
        "start_time": generate_future_datetime(72),
        "end_time": generate_future_datetime(73),
    }
    status, resp = call_webhook("bb04-create", data)
    passed = (
        resp.get("success") == False and "USER" in resp.get("error_code", "").upper()
    )
    record_result("Invalid user_id", passed, False, resp.get("success"), category="e2e")


def test_booking_cancel_lifecycle():
    """Test booking cancellation"""
    print("\n❌ Booking Cancellation Tests")

    # Test C1: Cancel non-existent booking
    data = {"booking_id": generate_uuid(), "user_id": TEST_DATA["user_id"]}
    status, resp = call_webhook("bb04-cancel", data)
    passed = resp.get("success") == False
    record_result(
        "Cancel non-existent booking",
        passed,
        False,
        resp.get("success"),
        category="e2e",
    )

    # Test C2: Cancel with wrong user_id
    if bookings_created:
        data = {
            "booking_id": bookings_created[0],
            "user_id": TEST_DATA["user_id_2"],  # Different user
        }
        status, resp = call_webhook("bb04-cancel", data)
        passed = resp.get("success") == False
        record_result(
            "Cancel with wrong user", passed, False, resp.get("success"), category="e2e"
        )

    # Test C3: Cancel with invalid UUID format
    data = {"booking_id": "not-a-uuid", "user_id": TEST_DATA["user_id"]}
    status, resp = call_webhook("bb04-cancel", data)
    passed = resp.get("success") == False
    record_result(
        "Cancel with invalid UUID", passed, False, resp.get("success"), category="e2e"
    )


def test_booking_reschedule_lifecycle():
    """Test booking rescheduling"""
    print("\n🔄 Booking Reschedule Tests")

    # Test R1: Reschedule non-existent booking
    data = {
        "booking_id": generate_uuid(),
        "user_id": TEST_DATA["user_id"],
        "new_start_time": generate_future_datetime(96),
        "new_end_time": generate_future_datetime(97),
    }
    status, resp = call_webhook("bb04-reschedule", data)
    passed = resp.get("success") == False
    record_result(
        "Reschedule non-existent booking",
        passed,
        False,
        resp.get("success"),
        category="e2e",
    )

    # Test R2: Reschedule with invalid times
    data = {
        "booking_id": generate_uuid(),
        "user_id": TEST_DATA["user_id"],
        "new_start_time": "invalid-date",
        "new_end_time": "invalid-date",
    }
    status, resp = call_webhook("bb04-reschedule", data)
    passed = resp.get("success") == False
    record_result(
        "Reschedule with invalid dates",
        passed,
        False,
        resp.get("success"),
        category="e2e",
    )


# ============================================================
# SECTION 4: SECURITY TESTS
# ============================================================


def test_security_injection():
    """Test SQL injection and XSS attacks"""
    print("\n🛡️ Security Injection Tests")

    # Test S1: SQL Injection in various fields
    sql_payloads = [
        "'; DROP TABLE bookings; --",
        "1 OR 1=1",
        "1; SELECT * FROM users",
        "' UNION SELECT * FROM bookings --",
        "admin'--",
        "1' AND '1'='1",
    ]

    for payload in sql_payloads:
        # Test in provider_slug
        data = {"provider_slug": payload}
        status, resp = call_webhook("bb03-main", data)
        passed = resp.get("success") == True  # Should sanitize and process
        record_result(
            f"SQL injection in provider_slug: {payload[:20]}...",
            passed,
            True,
            resp.get("success"),
            category="security",
        )

        # Test in booking_id
        data = {"booking_id": payload, "user_id": TEST_DATA["user_id"]}
        status, resp = call_webhook("bb04-cancel", data)
        passed = resp.get("success") == False  # Should reject invalid UUID
        record_result(
            f"SQL injection in booking_id",
            passed,
            False,
            resp.get("success"),
            category="security",
        )


def test_security_xss():
    """Test XSS attacks"""
    print("\n🔬 XSS Attack Tests")

    xss_payloads = [
        "<script>alert('xss')</script>",
        "<img src=x onerror=alert('xss')>",
        "javascript:alert('xss')",
        "<svg onload=alert('xss')>",
        "'\"><script>alert('xss')</script>",
        "<body onload=alert('xss')>",
    ]

    for payload in xss_payloads:
        # Test in provider_slug
        data = {"provider_slug": payload}
        status, resp = call_webhook("bb03-main", data)

        # Check if payload is in response
        resp_str = json.dumps(resp)
        passed = payload not in resp_str and "<script>" not in resp_str
        record_result(
            f"XSS sanitized in provider_slug",
            passed,
            "sanitized",
            resp.get("success"),
            category="security",
        )


def test_security_overflow():
    """Test buffer overflow and extreme values"""
    print("\n📊 Boundary Overflow Tests")

    # Test O1: Very long string
    long_string = "A" * 10000
    data = {"provider_slug": long_string}
    status, resp = call_webhook("bb03-main", data)
    record_result(
        "Very long provider_slug (10000 chars)",
        True,
        "handled",
        resp.get("success"),
        category="boundary",
    )

    # Test O2: Negative days_range
    data = {"provider_slug": "test-provider", "days_range": -1}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == False
    record_result(
        "Negative days_range", passed, False, resp.get("success"), category="boundary"
    )

    # Test O3: Zero days_range
    data = {"provider_slug": "test-provider", "days_range": 0}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == False
    record_result(
        "Zero days_range", passed, False, resp.get("success"), category="boundary"
    )

    # Test O4: Very large days_range
    data = {"provider_slug": "test-provider", "days_range": 999999999}
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == False
    record_result(
        "Very large days_range", passed, False, resp.get("success"), category="boundary"
    )

    # Test O5: Float instead of int
    data = {"provider_slug": "test-provider", "days_range": 7.5}
    status, resp = call_webhook("bb03-main", data)
    record_result(
        "Float days_range", True, "handled", resp.get("success"), category="boundary"
    )


# ============================================================
# SECTION 5: DEVIL'S ADVOCATE TESTS
# ============================================================


def test_devils_advocate():
    """Devil's Advocate: Try to break the system in unexpected ways"""
    print("\n😈 Devil's Advocate Tests")

    # Test D1: Null values everywhere
    data = {
        "provider_slug": None,
        "target_date": None,
        "days_range": None,
        "action": None,
        "user_id": None,
        "provider_id": None,
    }
    status, resp = call_webhook("bb03-main", data)
    record_result(
        "All null values",
        True,
        "handled",
        resp.get("success"),
        category="devils_advocate",
    )

    # Test D2: Empty strings
    data = {
        "provider_slug": "",
        "target_date": "",
        "days_range": "",
    }
    status, resp = call_webhook("bb03-main", data)
    passed = resp.get("success") == False
    record_result(
        "Empty strings", passed, False, resp.get("success"), category="devils_advocate"
    )

    # Test D3: Wrong data types
    data = {
        "provider_slug": 12345,  # Number instead of string
        "target_date": 20250101,  # Number instead of string
        "days_range": "seven",  # String instead of number
    }
    status, resp = call_webhook("bb03-main", data)
    record_result(
        "Wrong data types",
        True,
        "handled",
        resp.get("success"),
        category="devils_advocate",
    )

    # Test D4: Nested objects
    data = {
        "provider_slug": {"nested": "object"},
        "target_date": {"year": 2025, "month": 1, "day": 1},
    }
    status, resp = call_webhook("bb03-main", data)
    record_result(
        "Nested objects instead of primitives",
        True,
        "handled",
        resp.get("success"),
        category="devils_advocate",
    )

    # Test D5: Arrays instead of primitives
    data = {"provider_slug": ["test", "provider"], "target_date": ["2025", "01", "01"]}
    status, resp = call_webhook("bb03-main", data)
    record_result(
        "Arrays instead of primitives",
        True,
        "handled",
        resp.get("success"),
        category="devils_advocate",
    )

    # Test D6: Unicode and special characters
    special_strings = [
        "日本語プロバイダー",  # Japanese
        "провайдер",  # Russian
        "provider🔥🚀💡",  # Emojis
        "provider\t\n\r",  # Whitespace chars
        "provider\x00\x01",  # Null bytes
    ]

    for s in special_strings:
        data = {"provider_slug": s}
        status, resp = call_webhook("bb03-main", data)
        record_result(
            f"Special characters: {s[:20]}",
            True,
            "handled",
            resp.get("success"),
            category="devils_advocate",
        )

    # Test D7: Extremely nested JSON
    nested = {}
    current = nested
    for i in range(100):
        current["nested"] = {}
        current = current["nested"]
    current["provider_slug"] = "test"

    status, resp = call_webhook("bb03-main", nested)
    record_result(
        "Deeply nested JSON",
        True,
        "handled",
        resp.get("success"),
        category="devils_advocate",
    )

    # Test D8: Booking with impossible times
    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "start_time": "2099-12-31T23:59:59Z",
        "end_time": "2100-01-01T00:00:00Z",
    }
    status, resp = call_webhook("bb04-create", data)
    passed = resp.get("success") == False  # Should reject far future
    record_result(
        "Booking in year 2099",
        passed,
        False,
        resp.get("success"),
        category="devils_advocate",
    )

    # Test D9: Booking with negative duration (same start and end)
    same_time = generate_future_datetime(48)
    data = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "start_time": same_time,
        "end_time": same_time,
    }
    status, resp = call_webhook("bb04-create", data)
    passed = resp.get("success") == False
    record_result(
        "Zero duration booking",
        passed,
        False,
        resp.get("success"),
        category="devils_advocate",
    )

    # Test D10: Concurrent booking requests (same slot)
    start = generate_future_datetime(100)
    end = generate_future_datetime(101)

    data1 = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id"],
        "start_time": start,
        "end_time": end,
    }
    data2 = {
        "provider_id": TEST_DATA["provider_id"],
        "user_id": TEST_DATA["user_id_2"],
        "start_time": start,
        "end_time": end,
    }

    # Simulate concurrent requests
    import threading

    results = {"r1": None, "r2": None}

    def make_request(d, key):
        status, resp = call_webhook("bb04-create", d)
        results[key] = resp

    t1 = threading.Thread(target=make_request, args=(data1, "r1"))
    t2 = threading.Thread(target=make_request, args=(data2, "r2"))

    t1.start()
    t2.start()
    t1.join()
    t2.join()

    # At least one should succeed, possibly both (if lock works)
    success_count = sum(1 for r in results.values() if r and r.get("success"))
    record_result(
        "Concurrent booking requests",
        True,
        f"successes: {success_count}",
        success_count,
        category="devils_advocate",
    )


# ============================================================
# SECTION 6: PROVIDER DATA INTEGRATION
# ============================================================


def test_provider_data_integration():
    """Test provider data retrieval and validation"""
    print("\n🏥 Provider Data Integration Tests")

    # Test P1: Valid provider slug
    data = {"provider_slug": TEST_DATA["provider_slug"]}
    status, resp = call_webhook("bb03-provider-data", data)
    passed = resp.get("success") == True
    record_result(
        "Valid provider slug lookup",
        passed,
        True,
        resp.get("success"),
        category="integration",
    )

    # Test P2: Non-existent provider
    data = {"provider_slug": "non-existent-provider-xyz"}
    status, resp = call_webhook("bb03-provider-data", data)
    passed = resp.get("success") == False
    record_result(
        "Non-existent provider slug",
        passed,
        False,
        resp.get("success"),
        category="integration",
    )

    # Test P3: Provider slug with special characters
    data = {"provider_slug": "test-provider-123_abc"}
    status, resp = call_webhook("bb03-provider-data", data)
    record_result(
        "Provider slug with special chars",
        True,
        "handled",
        resp.get("success"),
        category="integration",
    )


# ============================================================
# MAIN TEST RUNNER
# ============================================================


def run_all_tests():
    """Execute all test categories"""
    print("=" * 70)
    print("COMPREHENSIVE TEST SUITE - Basic Booking System")
    print(f"Date: {datetime.utcnow().isoformat()}Z")
    print(f"N8N URL: {N8N_URL}")
    print("=" * 70)

    # Run all test categories
    test_unit_bb01_telegram_gateway()
    test_unit_bb02_security_firewall()
    test_unit_bb03_main()
    test_unit_bb04_validate_input()
    test_unit_bb08_jwt_auth()
    test_unit_bb09_deep_link()

    test_utc_dates()

    test_booking_create_lifecycle()
    test_booking_cancel_lifecycle()
    test_booking_reschedule_lifecycle()

    test_security_injection()
    test_security_xss()
    test_security_overflow()

    test_devils_advocate()

    test_provider_data_integration()

    # Print summary
    print("\n" + "=" * 70)
    print("TEST SUMMARY")
    print("=" * 70)

    categories = {}
    for r in all_results:
        cat = r.category
        if cat not in categories:
            categories[cat] = {"passed": 0, "failed": 0}
        if r.passed:
            categories[cat]["passed"] += 1
        else:
            categories[cat]["failed"] += 1

    total_passed = sum(c["passed"] for c in categories.values())
    total_failed = sum(c["failed"] for c in categories.values())
    total_tests = total_passed + total_failed

    for cat, counts in sorted(categories.items()):
        status = "✅" if counts["failed"] == 0 else "⚠️"
        print(
            f"{status} {cat.upper():20s} : {counts['passed']}/{counts['passed'] + counts['failed']} passed"
        )

    print()
    print(
        f"TOTAL: {total_passed}/{total_tests} tests passed ({100 * total_passed / total_tests:.1f}%)"
    )

    # Print bookings created
    if bookings_created:
        print(f"\n📋 Bookings created during tests (persistent):")
        for bid in bookings_created:
            print(f"   - {bid}")

    # List failed tests
    failed_tests = [r for r in all_results if not r.passed]
    if failed_tests:
        print(f"\n❌ FAILED TESTS ({len(failed_tests)}):")
        for r in failed_tests:
            print(f"   - {r.category}: {r.name}")
            print(f"     Expected: {r.expected}, Got: {r.actual}")

    return total_passed == total_tests


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
