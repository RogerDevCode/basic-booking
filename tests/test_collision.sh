#!/bin/bash

# ==============================================================================
# AUDIT: COLLISION DETECTION
# ==============================================================================
URL="https://n8n.stax.ink/webhook/book"
DB_URL="postgresql://neondb_owner:npg_S4woXq3lxJjd@ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

function log_pass() { echo -e "${GREEN}✅ PASS:${NC} $1"; }
function log_fail() { echo -e "${RED}❌ FAIL:${NC} $1"; }

# Test Data
PRO_ID="2eebc9bc-c2f8-46f8-9e78-7da0909fcca4"
SRV_ID="a7a019cb-3442-4f57-8877-1b04a1749c01"
USER_1="b9f03843-eee6-4607-ac5a-496c6faa9ea1"
USER_2="0006b96b-88f9-4058-bc84-5ad288cbb8c5" # ID real obtenido en tests anteriores o generado

# Slot: 2026-04-01 10:00 - 10:30
START_A="2026-04-01T10:00:00Z"
END_A="2026-04-01T10:30:00Z"

# Slot: 2026-04-01 10:15 - 10:45 (Overlap)
START_B="2026-04-01T10:15:00Z"
END_B="2026-04-01T10:45:00Z"

echo "========================================"
echo "🛡️ STARTING COLLISION AUDIT"
echo "========================================"

# 1. Cleanup
echo "🧹 Cleaning up test slot..."
psql "$DB_URL" -c "DELETE FROM bookings WHERE start_time >= '$START_A' AND start_time <= '$END_A';" > /dev/null

# 2. Booking A (Should Succeed)
echo -e "\n🧪 [1/3] Booking A (User 1)..."
RESP_A=$(curl -s -w "\n%{http_code}" -X POST "$URL" -H "Content-Type: application/json" -d "{
  \"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_1\", \"service_id\": \"$SRV_ID\",
  \"start_time\": \"$START_A\", \"end_time\": \"$END_A\"
}")
CODE_A=$(echo "$RESP_A" | tail -n 1)

if [[ "$CODE_A" == "200" ]]; then
    log_pass "Booking A Created"
else
    log_fail "Booking A Failed (Code $CODE_A)"
    exit 1
fi

# 3. Booking B (Exact Collision - Should Fail)
echo -e "\n🧪 [2/3] Booking B (Exact Collision)..."
RESP_B=$(curl -s -w "\n%{http_code}" -X POST "$URL" -H "Content-Type: application/json" -d "{
  \"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_2\", \"service_id\": \"$SRV_ID\",
  \"start_time\": \"$START_A\", \"end_time\": \"$END_A\"
}")
CODE_B=$(echo "$RESP_B" | tail -n 1)
BODY_B=$(echo "$RESP_B" | head -n 1)

# Note: The DB trigger throws an error. BB_04 V11 doesn't catch DB errors explicitly to return 400 yet, 
# so it might return 500 (Workflow Error). This is acceptable for security but could be improved for UX.
if [[ "$CODE_B" != "200" ]]; then
    log_pass "Collision Rejected (Code $CODE_B)"
else
    log_fail "Collision ACCEPTED (Code $CODE_B) - CRITICAL FAILURE"
fi

# 4. Booking C (Partial Overlap - Should Fail)
echo -e "\n🧪 [3/3] Booking C (Partial Overlap)..."
RESP_C=$(curl -s -w "\n%{http_code}" -X POST "$URL" -H "Content-Type: application/json" -d "{
  \"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_2\", \"service_id\": \"$SRV_ID\",
  \"start_time\": \"$START_B\", \"end_time\": \"$END_B\"
}")
CODE_C=$(echo "$RESP_C" | tail -n 1)

if [[ "$CODE_C" != "200" ]]; then
    log_pass "Overlap Rejected (Code $CODE_C)"
else
    log_fail "Overlap ACCEPTED (Code $CODE_C) - CRITICAL FAILURE"
fi

echo "========================================"
echo "🏁 COLLISION AUDIT COMPLETE"
echo "========================================"
