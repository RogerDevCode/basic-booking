#!/bin/bash
# ============================================================================
# BB_09 Deep Link - Full Test Suite (Production)
# ============================================================================

WEBHOOK_UUID="f8f94fd2-604e-4c52-9be0-2f2bbee48010"
BASE_URL="https://n8n.stax.ink/webhook/${WEBHOOK_UUID}/agendar-v3"

echo "🧪 BB_09 Full Test Suite"
echo "=========================================="
echo "Webhook UUID: $WEBHOOK_UUID"
echo "Base URL: $BASE_URL"
echo ""

# Test 1: Existing professional (dr-roger-auto from DB)
echo "📋 Test 1: Existing Professional (dr-roger-auto)"
RESPONSE=$(curl -s -w "\nHTTP:%{http_code}|REDIRECT:%{redirect_url}" "$BASE_URL/dr-roger-auto")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP:" | cut -d: -f2 | cut -d'|' -f1)
REDIRECT=$(echo "$RESPONSE" | grep "REDIRECT:" | cut -d: -f2-)
BODY=$(echo "$RESPONSE" | grep -v "HTTP:\|REDIRECT:")

echo "   HTTP Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "302" ]; then
  echo "   ✅ PASS: Redirect successful"
  echo "   🔗 Redirect: $REDIRECT"
  
  if echo "$REDIRECT" | grep -q "t.me.*start=dr-roger-auto"; then
    echo "   ✅ Valid Telegram deep link"
  fi
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ⚠️  404: Professional not found (check DB migration)"
  if echo "$BODY" | grep -q "<!DOCTYPE html>"; then
    echo "   ✅ HTML error page served"
  fi
else
  echo "   ❌ Unexpected: HTTP $HTTP_CODE"
  echo "$BODY" | head -10
fi
echo ""

# Test 2: Non-existent professional
echo "📋 Test 2: Non-Existent Professional (test-doctor)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/test-doctor")
echo "   HTTP Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "404" ]; then
  echo "   ✅ PASS: 404 returned for non-existent professional"
else
  echo "   ❌ Expected 404, got $HTTP_CODE"
fi
echo ""

# Test 3: Invalid slug format
echo "📋 Test 3: Invalid Slug (special characters)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/dr@invalid%23test")
echo "   HTTP Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: Paranoid Guard rejected invalid format"
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ⚠️  Should be 400 (validation error), not 404"
else
  echo "   ❌ Unexpected: HTTP $HTTP_CODE"
fi
echo ""

# Test 4: Test dr-smith if exists
echo "📋 Test 4: Test Professional (dr-smith - if migrated)"
RESPONSE=$(curl -s -w "\nHTTP:%{http_code}" "$BASE_URL/dr-smith")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP:" | cut -d: -f2)
echo "   HTTP Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "302" ]; then
  echo "   ✅ Migration successful: dr-smith found"
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ⚠️  dr-smith not found (migration not run)"
fi
echo ""

# Test 5: Case normalization
echo "📋 Test 5: Case Normalization (DR-ROGER-AUTO)"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/DR-ROGER-AUTO")
echo "   HTTP Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "302" ]; then
  echo "   ✅ PASS: Uppercase normalized to lowercase"
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ⚠️  Case normalization may not be working"
fi
echo ""

echo "=========================================="
echo "🏁 Test Suite Complete"
echo ""
echo "📊 Summary:"
echo "   Base URL: $BASE_URL/:slug"
echo ""
echo "🔧 Next Steps:"
echo "   - If Test 1 fails: Check workflow is active in n8n"
echo "   - If Test 4 fails: Run migration SQL in n8n"
echo "   - Check n8n execution logs for detailed errors"
