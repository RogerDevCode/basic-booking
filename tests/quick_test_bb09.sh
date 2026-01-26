#!/bin/bash
# ============================================================================
# BB_09 Deep Link Redirect - Quick Test with Production URL
# ============================================================================

WEBHOOK_UUID="dea8ff90-a649-4652-87de-a3d136dc47be"
BASE_URL="https://n8n.stax.ink/webhook/${WEBHOOK_UUID}/agendar-v3"

echo "🧪 BB_09 Quick Test (Production URL)"
echo "==========================================="
echo "URL Base: $BASE_URL"
echo ""

# Test 1: Valid slug format (professional doesn't exist)
echo "📋 Test 1: Valid Slug (Non-existent Professional)"
echo "   Testing: /test-doctor"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$BASE_URL/test-doctor")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE")

echo "   HTTP Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "404" ]; then
  if echo "$BODY" | grep -q "<!DOCTYPE html>"; then
    echo "   ✅ PASS: HTML error page returned"
    if echo "$BODY" | grep -q "Profesional no encontrado"; then
      echo "   ✅ Correct Spanish error message"
    fi
  else
    echo "   ⚠️  WARNING: Non-HTML response"
  fi
elif [ "$HTTP_CODE" = "302" ]; then
  echo "   ⚠️  Unexpected redirect (professional shouldn't exist)"
else
  echo "   ❌ Unexpected HTTP $HTTP_CODE"
fi
echo ""

# Test 2: Invalid slug format (special characters)
echo "📋 Test 2: Invalid Slug Format (Special Characters)"
echo "   Testing: /dr@invalid#test"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$BASE_URL/dr@invalid%23test")
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE")

echo "   HTTP Code: $HTTP_CODE"
if [ "$HTTP_CODE" = "400" ]; then
  echo "   ✅ PASS: Paranoid Guard rejected invalid format"
  if echo "$BODY" | grep -q "INVALID_SLUG_FORMAT"; then
    echo "   ✅ Correct error message"
  fi
elif [ "$HTTP_CODE" = "404" ]; then
  echo "   ⚠️  WARNING: Should be 400 (input validation), not 404"
else
  echo "   ❌ Unexpected HTTP $HTTP_CODE"
fi
echo ""

# Test 3: Check if workflow has all nodes
echo "📋 Test 3: Workflow Completeness Check"
echo "   This test verifies if the workflow has all 15 nodes"
echo "   Manual verification required in n8n UI"
echo "   ⚠️  Please confirm in n8n that you see ALL nodes:"
echo "      1. GET /agendar-v3/:slug"
echo "      2. Paranoid Guard"
echo "      3. Validation OK?"
echo "      4. DB: Find Professional"
echo "      5. DB: Get Bot Username"
echo "      6. Merge Data"
echo "      7. Professional Found?"
echo "      8. Log: Success"
echo "      9. Redirect to Telegram"
echo "      10. Log: Not Found"
echo "      11. 404 Not Found"
echo "      12. Prepare Error Data"
echo "      13. Log: Validation Error"
echo "      14. Call BB_00 Error Handler"
echo "      15. 400 Bad Request"
echo ""

# Test 4: Database check
echo "📋 Test 4: Database Migration Status"
echo "   Checking if professionals table exists..."
if command -v psql &> /dev/null && [ -n "$DATABASE_URL" ]; then
  PROF_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM professionals WHERE deleted_at IS NULL" 2>/dev/null || echo "ERROR")
  if [ "$PROF_COUNT" = "ERROR" ]; then
    echo "   ❌ FAIL: professionals table doesn't exist"
    echo "   📌 Action: Run migration_bb09_professionals.sql"
  else
    echo "   ✅ PASS: professionals table exists"
    echo "   📊 Count: $PROF_COUNT professional(s) in DB"
  fi
else
  echo "   ⚠️  SKIP: DATABASE_URL not set or psql not available"
fi
echo ""

echo "==========================================="
echo "🏁 Quick Test Complete"
echo ""
echo "📝 Summary:"
echo "   Production URL: $BASE_URL/:slug"
echo ""
echo "🔧 Next Steps:"
echo "   1. If workflow is incomplete: Re-import full JSON"
echo "   2. If DB test fails: Run migration SQL"
echo "   3. If tests fail: Check n8n execution logs"
