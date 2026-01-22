#!/bin/bash
#
# Test Script para BB_02 Security Firewall - Test Webhook
# Endpoint: /webhook/test/firewall
#

set -e

BASE_URL="${N8N_BASE_URL:-https://n8n.stax.ink}"
ENDPOINT="/webhook/test/firewall"

echo "═══════════════════════════════════════════════════════"
echo "  BB_02 Security Firewall - Test Suite"
echo "═══════════════════════════════════════════════════════"
echo ""

# Test 1: Valid Request - User with RUT
echo "📋 Test 1: Valid Request (User with RUT)"
echo "───────────────────────────────────────────────────────"
curl -X POST "${BASE_URL}${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "telegram_id": 5391760292,
      "rut": "12345678-9"
    },
    "routing": {
      "intent": "cmd_book",
      "target_date": "2026-01-21"
    }
  }' \
  -w "\n\nHTTP Status: %{http_code}\n" \
  -s | jq '.'
echo ""

# Test 2: Valid Request - User without RUT
echo "📋 Test 2: Valid Request (User without RUT)"
echo "───────────────────────────────────────────────────────"
curl -X POST "${BASE_URL}${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "telegram_id": 999888777
    },
    "routing": {
      "intent": "cmd_start"
    }
  }' \
  -w "\n\nHTTP Status: %{http_code}\n" \
  -s | jq '.'
echo ""

# Test 3: Invalid Request - Missing user object
echo "❌ Test 3: INVALID - Missing user object (Expected 400)"
echo "───────────────────────────────────────────────────────"
curl -X POST "${BASE_URL}${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{
    "routing": {
      "intent": "test"
    }
  }' \
  -w "\n\nHTTP Status: %{http_code}\n" \
  -s | jq '.'
echo ""

# Test 4: Invalid Request - Empty telegram_id
echo "❌ Test 4: INVALID - Empty telegram_id (Expected 400)"
echo "───────────────────────────────────────────────────────"
curl -X POST "${BASE_URL}${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "telegram_id": ""
    },
    "routing": {
      "intent": "test"
    }
  }' \
  -w "\n\nHTTP Status: %{http_code}\n" \
  -s | jq '.'
echo ""

# Test 5: Invalid Request - Negative telegram_id
echo "❌ Test 5: INVALID - Negative telegram_id (Expected 400)"
echo "───────────────────────────────────────────────────────"
curl -X POST "${BASE_URL}${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "telegram_id": -123
    },
    "routing": {
      "intent": "test"
    }
  }' \
  -w "\n\nHTTP Status: %{http_code}\n" \
  -s | jq '.'
echo ""

# Test 6: Invalid Request - Invalid RUT format
echo "❌ Test 6: INVALID - Invalid RUT format (Expected 400)"
echo "───────────────────────────────────────────────────────"
curl -X POST "${BASE_URL}${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "telegram_id": 123456789,
      "rut": "invalid-rut"
    },
    "routing": {
      "intent": "test"
    }
  }' \
  -w "\n\nHTTP Status: %{http_code}\n" \
  -s | jq '.'
echo ""

# Test 7: Valid Request - Type coercion test
echo "📋 Test 7: Type Coercion - String telegram_id (should normalize)"
echo "───────────────────────────────────────────────────────"
curl -X POST "${BASE_URL}${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "telegram_id": "5391760292"
    },
    "routing": {
      "intent": "coercion_test"
    }
  }' \
  -w "\n\nHTTP Status: %{http_code}\n" \
  -s | jq '.'
echo ""

echo "═══════════════════════════════════════════════════════"
echo "  Test Suite Completed"
echo "═══════════════════════════════════════════════════════"
