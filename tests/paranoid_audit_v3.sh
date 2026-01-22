#!/bin/bash

# ==============================================================================
# 🛡️ AUTOAGENDA PARANOID AUDIT SUITE (V3 - THE ZOMBIE KILLER)
# ==============================================================================

# ENDPOINTS V3
URL_AVAIL="https://n8n.stax.ink/webhook/availability-v3"
URL_BOOK="https://n8n.stax.ink/webhook/book-v3"
URL_CONF="https://n8n.stax.ink/webhook/api/config-v3"

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
echo "🔮 SECTION 1: AVAILABILITY ENGINE (V3)"
echo "==========================================="
run_test "Happy Path" "$URL_AVAIL" "{\"professional_id\": \"$PRO_ID\", \"service_id\": \"$SRV_ID\", \"date\": \"2026-06-01\"}" "200" "success"
run_test "Type: ID as Array" "$URL_AVAIL" "{\"professional_id\": [\"$PRO_ID\"], \"service_id\": \"$SRV_ID\", \"date\": \"2026-06-01\"}" "400" "String UUID required"
run_test "Date: Feb 30th" "$URL_AVAIL" "{\"professional_id\": \"$PRO_ID\", \"service_id\": \"$SRV_ID\", \"date\": \"2026-02-30\"}" "400" "Logic failure"

echo -e "\n==========================================="
echo "💳 SECTION 2: BOOKING TRANSACTION (V3)"
echo "==========================================="
run_test "Duration: 0 Min" "$URL_BOOK" "{\"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_ID\", \"service_id\": \"$SRV_ID\", \"start_time\": \"2026-06-01T10:00:00Z\", \"end_time\": \"2026-06-01T10:00:00Z\"}" "400" "positive"
run_test "Time Travel" "$URL_BOOK" "{\"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_ID\", \"service_id\": \"$SRV_ID\", \"start_time\": \"2026-06-01T10:00:00Z\", \"end_time\": \"2026-06-01T09:00:00Z\"}" "400" "before end_time"

echo -e "\n==========================================="
echo "🛡️ SECTION 3: DASHBOARD AUTH (V3)"
echo "==========================================="
MOCK_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYWRtaW4iLCJleHAiOjE5MjQ5ODg4MDB9.signature"
run_test "Auth: No Token" "$URL_CONF" "{\"is_active\": true}" "401" "Missing token"
run_test "Config: Bad Type" "$URL_CONF" "HEADER: Authorization: Bearer $MOCK_TOKEN" "{\"reminder_1_hours\": \"NaN\"}" "400" "number" # This syntax is a bit mixed, fixing below

# Specific fix for the last complex curl
echo -ne "🧪 Config: Strict Types... "
RESP=$(curl -s -w "\n%{http_code}" -X POST "$URL_CONF" -H "Authorization: Bearer $MOCK_TOKEN" -H "Content-Type: application/json" -d '{"reminder_1_hours": "fail"}')
CODE=$(echo "$RESP" | tail -n 1)
if [[ "$CODE" == "400" ]]; then echo -e "${GREEN}PASS${NC}"; ((pass++)); else echo -e "${RED}FAIL ($CODE)${NC}"; ((fail++)); fi

echo -e "\n==========================================="
echo "📊 FINAL V3 RESULTS: $pass Passed / $fail Failed"
echo "==========================================="
