#!/bin/bash

# ============================================================================
# SCRIPT: Find Active Webhook Path
# PURPOSE: Discover the actual webhook path registered in n8n
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "============================================================================"
echo "🔍 WEBHOOK PATH DISCOVERY"
echo "============================================================================"
echo ""

echo -e "${BLUE}Testing common webhook paths...${NC}"
echo ""

# Array of common paths
PATHS=(
    "error-handler"
    "webhook-test"
    "webhook"
    "test"
    "global-error-handler"
    "bb-00"
    "BB_00_Global_Error_Handler"
)

FOUND_PATH=""

for path in "${PATHS[@]}"; do
    echo -n "Testing: /webhook/$path ... "
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "http://localhost:5678/webhook/$path" \
        -H "Content-Type: application/json" \
        -d '{"test":"ping"}' 2>&1)
    
    if [ "$RESPONSE" == "500" ] || [ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "201" ]; then
        echo -e "${GREEN}✅ FOUND! (HTTP $RESPONSE)${NC}"
        FOUND_PATH="$path"
        break
    else
        echo -e "${RED}❌ Not found (HTTP $RESPONSE)${NC}"
    fi
done

echo ""
echo "============================================================================"

if [ -n "$FOUND_PATH" ]; then
    echo -e "${GREEN}✅ SUCCESS: Webhook path discovered!${NC}"
    echo ""
    echo "   Production URL: http://localhost:5678/webhook/$FOUND_PATH"
    echo ""
    echo "   Update your test scripts to use this path."
    echo ""
    
    # Update diagnose_webhook.sh
    if [ -f "./tests/diagnose_webhook.sh" ]; then
        echo -e "${YELLOW}Updating diagnose_webhook.sh...${NC}"
        sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=\"http://localhost:5678/webhook/$FOUND_PATH\"|" ./tests/diagnose_webhook.sh
        echo -e "${GREEN}✅ Updated!${NC}"
    fi
    
    # Update test_error_handler.sh
    if [ -f "./tests/test_error_handler.sh" ]; then
        echo -e "${YELLOW}Updating test_error_handler.sh...${NC}"
        sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=\"http://localhost:5678/webhook/$FOUND_PATH\"|" ./tests/test_error_handler.sh
        echo -e "${GREEN}✅ Updated!${NC}"
    fi
    
    echo ""
    echo "   Now run: ./tests/diagnose_webhook.sh"
else
    echo -e "${RED}❌ FAILED: No active webhook found${NC}"
    echo ""
    echo "   Possible causes:"
    echo "   1. Workflow is not activated in n8n"
    echo "   2. Webhook path is different from common patterns"
    echo ""
    echo "   MANUAL CHECK REQUIRED:"
    echo "   1. Open n8n UI: http://localhost:5678"
    echo "   2. Open workflow: BB_00_Global_Error_Handler"
    echo "   3. Click on 'Webhook Trigger' node"
    echo "   4. Look for 'Production URL' in the right panel"
    echo "   5. Copy the path after '/webhook/'"
    echo ""
fi

echo "============================================================================"
