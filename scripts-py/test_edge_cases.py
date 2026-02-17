#!/usr/bin/env python3
"""
FASE 1: Edge Cases & Boundary Testing
Tests para casos extremos y límites de inputs.
"""

import json
import requests
import sys
from datetime import datetime, timedelta

BASE_URL = "http://localhost:5678"

class EdgeCaseTester:
    def __init__(self):
        self.results = {"passed": 0, "failed": 0, "total": 0, "details": []}
    
    def test(self, name, endpoint, payload, expect_success=None, expect_error_code=None):
        """Run a single test case."""
        self.results["total"] += 1
        
        try:
            response = requests.post(f"{BASE_URL}{endpoint}", json=payload, timeout=15)
            
            # Handle non-200 responses
            if response.status_code not in [200, 400, 401, 403, 404, 500]:
                self.record(False, name, f"Unexpected status: {response.status_code}")
                return
            
            result = response.json()
            success = result.get("success")
            error_code = result.get("error_code")
            
            # Validate expectations
            if expect_success is not None:
                if success == expect_success:
                    if expect_error_code and error_code != expect_error_code:
                        self.record(False, name, f"Wrong error_code: {error_code} (expected {expect_error_code})")
                    else:
                        self.record(True, name, f"success={success}, error_code={error_code}")
                else:
                    self.record(False, name, f"success={success} (expected {expect_success})")
            else:
                # Just check it doesn't crash
                if response.status_code == 500:
                    self.record(False, name, "Server error 500")
                else:
                    self.record(True, name, f"Handled gracefully: success={success}")
                    
        except requests.exceptions.Timeout:
            self.record(False, name, "Request timeout")
        except Exception as e:
            self.record(False, name, f"Exception: {type(e).__name__}: {str(e)[:50]}")
    
    def record(self, passed, name, detail):
        """Record test result."""
        if passed:
            self.results["passed"] += 1
            print(f"  ✅ {name}: {detail}")
        else:
            self.results["failed"] += 1
            print(f"  ❌ {name}: {detail}")
        self.results["details"].append({"name": name, "passed": passed, "detail": detail})
    
    def section(self, title):
        """Print section header."""
        print(f"\n{'='*60}")
        print(title)
        print("="*60)

def test_empty_null_inputs(tester):
    """Test empty and null inputs."""
    tester.section("1. EMPTY & NULL INPUTS")
    
    endpoints = [
        ("/webhook/telegram-webhook", {}),
        ("/webhook/bb03-main", {}),
        ("/webhook/bb03-provider-data", {}),
        ("/webhook/bb04-validate", {}),
        ("/webhook/bb09-deep-link", {}),
        ("/webhook/jwt-auth-helper", {}),
    ]
    
    for endpoint, _ in endpoints:
        tester.test(f"Empty object: {endpoint}", endpoint, {}, expect_success=False)
    
    # Null values in fields
    tester.test("Null provider_slug", "/webhook/bb03-main", 
        {"provider_slug": None, "target_date": "2026-02-17"}, expect_success=False)
    
    tester.test("Null telegram_id", "/webhook/bb02-security",
        {"telegram_id": None, "action": "access"}, expect_success=False)

def test_string_boundaries(tester):
    """Test string length boundaries."""
    tester.section("2. STRING BOUNDARIES")
    
    # Empty strings
    tester.test("Empty string provider_slug", "/webhook/bb03-main",
        {"provider_slug": "", "target_date": "2026-02-17"}, expect_success=False)
    
    # Single character
    tester.test("Single char provider_slug", "/webhook/bb03-main",
        {"provider_slug": "x", "target_date": "2026-02-17"}, expect_success=True)
    
    # Normal length
    tester.test("Normal provider_slug", "/webhook/bb03-main",
        {"provider_slug": "provider-123", "target_date": "2026-02-17"}, expect_success=True)
    
    # Very long strings
    long_string = "a" * 1000
    tester.test("1000 char string", "/webhook/bb03-main",
        {"provider_slug": long_string, "target_date": "2026-02-17"}, expect_success=False)
    
    # Unicode
    tester.test("Unicode Chinese", "/webhook/bb03-main",
        {"provider_slug": "测试提供商", "target_date": "2026-02-17"}, expect_success=True)
    
    tester.test("Unicode Emoji", "/webhook/bb03-main",
        {"provider_slug": "test🔥🚀✅", "target_date": "2026-02-17"}, expect_success=True)
    
    tester.test("Unicode Arabic", "/webhook/bb03-main",
        {"provider_slug": "مزود-خدمة", "target_date": "2026-02-17"}, expect_success=True)

def test_special_characters(tester):
    """Test special characters and injections."""
    tester.section("3. SPECIAL CHARACTERS")
    
    special_chars = [
        ("Newlines", "test\nvalue"),
        ("Tabs", "test\tvalue"),
        ("Quotes", "test\"value'here"),
        ("Backslashes", "test\\value\\path"),
        ("HTML", "<test>value</test>"),
        ("JSON chars", "test{key:value}"),
        ("Path traversal", "../../../etc/passwd"),
        ("URL encoded", "test%20value%2Fpath"),
        ("Null byte", "test\x00value"),
        ("Control chars", "test\r\n\tvalue"),
    ]
    
    for name, value in special_chars:
        tester.test(f"{name} in provider_slug", "/webhook/bb03-main",
            {"provider_slug": value, "target_date": "2026-02-17"})

def test_date_boundaries(tester):
    """Test date boundary cases."""
    tester.section("4. DATE BOUNDARIES")
    
    today = datetime.now().strftime("%Y-%m-%d")
    yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    
    # Valid dates
    tester.test("Today's date", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": today}, expect_success=True)
    
    tester.test("Tomorrow's date", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": tomorrow}, expect_success=True)
    
    # Edge dates
    tester.test("Yesterday (past)", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": yesterday}, expect_success=True)
    
    tester.test("Year 1900", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": "1900-01-01"})
    
    tester.test("Year 2099", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": "2099-12-31"})
    
    tester.test("Leap year 2024", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": "2024-02-29"}, expect_success=True)
    
    # Invalid dates
    tester.test("Invalid date format", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": "17-02-2026"}, expect_success=False)
    
    tester.test("Invalid month", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": "2026-13-01"}, expect_success=False)
    
    tester.test("Invalid day", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": "2026-02-32"}, expect_success=False)
    
    tester.test("Invalid leap day", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": "2023-02-29"}, expect_success=False)
    
    tester.test("Garbage date", "/webhook/bb03-main",
        {"provider_slug": "test", "target_date": "not-a-date"}, expect_success=False)

def test_number_boundaries(tester):
    """Test number boundary cases."""
    tester.section("5. NUMBER BOUNDARIES")
    
    # days_range tests
    tester.test("days_range = 0", "/webhook/bb03-main",
        {"provider_slug": "test", "days_range": 0}, expect_success=False)
    
    tester.test("days_range = 1", "/webhook/bb03-main",
        {"provider_slug": "test", "days_range": 1}, expect_success=True)
    
    tester.test("days_range = 365", "/webhook/bb03-main",
        {"provider_slug": "test", "days_range": 365}, expect_success=True)
    
    tester.test("days_range = 366", "/webhook/bb03-main",
        {"provider_slug": "test", "days_range": 366}, expect_success=False)
    
    tester.test("days_range = -1", "/webhook/bb03-main",
        {"provider_slug": "test", "days_range": -1}, expect_success=False)
    
    tester.test("days_range = 1.5", "/webhook/bb03-main",
        {"provider_slug": "test", "days_range": 1.5})
    
    tester.test("days_range = 999999", "/webhook/bb03-main",
        {"provider_slug": "test", "days_range": 999999}, expect_success=False)
    
    tester.test("days_range as string", "/webhook/bb03-main",
        {"provider_slug": "test", "days_range": "7"}, expect_success=False)

def test_uuid_validation(tester):
    """Test UUID validation."""
    tester.section("6. UUID VALIDATION")
    
    valid_uuid = "00000000-0000-0000-0000-000000000001"
    
    # Valid UUID
    tester.test("Valid UUID", "/webhook/bb04-create",
        {"provider_id": valid_uuid, "user_id": valid_uuid, 
         "start_time": "2026-02-17T10:00:00Z", "end_time": "2026-02-17T11:00:00Z"})
    
    # Invalid UUIDs
    tester.test("UUID all zeros", "/webhook/bb04-create",
        {"provider_id": "00000000-0000-0000-0000-000000000000", "user_id": valid_uuid,
         "start_time": "2026-02-17T10:00:00Z", "end_time": "2026-02-17T11:00:00Z"})
    
    tester.test("UUID missing dashes", "/webhook/bb04-create",
        {"provider_id": "00000000000000000000000000000001", "user_id": valid_uuid,
         "start_time": "2026-02-17T10:00:00Z", "end_time": "2026-02-17T11:00:00Z"},
        expect_success=False)
    
    tester.test("UUID wrong format", "/webhook/bb04-create",
        {"provider_id": "not-a-uuid", "user_id": valid_uuid,
         "start_time": "2026-02-17T10:00:00Z", "end_time": "2026-02-17T11:00:00Z"},
        expect_success=False)
    
    tester.test("UUID with special chars", "/webhook/bb04-create",
        {"provider_id": "00000000-0000-0000-0000-00000000000G", "user_id": valid_uuid,
         "start_time": "2026-02-17T10:00:00Z", "end_time": "2026-02-17T11:00:00Z"},
        expect_success=False)

def test_array_objects(tester):
    """Test arrays and nested objects."""
    tester.section("7. ARRAYS & NESTED OBJECTS")
    
    # Arrays where strings expected
    tester.test("Array as string field", "/webhook/bb03-main",
        {"provider_slug": ["a", "b", "c"], "target_date": "2026-02-17"},
        expect_success=False)
    
    # Objects where strings expected
    tester.test("Object as string field", "/webhook/bb03-main",
        {"provider_slug": {"nested": "value"}, "target_date": "2026-02-17"},
        expect_success=False)
    
    # Deeply nested
    tester.test("Deeply nested object", "/webhook/bb03-main",
        {"provider_slug": "test", "extra": {"a": {"b": {"c": {"d": "deep"}}}}},
        expect_success=True)
    
    # Array in valid field
    tester.test("Array in slots field", "/webhook/bb03-calculate-slots",
        {"provider_slug": "test", "slots": ["09:00", "10:00", "11:00"]},
        expect_success=True)
    
    tester.test("Empty array in slots", "/webhook/bb03-calculate-slots",
        {"provider_slug": "test", "slots": []},
        expect_success=True)

def test_telegram_specific(tester):
    """Test Telegram-specific edge cases."""
    tester.section("8. TELEGRAM SPECIFIC")
    
    # Very long text
    tester.test("Long message text", "/webhook/telegram-webhook",
        {"message": {"chat": {"id": 123}, "text": "A" * 4096, "from": {"first_name": "Test"}}},
        expect_success=True)
    
    # Empty text
    tester.test("Empty message text", "/webhook/telegram-webhook",
        {"message": {"chat": {"id": 123}, "text": "", "from": {"first_name": "Test"}}},
        expect_success=True)
    
    # No text field
    tester.test("No text field", "/webhook/telegram-webhook",
        {"message": {"chat": {"id": 123}, "from": {"first_name": "Test"}}},
        expect_success=True)
    
    # Sticker instead of text
    tester.test("Sticker message", "/webhook/telegram-webhook",
        {"message": {"chat": {"id": 123}, "sticker": {"file_id": "xyz"}, "from": {"first_name": "Test"}}},
        expect_success=True)
    
    # Negative chat_id (groups)
    tester.test("Negative chat_id (group)", "/webhook/telegram-webhook",
        {"message": {"chat": {"id": -100123456789}, "text": "/start", "from": {"first_name": "Test"}}},
        expect_success=True)
    
    # Very large chat_id
    tester.test("Large chat_id", "/webhook/telegram-webhook",
        {"message": {"chat": {"id": 999999999999999}, "text": "/start", "from": {"first_name": "Test"}}},
        expect_success=True)

def main():
    print("=" * 60)
    print("FASE 1: EDGE CASES & BOUNDARY TESTING")
    print(f"Started: {datetime.now().isoformat()}")
    print("=" * 60)
    
    tester = EdgeCaseTester()
    
    test_empty_null_inputs(tester)
    test_string_boundaries(tester)
    test_special_characters(tester)
    test_date_boundaries(tester)
    test_number_boundaries(tester)
    test_uuid_validation(tester)
    test_array_objects(tester)
    test_telegram_specific(tester)
    
    # Summary
    print("\n" + "=" * 60)
    print("EDGE CASE TEST SUMMARY")
    print("=" * 60)
    
    r = tester.results
    print(f"Total:  {r['total']}")
    print(f"Passed: {r['passed']}")
    print(f"Failed: {r['failed']}")
    print(f"Pass Rate: {r['passed']/r['total']*100:.1f}%")
    
    if r['failed'] > 0:
        print(f"\nFailed tests:")
        for d in r['details']:
            if not d['passed']:
                print(f"  - {d['name']}: {d['detail']}")
    
    return 0 if r['failed'] == 0 else 1

if __name__ == '__main__':
    sys.exit(main())
