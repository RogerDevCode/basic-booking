#!/bin/bash
# ============================================================================
# BB_09 Deep Link Redirect - Verification Script
# ============================================================================
# Tests: Valid slug, Invalid slug, SQL Injection attempt
# Expected: 302 Redirect for valid, 404 for invalid, Safe handling of SQLi
# ============================================================================

BASE_URL="${N8N_URL:-https://n8n.stax.ink}"
ENDPOINT="/webhook/agendar-v3"

echo "🔍 BB_09 Deep Link Redirect Verification (V3)"
echo "=========================================="
echo ""

# ============================================================================
# Test 1: Valid Professional Slug (Happy Path)
# ============================================================================
echo "📋 Test 1: Valid Slug Redirect"
echo "   Testing: GET /agendar-v3/dr-smith"

RESPONSE=$(curl -s -o /dev/null -w "%{http_code}|%{redirect_url}" \
  "${BASE_URL}${ENDPOINT}/dr-smith")

HTTP_CODE=$(echo "$RESPONSE" | cut -d'|' -f1)
REDIRECT_URL=$(echo "$RESPONSE" | cut -d'|' -f2)

if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "301" ]; then
  echo "   ✅ PASS: HTTP $HTTP_CODE (Redirect)"
  echo "   📍 Redirect URL: $REDIRECT_URL"
  if [[ "$REDIRECT_URL" == *"t.me/setcalendarbot"* ]]; then
    echo "   ✅ Correct Telegram Deep Link"
  else
    echo "   ⚠️  WARNING: Unexpected redirect URL"
  fi
else
  echo "   ❌ FAIL: Expected 302, got HTTP $HTTP_CODE"
fi
echo ""

# ============================================================================
# Test 2: Non-existent Professional (404 Handling)
# ============================================================================
echo "📋 Test 2: Invalid Slug (404 Test)"
echo "   Testing: GET /agendar-v3/nonexistent-doctor-99999"

RESPONSE=$(curl -s -w "\n%{http_code}" \
  "${BASE_URL}${ENDPOINT}/nonexistent-doctor-99999")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "404" ]; then
  echo "   ✅ PASS: HTTP 404 (Not Found)"
  if [[ "$BODY" == *"Doctor no encontrado"* ]]; then
    echo "   ✅ Correct error message displayed"
  else
    echo "   ⚠️  WARNING: Unexpected error message"
  fi
else
  echo "   ❌ FAIL: Expected 404, got HTTP $HTTP_CODE"
fi
echo ""

# ============================================================================
# Test 3: SQL Injection Protection (Security Test)
# ============================================================================
echo "📋 Test 3: SQL Injection Attempt"
echo "   Testing: Malicious payload in slug parameter"

# URL-encode the SQL injection payload
PAYLOAD="' OR '1'='1' -- "
ENCODED_PAYLOAD=$(echo "$PAYLOAD" | jq -sRr @uri)

RESPONSE=$(curl -s -w "\n%{http_code}" \
  "${BASE_URL}${ENDPOINT}/${ENCODED_PAYLOAD}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: HTTP $HTTP_CODE (Attack rejected)"
else
  echo "   ⚠️  CRITICAL: Potential SQL Injection vulnerability"
  echo "   ❌ HTTP $HTTP_CODE with response:"
  echo "$BODY" | head -20
fi
echo ""

# ============================================================================
# Test 4: Special Characters Handling
# ============================================================================
echo "📋 Test 4: Special Characters Validation"
echo "   Testing: Slug with XSS attempt"

XSS_PAYLOAD="<script>alert('XSS')</script>"
ENCODED_XSS=$(echo "$XSS_PAYLOAD" | jq -sRr @uri)

RESPONSE=$(curl -s -w "\n%{http_code}" \
  "${BASE_URL}${ENDPOINT}/${ENCODED_XSS}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "404" ] || [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: HTTP $HTTP_CODE (XSS rejected)"
else
  echo "   ⚠️  WARNING: XSS payload not properly sanitized"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=========================================="
echo "🏁 Verification Complete"
echo ""
echo "📝 Notes:"
echo "   - Valid slugs should redirect to Telegram (302)"
echo "   - Invalid slugs should return 404 with HTML message"
echo "   - SQL Injection and XSS should be rejected (400/404)"
echo ""
echo "⚠️  Known Issues (as of current architecture):"
echo "   1. SQL query uses direct interpolation (SQLi risk)"
echo "   2. No input validation guard at entry point"
echo "   3. No logging to audit_logs or BB_00 error handler"
echo "   4. Hardcoded bot username (should use app_config)"
echo "   5. No V3 endpoint versioning"
