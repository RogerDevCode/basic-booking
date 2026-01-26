#!/bin/bash
# ============================================================================
# BB_09 Deep Link Redirect - Comprehensive Test Suite v2
# ============================================================================
# Extended tests: DB check, workflow status, all edge cases
# ============================================================================

set -e

BASE_URL="${N8N_URL:-https://n8n.stax.ink}"
ENDPOINT="/webhook/agendar-v3"

echo "🧪 BB_09 Comprehensive Test Suite"
echo "=========================================="
echo "Base URL: $BASE_URL"
echo "Endpoint: $ENDPOINT"
echo ""

# ============================================================================
# Test Suite 1: Infrastructure Checks
# ============================================================================
echo "📊 SUITE 1: Infrastructure Validation"
echo "----------------------------------------"

# Test 1.1: Webhook Endpoint Accessibility
echo "🔍 Test 1.1: Webhook Endpoint Status"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/webhook-test/ping" || echo "000")
if [ "$RESPONSE" = "404" ] || [ "$RESPONSE" = "401" ]; then
  echo "   ✅ n8n server reachable (HTTP $RESPONSE)"
else
  echo "   ⚠️  Unexpected response: HTTP $RESPONSE"
fi
echo ""

# Test 1.2: BB_09 Specific Endpoint
echo "🔍 Test 1.2: BB_09 V3 Endpoint Registered"
RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}${ENDPOINT}/health-check" 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "404" ]; then
  echo "   ❌ CRITICAL: BB_09 workflow NOT ACTIVE or NOT IMPORTED"
  echo "   📌 Action Required: Import and activate BB_09 in n8n UI"
elif [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ Workflow is active (Paranoid Guard rejected invalid slug)"
elif [ "$HTTP_CODE" = "302" ]; then
  echo "   ⚠️  Unexpected redirect (check workflow logic)"
else
  echo "   ℹ️  Response: HTTP $HTTP_CODE"
fi
echo ""

# ============================================================================
# Test Suite 2: Valid Professional Scenarios
# ============================================================================
echo "📊 SUITE 2: Valid Professional Tests"
echo "----------------------------------------"

# Test 2.1: Known professional (dr-smith from migration seed)
echo "🔍 Test 2.1: Seeded Professional (dr-smith)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{redirect_url}" \
  "${BASE_URL}${ENDPOINT}/dr-smith")

HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
REDIRECT_URL=$(echo "$RESPONSE" | cut -d'|' -f2)

if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
  echo "   ✅ PASS: HTTP $HTTP_CODE (Redirect)"
  echo "   📍 Target: $REDIRECT_URL"
  
  # Validate Telegram URL structure
  if [[ "$REDIRECT_URL" =~ ^https://t\.me/[a-zA-Z0-9_]+\?start=[a-z0-9-]+$ ]]; then
    echo "   ✅ Valid Telegram deep link format"
  else
    echo "   ⚠️  WARNING: Malformed Telegram URL"
  fi
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ❌ FAIL: Professional not found (check DB migration)"
  echo "   📌 Action: Run migration_bb09_professionals.sql"
elif [ "$HTTP_CODE" = "400" ]; then
  echo "   ❌ FAIL: Paranoid Guard rejected valid slug"
else
  echo "   ❌ FAIL: Unexpected HTTP $HTTP_CODE"
fi
echo ""

# Test 2.2: Case sensitivity (should normalize to lowercase)
echo "🔍 Test 2.2: Case Normalization (DR-SMITH -> dr-smith)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}${ENDPOINT}/DR-SMITH")

HTTP_CODE=$RESPONSE

if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
  echo "   ✅ PASS: Uppercase normalized correctly"
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ⚠️  WARNING: Case normalization may not be working"
elif [ "$HTTP_CODE" = "400" ]; then
  echo "   ❌ FAIL: Paranoid Guard too strict on case"
else
  echo "   ℹ️  HTTP $HTTP_CODE"
fi
echo ""

# ============================================================================
# Test Suite 3: Security & Validation
# ============================================================================
echo "📊 SUITE 3: Security Tests"
echo "----------------------------------------"

# Test 3.1: SQL Injection
echo "🔍 Test 3.1: SQL Injection Protection"
PAYLOAD="' OR '1'='1' --"
ENCODED=$(printf '%s' "$PAYLOAD" | jq -sRr @uri)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}${ENDPOINT}/${ENCODED}")

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: SQLi attempt rejected (HTTP $HTTP_CODE)"
else
  echo "   🚨 CRITICAL: Potential SQL injection vulnerability!"
  echo "   📌 Response: HTTP $HTTP_CODE"
fi
echo ""

# Test 3.2: XSS via slug
echo "🔍 Test 3.2: XSS Protection"
XSS="<script>alert('xss')</script>"
ENCODED_XSS=$(printf '%s' "$XSS" | jq -sRr @uri)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}${ENDPOINT}/${ENCODED_XSS}")

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: XSS payload rejected (HTTP $HTTP_CODE)"
else
  echo "   ⚠️  WARNING: XSS may not be filtered properly"
fi
echo ""

# Test 3.3: Path traversal
echo "🔍 Test 3.3: Path Traversal Protection"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}${ENDPOINT}/../../../etc/passwd")

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: Path traversal blocked (HTTP $HTTP_CODE)"
else
  echo "   ⚠️  WARNING: Path traversal not properly blocked"
fi
echo ""

# Test 3.4: Excessive length
echo "🔍 Test 3.4: Length Limit Enforcement (>50 chars)"
LONG_SLUG=$(printf 'a%.0s' {1..100})
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}${ENDPOINT}/${LONG_SLUG}")

if [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: Long slug rejected (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ⚠️  Length check may be missing (404 instead of 400)"
else
  echo "   ℹ️  HTTP $HTTP_CODE"
fi
echo ""

# Test 3.5: Special characters
echo "🔍 Test 3.5: Special Character Rejection"
SPECIAL="dr@smith#test"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}${ENDPOINT}/${SPECIAL}")

if [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: Special chars rejected by Paranoid Guard"
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ⚠️  Special chars rejected by DB lookup (should be 400)"
else
  echo "   ℹ️  HTTP $HTTP_CODE"
fi
echo ""

# ============================================================================
# Test Suite 4: Error Handling
# ============================================================================
echo "📊 SUITE 4: Error Handling"
echo "----------------------------------------"

# Test 4.1: Non-existent professional
echo "🔍 Test 4.1: 404 HTML Error Page"
RESPONSE=$(curl -s -w "\n%{http_code}" \
  "${BASE_URL}${ENDPOINT}/nonexistent-doctor-xyz")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "404" ]; then
  echo "   ✅ PASS: HTTP 404 returned"
  
  # Check for HTML content
  if echo "$BODY" | grep -q "<!DOCTYPE html>"; then
    echo "   ✅ HTML error page served"
  else
    echo "   ⚠️  Non-HTML response (expected HTML error page)"
  fi
  
  # Check for custom error message
  if echo "$BODY" | grep -qi "no encontrado\|not found"; then
    echo "   ✅ Custom error message present"
  else
    echo "   ⚠️  Generic error message"
  fi
else
  echo "   ❌ FAIL: Expected 404, got HTTP $HTTP_CODE"
fi
echo ""

# Test 4.2: Empty slug
echo "🔍 Test 4.2: Empty Slug Handling"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  "${BASE_URL}${ENDPOINT}/")

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "404" ]; then
  echo "   ✅ PASS: Empty slug rejected (HTTP $HTTP_CODE)"
else
  echo "   ⚠️  Unexpected response: HTTP $HTTP_CODE"
fi
echo ""

# ============================================================================
# FINAL REPORT
# ============================================================================
echo "=========================================="
echo "🏁 Test Suite Complete"
echo ""
echo "📊 Summary:"
echo "   - Suite 1: Infrastructure checks"
echo "   - Suite 2: Valid professional tests"
echo "   - Suite 3: Security validation (5 tests)"
echo "   - Suite 4: Error handling (2 tests)"
echo ""
echo "🔧 Next Steps:"
echo "   1. If BB_09 not active: Import workflow in n8n UI"
echo "   2. If dr-smith not found: Run database migration"
echo "   3. Review any ⚠️  warnings above"
echo "   4. Check audit_logs for logged events"
echo ""
echo "📝 Database Verification:"
echo "   psql \$DATABASE_URL -c \"SELECT slug, name FROM professionals WHERE deleted_at IS NULL;\""
echo "   psql \$DATABASE_URL -c \"SELECT config_value FROM app_config WHERE config_key = 'TELEGRAM_BOT_USERNAME';\""
