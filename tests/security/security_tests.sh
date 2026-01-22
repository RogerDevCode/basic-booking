#!/bin/bash
# FIX-04 + FIX-08: Security Tests (Updated for V2 Endpoints)
# OWASP Top 10, SQL Injection, XSS, Authentication

set -e

BASE_URL="${N8N_URL:-http://localhost:5678}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-password}"

echo "=== SECURITY TEST SUITE (V2) ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_count=0
passed_count=0
failed_count=0

# Test helper
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    test_count=$((test_count + 1))
    
    echo -n "Test $test_count: $test_name... "
    
    # Execute and capture output
    local output
    output=$(eval "$test_command" 2>&1)
    
    if echo "$output" | grep -q "$expected_result"; then
        echo -e "${GREEN}PASSED${NC}"
        passed_count=$((passed_count + 1))
    else
        echo -e "${RED}FAILED${NC}"
        echo "  Expected match for: $expected_result"
        echo "  Got output: $output"
        failed_count=$((failed_count + 1))
    fi
}

echo ""
echo "--- SQL INJECTION TESTS ---"

# Test 1: SQL Injection in tenant_id
run_test "SQLi: tenant_id field" \
  "curl -s '$BASE_URL/webhook/api/stats-v2?tenant_id=%27%20OR%20%271%27%3D%271' -H 'Authorization: Bearer test_token'" \
  "401"

# Test 2: SQL Injection via UNION
run_test "SQLi: UNION SELECT" \
  "curl -s '$BASE_URL/webhook/api/stats-v2?tenant_id=test%27%20UNION%20SELECT%20* FROM%20users--' -H 'Authorization: Bearer test_token'" \
  "401"

# Test 3: SQL Injection via comment
run_test "SQLi: Comment injection" \
  "curl -s '$BASE_URL/webhook/api/stats-v2?tenant_id=test%27%20OR%20%271%27%3D%271%27--' -H 'Authorization: Bearer test_token'" \
  "401"

echo ""
echo "--- AUTHENTICATION TESTS ---"

# Test 4: No auth header
run_test "Auth: Missing Authorization header" \
  "curl -s -w '%{http_code}' '$BASE_URL/webhook/api/stats-v2' -o /dev/null" \
  "401"

# Test 5: Invalid token format
run_test "Auth: Invalid token format" \
  "curl -s -w '%{http_code}' '$BASE_URL/webhook/api/stats-v2' -H 'Authorization: InvalidFormat' -o /dev/null" \
  "401"

echo ""
echo "--- XSS TESTS ---"

# Test 6: XSS in user input (Availability v2)
run_test "XSS: Script injection in availability" \
  "curl -s '$BASE_URL/webhook/availability-v2' -H 'Content-Type: application/json' -d '{\"user_id\": \"<script>alert(1)</script>\"}'" \
  "error"

# Test 7: XSS in booking (Book v2)
run_test "XSS: HTML entity injection in book" \
  "curl -s '$BASE_URL/webhook/book-v2' -H 'Content-Type: application/json' -d '{\"user_id\": \"test<script>alert(1)</script>\"}'" \
  "error"

echo ""
echo "--- COMPLIANCE TESTS ---"

# Test 8: HSTS header
run_test "Headers: HSTS" \
  "curl -s -I '$BASE_URL' | grep -i 'strict-transport-security' || echo 'Missing'" \
  "strict-transport-security"

echo ""
echo "--- SUMMARY ---"
echo "Total tests: $test_count"
echo -e "Passed: ${GREEN}$passed_count${NC}"
echo -e "Failed: ${RED}$failed_count${NC}"

# Exit with error if any tests failed
if [ $failed_count -gt 0 ]; then
    echo ""
    echo -e "${RED}SECURITY TESTS FAILED${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}ALL SECURITY TESTS PASSED${NC}"
    exit 0
fi
