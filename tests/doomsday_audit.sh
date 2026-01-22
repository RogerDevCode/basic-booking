#!/bin/bash

# ==============================================================================
# 🛡️ AUTOAGENDA DOOMSDAY AUDIT (GATEWAY & ORCHESTRATION)
# ==============================================================================
# Focus: Security, Stability, and Full Flow Orchestration (BB_01 -> BB_02 -> BB_03).

# CONFIG
URL_TG="https://n8n.stax.ink/webhook/telegram-webhook"
URL_AVAIL="https://n8n.stax.ink/webhook/availability-v2"
URL_BOOK="https://n8n.stax.ink/webhook/book-v2"
URL_DASH="https://n8n.stax.ink/webhook/api/config-v2"
DB_URL="postgresql://neondb_owner:npg_S4woXq3lxJjd@ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"

# COLORS
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# HELPER
log_pass() { echo -e "${GREEN}✅ PASS:${NC} $1"; }
log_fail() { echo -e "${RED}❌ FAIL:${NC} $1"; }
log_info() { echo -e "${BLUE}ℹ️ INFO:${NC} $1"; }

# DATA SEEDING
PRO_ID="2eebc9bc-c2f8-46f8-9e78-7da0909fcca4"
SRV_ID="a7a019cb-3442-4f57-8877-1b04a1749c01"
USER_ID="b9f03843-eee6-4607-ac5a-496c6faa9ea1"

echo "========================================"
echo "🔥 STARTING DOOMSDAY PROTOCOL (V3) 🔥"
echo "========================================"

# ------------------------------------------------------------------------------
# 1. BB_01 TELEGRAM GATEWAY (The Orchestrator)
# ------------------------------------------------------------------------------
echo -e "\n🔍 [1/5] Testing Telegram Gateway Orchestration (BB_01)..."

# Case 1.1: Full Orchestration Flow (/book)
# This test verifies if BB_01 correctly calls BB_02 (Firewall) and then BB_03 (Availability)
RESP=$(curl -s -w "\n%{http_code}" -X POST "$URL_TG" \
    -H "Content-Type: application/json" \
    -d "{ \"message\": { \"chat\": { \"id\": 5391760292 }, \"text\": \"/book\", \"from\": { \"first_name\": \"TestUser\" } } }")

BODY=$(echo "$RESP" | head -n 1)
CODE=$(echo "$RESP" | tail -n 1)

if [[ "$CODE" == "200" ]]; then
    if echo "$BODY" | grep -qiE "slots|available|denied"; then
        log_pass "Orchestration Success (Gateway responded with logic)"
        log_info "Response: $BODY"
    else
        log_fail "Orchestration Broken (Gateway responded but missing logic). Body: $BODY"
    fi
else
    log_fail "Gateway Failure (Code: $CODE). Body: $BODY"
fi


# ------------------------------------------------------------------------------
# 2. BB_03 AVAILABILITY ENGINE
# ------------------------------------------------------------------------------
echo -e "\n🔍 [2/5] Testing Availability Engine (BB_03)..."
RESP=$(curl -s -w "\n%{http_code}" -X POST "$URL_AVAIL" -H "Content-Type: application/json" -d "{ \"professional_id\": \"$PRO_ID\", \"service_id\": \"$SRV_ID\", \"date\": \"2026-02-10\" }")
CODE=$(echo "$RESP" | tail -n 1)
if [[ "$CODE" == "200" ]]; then log_pass "Engine Responsive"; else log_fail "Engine Failure (Code: $CODE)"; fi


# ------------------------------------------------------------------------------
# 3. BB_04 BOOKING TRANSACTION (Concurrency)
# ------------------------------------------------------------------------------
echo -e "\n🔍 [3/5] Testing Concurrency (BB_04)..."
TARGET_START="2026-05-05T10:00:00Z"
TARGET_END="2026-05-05T10:30:00Z"
psql "$DB_URL" -c "DELETE FROM public.bookings WHERE start_time = '$TARGET_START';" > /dev/null

echo "   ⚡ Launching 5 parallel booking requests..."
for i in {1..5}; do
    curl -s -X POST "$URL_BOOK" -H "Content-Type: application/json" -d "{
      \"professional_id\": \"$PRO_ID\", \"user_id\": \"$USER_ID\", \"service_id\": \"$SRV_ID\",
      \"start_time\": \"$TARGET_START\", \"end_time\": \"$TARGET_END\"
    }" &
done
wait

COUNT=$(psql "$DB_URL" -t -c "SELECT count(*) FROM public.bookings WHERE start_time = '$TARGET_START';")
COUNT=$(echo $COUNT | xargs)
if [[ "$COUNT" -eq 1 ]]; then log_pass "Race Condition Defeated"; else log_fail "Race Condition FAILED ($COUNT bookings)"; fi


# ------------------------------------------------------------------------------
# 4. BB_06 DASHBOARD (Security)
# ------------------------------------------------------------------------------
echo -e "\n🔍 [4/5] Testing Dashboard Security (BB_06)..."
RESP=$(curl -s -w "\n%{http_code}" -X POST "$URL_DASH" -H "Content-Type: application/json" -d '{"is_active": true}')
CODE=$(echo "$RESP" | tail -n 1)
if [[ "$CODE" == "401" ]]; then log_pass "Auth Enforced"; else log_fail "Auth Bypass (Code: $CODE)"; fi


# ------------------------------------------------------------------------------
# 5. SYSTEM SURVIVAL
# ------------------------------------------------------------------------------
echo -e "\n🔍 [5/5] System Integrity Check..."
TABLES=$(psql "$DB_URL" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('bookings', 'users', 'app_config');")
TABLES=$(echo $TABLES | xargs)
if [[ "$TABLES" -eq 3 ]]; then log_pass "Tables Intact"; else log_fail "Schema Loss ($TABLES/3)"; fi

echo "========================================"
echo "🏁 AUDIT COMPLETE"
echo "========================================"
