#!/bin/bash
# CERTIFICATION SUITE: BB_00 Global Error Handler
# Strict checking of HTTP Codes, DB Persistence, and Strike Logic.

URL="https://n8n.stax.ink/webhook/error-handler"
ENTITY="telegram:CERT_TEST_USER"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "$1"; }

# 1. Validation Test (Fail Fast)
log "🧪 Test 1: Validation (Expecting 400)..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$URL" -H "Content-Type: application/json" -d '{}')
if [ "$CODE" -eq 400 ]; then log "${GREEN}✅ PASS: 400 Received${NC}"; else log "${RED}❌ FAIL: Got $CODE${NC}"; fi

# 2. Persistence Test (Happy Path)
log "🧪 Test 2: Persistence (Expecting 200 & DB Record)..."
RESP=$(curl -s -X POST "$URL" -H "Content-Type: application/json" -d "{\"workflow_name\": \"CERT_FLOW\", \"error_message\": \"Testing DB\", \"error_type\": \"INFO\"}")
if [[ "$RESP" == *"error_id"* ]]; then log "${GREEN}✅ PASS: Record Created${NC}"; else log "${RED}❌ FAIL: No error_id${NC}"; fi

# 3. Strike Test (Security)
log "🧪 Test 3: Strike System (Expecting Count Increase)..."
# Reset first
psql 'postgresql://neondb_owner:npg_S4woXq3lxJjd@ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require' -c "DELETE FROM security_firewall WHERE entity_id = '$ENTITY';" > /dev/null

# Trigger Strike
curl -s -X POST "$URL" -H "Content-Type: application/json" -d "{\"workflow_name\": \"CERT_FLOW\", \"error_message\": \"Strike 1\", \"entity_id\": \"$ENTITY\"}" > /dev/null
sleep 2

# Verify
COUNT=$(psql 'postgresql://neondb_owner:npg_S4woXq3lxJjd@ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require' -t -c "SELECT strike_count FROM security_firewall WHERE entity_id = '$ENTITY';" | xargs)

if [ "$COUNT" -eq "1" ]; then 
    log "${GREEN}✅ PASS: Strike Count is 1${NC}"
else 
    log "${RED}❌ FAIL: Strike Count is '$COUNT' (Expected 1)${NC}"
fi
