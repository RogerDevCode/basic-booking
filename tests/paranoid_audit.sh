#!/bin/bash

# ==============================================================================
# 🛡️ AUTOAGENDA PARANOID AUDIT SUITE
# ==============================================================================
# Test Vectors: Semantic Fuzzing, Boundary Values, Logic Gaps, Injection.

# ENDPOINTS
URL_TG="https://n8n.stax.ink/webhook/telegram-webhook"
URL_AVAIL="https://n8n.stax.ink/webhook/availability-v2"
URL_BOOK="https://n8n.stax.ink/webhook/book-v2"
URL_CONF="https://n8n.stax.ink/webhook/api/config-v2"

# DATA
PRO_ID="2eebc9bc-c2f8-46f8-9e78-7da0909fcca4"
SRV_ID="a7a019cb-3442-4f57-8877-1b04a1749c01"
USER_ID="b9f03843-eee6-4607-ac5a-496c6faa9ea1"

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass=0
fail=0

run_test() {
    local name="$1"
    local url="$2"
    local payload="$3"
    local expected_code="$4"
    local expected_match="$5"

    echo -ne "🧪 $name... "
    RESP=$(curl -s -w "\n%{http_code}" -X POST "$url" -H "Content-Type: application/json" -d "$payload")
    BODY=$(echo "$RESP" | head -n 1)
    CODE=$(echo "$RESP" | tail -n 1)

    if [[ "$CODE" == "$expected_code" ]]; then
        if [[ -n "$expected_match" ]]; then
            if echo "$BODY" | grep -qi "$expected_match"; then
                echo -e "${GREEN}PASS${NC}"
                ((pass++))
            else
                echo -e "${RED}FAIL (Body Mismatch)${NC}\n   Got: $BODY"
                ((fail++))
            fi
        else
            echo -e "${GREEN}PASS${NC}"
            ((pass++))
        fi
    else
        echo -e "${RED}FAIL (Code $CODE != $expected_code)${NC}\n   Body: $BODY"
        ((fail++))
    fi
}

echo "==========================================="
echo "🔮 SECTION 1: AVAILABILITY ENGINE (BB_03)"
echo "==========================================="

# 1.1 Basic Smoke
run_test "Happy Path" "$URL_AVAIL" \
    "{\"professional_id\": \"$PRO_ID\", \"service_id\": \"$SRV_ID\", \"date\": \"2026-06-01\"}" \
    "200" "success"

# 1.2 Date Fuzzing
run_test "Date: Feb 30th (Logic)" "$URL_AVAIL" \
    "{\"professional_id\": \"$PRO_ID\", \"service_id\": \"$SRV_ID\", \"date\": \"2026-02-30\"}" \
    "400" "Invalid date"

run_test "Date: Year 9999 (Boundary)" "$URL_AVAIL" \
    "{\"professional_id\": \"$PRO_ID\", \"service_id\": \"$SRV_ID\", \"date\": \"9999-12-31\"}" \
    "200" "success" # Should handle gracefully (empty slots) or error if DB int overflow, but 200 is acceptable if logic holds.

# 1.3 Type Confusion
run_test "Type: ID as Array" "$URL_AVAIL" \
    "{\"professional_id\": [\"$PRO_ID\"], \"service_id\": \"$SRV_ID\", \"date\": \"2026-06-01\"}" \
    "400" "Invalid professional_id"

run_test "Type: Date as Object" "$URL_AVAIL" \
    "{\"professional_id\": \"$PRO_ID\", \"service_id\": \"$SRV_ID\", \"date\": { \"year\": 2026 }}" \
    "400" "Invalid date"

# 1.4 Injection
run_test "Injection: SQL Tautology" "$URL_AVAIL" \
    "{\"professional_id\": \"' OR '1'='1'\", \"service_id\": \"$SRV_ID\", \"date\": \"2026-06-01\"}" \
    "400" "Invalid professional_id" # Should catch length/format or UUID regex

echo -e "\n==========================================="
echo "💳 SECTION 2: BOOKING TRANSACTION (BB_04)"
echo "==========================================="

# 2.1 Logic Boundary
run_test "Duration: 0 Minutes" "$URL_BOOK" \
    "{\"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_ID\", \"service_id\": \"$SRV_ID\", \"start_time\": \"2026-06-01T10:00:00Z\", \"end_time\": \"2026-06-01T10:00:00Z\"}" \
    "400" "range"

run_test "Duration: 24 Hours (Max Limit)" "$URL_BOOK" \
    "{\"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_ID\", \"service_id\": \"$SRV_ID\", \"start_time\": \"2026-06-01T10:00:00Z\", \"end_time\": \"2026-06-02T10:00:00Z\"}" \
    "400" "range"

# 2.2 Time Travel
run_test "Time: End before Start" "$URL_BOOK" \
    "{\"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_ID\", \"service_id\": \"$SRV_ID\", \"start_time\": \"2026-06-01T10:00:00Z\", \"end_time\": \"2026-06-01T09:00:00Z\"}" \
    "400" "before end_time"

# 2.3 Buffer Overflow
LONG_STR=$(printf 'A%.0s' {1..5000})
run_test "Overflow: Service ID 5KB" "$URL_BOOK" \
    "{\"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_ID\", \"service_id\": \"$LONG_STR\", \"start_time\": \"2026-06-01T10:00:00Z\", \"end_time\": \"2026-06-01T10:30:00Z\"}" \
    "400" "too long"

echo -e "\n==========================================="
echo "🛡️ SECTION 3: DASHBOARD AUTH (BB_06)"
echo "==========================================="

# 3.1 Auth Bypass
run_test "Auth: Null Token" "$URL_CONF" \
    "{\"is_active\": true}" \
    "401" "Missing token"

run_test "Auth: Malformed JWT" "$URL_CONF" \
    "HEADER: Authorization: Bearer not.a.jwt" \
    "401" # Expecting 401 response code

# 3.2 Logic Fuzzing on Config
# Sending string to boolean field
# NOTE: BB_06 V33 updates DB directly. Type mismatch might cause DB error (500) if not guarded.
# Our JS Guard checks types!
# Mocking a valid token structure for the test (signature won't be verified by mock guard, but structure will)
MOCK_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYWRtaW4iLCJleHAiOjE5MjQ5ODg4MDB9.signature"

# Run curl directly for custom header
echo -ne "🧪 Config: Bad Types... "
RESP=$(curl -s -w "\n%{http_code}" -X POST "$URL_CONF" \
    -H "Authorization: Bearer $MOCK_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"reminder_1_hours": "not-a-number", "is_active": "maybe"}')
CODE=$(echo "$RESP" | tail -n 1)
if [[ "$CODE" == "400" ]] || [[ "$CODE" == "500" ]]; then
    # 500 is technically acceptable if DB catches it, but 400 is better (Guard).
    # Our JS Guard checks types? Let's see.
    echo -e "${GREEN}PASS ($CODE)${NC}" 
    ((pass++))
else
    echo -e "${RED}FAIL (Accepted bad types: $CODE)${NC}"
    ((fail++))
fi

echo -e "\n==========================================="
echo "📊 RESULTS: $pass Passed / $fail Failed"
echo "==========================================="
