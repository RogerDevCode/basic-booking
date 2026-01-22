#!/bin/bash

# ============================================================================
# SCRIPT: Import All AutoAgenda Workflows to n8n
# PURPOSE: Batch import all workflow JSON files into n8n instance
# AUTHOR: AutoAgenda Architect
# DATE: 2026-01-15
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

WORKFLOWS_DIR="./workflows"
N8N_URL="http://localhost:5678"

echo "============================================================================"
echo "📦 AUTOAGENDA WORKFLOW IMPORTER"
echo "============================================================================"
echo ""

# ============================================================================
# STEP 1: Check if n8n is running
# ============================================================================

echo -e "${BLUE}STEP 1: Checking n8n service${NC}"
if ! docker ps | grep -q "n8n"; then
    echo -e "${RED}❌ n8n container is NOT running${NC}"
    echo "   Run: docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✅ n8n is running${NC}"
echo ""

# ============================================================================
# STEP 2: List available workflow files
# ============================================================================

echo -e "${BLUE}STEP 2: Scanning workflow files${NC}"
if [ ! -d "$WORKFLOWS_DIR" ]; then
    echo -e "${RED}❌ Workflows directory not found: $WORKFLOWS_DIR${NC}"
    exit 1
fi

WORKFLOW_FILES=$(find "$WORKFLOWS_DIR" -name "*.json" -type f | sort)
WORKFLOW_COUNT=$(echo "$WORKFLOW_FILES" | wc -l)

echo -e "${GREEN}✅ Found $WORKFLOW_COUNT workflow files:${NC}"
echo "$WORKFLOW_FILES" | while read -r file; do
    echo "   - $(basename "$file")"
done
echo ""

# ============================================================================
# STEP 3: Check if n8n requires authentication
# ============================================================================

echo -e "${BLUE}STEP 3: Checking n8n authentication${NC}"
AUTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$N8N_URL/api/v1/workflows")

if [ "$AUTH_CHECK" == "401" ] || [ "$AUTH_CHECK" == "403" ]; then
    echo -e "${YELLOW}⚠️  n8n requires authentication (API Key or Login)${NC}"
    echo ""
    echo "   MANUAL IMPORT REQUIRED:"
    echo "   1. Open n8n UI: $N8N_URL"
    echo "   2. Log in with your credentials"
    echo "   3. For each workflow file:"
    echo "      - Click menu (☰) → 'Import from File'"
    echo "      - Select the workflow JSON file"
    echo "      - Click 'Import'"
    echo "      - Click 'Active' toggle to activate"
    echo ""
    echo "   Workflow files to import:"
    echo "$WORKFLOW_FILES" | while read -r file; do
        echo "      - $file"
    done
    echo ""
    echo "============================================================================"
    exit 0
fi

if [ "$AUTH_CHECK" == "000" ]; then
    echo -e "${RED}❌ Cannot connect to n8n API${NC}"
    echo "   Verify n8n is running and accessible at: $N8N_URL"
    exit 1
fi

# ============================================================================
# STEP 4: Import workflows via API (if no auth required)
# ============================================================================

echo -e "${BLUE}STEP 4: Importing workflows via API${NC}"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

echo "$WORKFLOW_FILES" | while read -r file; do
    WORKFLOW_NAME=$(basename "$file" .json)
    echo -e "${YELLOW}Importing: $WORKFLOW_NAME${NC}"
    
    RESPONSE=$(curl -s -X POST "$N8N_URL/api/v1/workflows" \
        -H "Content-Type: application/json" \
        -d @"$file" 2>&1)
    
    if echo "$RESPONSE" | grep -q '"id"'; then
        echo -e "${GREEN}✅ SUCCESS: $WORKFLOW_NAME imported${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}❌ FAILED: $WORKFLOW_NAME${NC}"
        echo "   Error: $RESPONSE"
        ((FAIL_COUNT++))
    fi
    echo ""
done

# ============================================================================
# SUMMARY
# ============================================================================

echo "============================================================================"
echo "📊 IMPORT SUMMARY"
echo "============================================================================"
echo ""
echo "   Total workflows: $WORKFLOW_COUNT"
echo "   Imported: $SUCCESS_COUNT"
echo "   Failed: $FAIL_COUNT"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}✅ All workflows imported successfully!${NC}"
    echo ""
    echo "   NEXT STEPS:"
    echo "   1. Open n8n UI: $N8N_URL"
    echo "   2. Activate each workflow (click 'Active' toggle)"
    echo "   3. Verify credentials are configured correctly"
    echo "   4. Test webhooks with: ./tests/diagnose_webhook.sh"
else
    echo -e "${YELLOW}⚠️  Some workflows failed to import${NC}"
    echo "   Review errors above and import manually via UI"
fi

echo ""
echo "============================================================================"
