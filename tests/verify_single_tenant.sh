#!/bin/bash
# ============================================================================
# Single-Tenant Migration Verification Script
# ============================================================================
# Purpose: Verify that multi-tenant to single-tenant migration completed
#          successfully.
#
# Usage: bash tests/verify_single_tenant.sh
# ============================================================================

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

# Check if DB_URL is set
if [ -z "$DATABASE_URL" ]; then
    echo -e "${RED}❌ DATABASE_URL not set in .env${NC}"
    exit 1
fi

DB_URL="$DATABASE_URL"

echo "============================================"
echo "🔍 Verifying Single-Tenant Migration"
echo "============================================"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Test 1: Verify tenants table is dropped
# ============================================================================
echo -n "Test 1: Tenants table removed... "
if psql "$DB_URL" -tAc "SELECT 1 FROM tenants LIMIT 1" 2>&1 | grep -q "does not exist"; then
    echo -e "${GREEN}✅ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Tenants table still exists${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 2: Verify no tenant_id columns remain
# ============================================================================
echo -n "Test 2: No tenant_id columns... "
TENANT_COLS=$(psql "$DB_URL" -tAc "
    SELECT COUNT(*) 
    FROM information_schema.columns 
    WHERE column_name = 'tenant_id' 
    AND table_schema = 'public'
")

if [ "$TENANT_COLS" -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Found $TENANT_COLS tenant_id columns${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 3: Verify get_config() function works without tenant_id
# ============================================================================
echo -n "Test 3: get_config() function... "
SLOT_DURATION=$(psql "$DB_URL" -tAc "SELECT get_config('SLOT_DURATION_MINS', '30')")

if [ ! -z "$SLOT_DURATION" ]; then
    echo -e "${GREEN}✅ PASS${NC} (value: $SLOT_DURATION)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Function returned empty${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 4: Verify get_message() function works without tenant_id
# ============================================================================
echo -n "Test 4: get_message() function... "
MSG=$(psql "$DB_URL" -tAc "SELECT get_message('ERR_INVALID_PRO', 'es')")

if echo "$MSG" | grep -q "inválido"; then
    echo -e "${GREEN}✅ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Message not found or incorrect${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 5: Verify get_config_json() function exists and works
# ============================================================================
echo -n "Test 5: get_config_json() function... "
CONFIG_JSON=$(psql "$DB_URL" -tAc "SELECT get_config_json()")

if [ ! -z "$CONFIG_JSON" ] && echo "$CONFIG_JSON" | grep -q "SLOT_DURATION_MINS"; then
    echo -e "${GREEN}✅ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Function failed or incomplete${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 6: Verify get_tenant_config_json() is removed
# ============================================================================
echo -n "Test 6: Old get_tenant_config_json() removed... "
if psql "$DB_URL" -tAc "SELECT get_tenant_config_json('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')" 2>&1 | grep -q "does not exist"; then
    echo -e "${GREEN}✅ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠️  WARNING - Old function still exists${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 7: Verify app_config unique constraint (key only)
# ============================================================================
echo -n "Test 7: app_config unique constraint... "
CONSTRAINT=$(psql "$DB_URL" -tAc "
    SELECT constraint_name 
    FROM information_schema.table_constraints 
    WHERE table_name = 'app_config' 
    AND constraint_type = 'UNIQUE'
    AND constraint_name = 'app_config_key_unique'
")

if [ ! -z "$CONSTRAINT" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Unique constraint missing${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 8: Verify app_messages unique constraint (code, lang)
# ============================================================================
echo -n "Test 8: app_messages unique constraint... "
CONSTRAINT=$(psql "$DB_URL" -tAc "
    SELECT constraint_name 
    FROM information_schema.table_constraints 
    WHERE table_name = 'app_messages' 
    AND constraint_type = 'UNIQUE'
    AND constraint_name = 'app_messages_code_lang_unique'
")

if [ ! -z "$CONSTRAINT" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Unique constraint missing${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 9: Verify no foreign keys to tenants table
# ============================================================================
echo -n "Test 9: No FKs to tenants table... "
FK_COUNT=$(psql "$DB_URL" -tAc "
    SELECT COUNT(*) 
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
        ON tc.constraint_name = ccu.constraint_name
    WHERE ccu.table_name = 'tenants' 
    AND tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public'
")

if [ "$FK_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Found $FK_COUNT foreign keys to tenants${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Test 10: Verify data integrity (records still exist)
# ============================================================================
echo -n "Test 10: Data integrity check... "
USER_COUNT=$(psql "$DB_URL" -tAc "SELECT COUNT(*) FROM users WHERE deleted_at IS NULL")
PROF_COUNT=$(psql "$DB_URL" -tAc "SELECT COUNT(*) FROM professionals WHERE deleted_at IS NULL")
CONFIG_COUNT=$(psql "$DB_URL" -tAc "SELECT COUNT(*) FROM app_config")

if [ "$USER_COUNT" -gt 0 ] && [ "$PROF_COUNT" -gt 0 ] && [ "$CONFIG_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ PASS${NC} (Users: $USER_COUNT, Professionals: $PROF_COUNT, Configs: $CONFIG_COUNT)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL - Data missing${NC}"
    echo "  Users: $USER_COUNT, Professionals: $PROF_COUNT, Configs: $CONFIG_COUNT"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================"
echo "📊 Test Results"
echo "============================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎯 All tests passed! Migration successful!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed. Please review the output above.${NC}"
    exit 1
fi
