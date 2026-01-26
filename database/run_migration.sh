#!/bin/bash
# ============================================================================
# Single-Tenant Migration Runner
# ============================================================================
# Purpose: Execute all migration scripts in order with verification
#
# Usage: bash database/run_migration.sh
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi

# Check DB_URL
if [ -z "$DATABASE_URL" ]; then
    echo -e "${RED}❌ DATABASE_URL not set in .env${NC}"
    exit 1
fi

DB_URL="$DATABASE_URL"

echo "============================================"
echo "🚀 AutoAgenda Single-Tenant Migration"
echo "============================================"
echo ""

# Check for backup
if [ ! -d "database/backups" ] || [ -z "$(ls -A database/backups 2>/dev/null)" ]; then
    echo -e "${YELLOW}⚠️  WARNING: No backup found!${NC}"
    echo ""
    read -p "Do you want to create a backup now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bash database/backup_before_migration.sh
    else
        echo ""
        read -p "Continue WITHOUT backup? This is DANGEROUS! (yes/NO): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            echo "Migration cancelled."
            exit 0
        fi
    fi
fi

echo ""
echo -e "${BLUE}Starting migration...${NC}"
echo ""

# ============================================================================
# Phase 1: Remove Tenant Constraints
# ============================================================================
echo "============================================"
echo "📦 Phase 1: Removing Tenant Constraints"
echo "============================================"
echo ""

if psql "$DB_URL" -f database/migration_01_remove_tenant_constraints.sql; then
    echo -e "${GREEN}✅ Phase 1 completed successfully${NC}"
else
    echo -e "${RED}❌ Phase 1 failed!${NC}"
    echo "Please check the error messages above and restore from backup if needed."
    exit 1
fi

echo ""
read -p "Press Enter to continue to Phase 2..."
echo ""

# ============================================================================
# Phase 2: Drop Tenant Columns and Table
# ============================================================================
echo "============================================"
echo "🗑️  Phase 2: Dropping Tenant Schema"
echo "============================================"
echo ""

if psql "$DB_URL" -f database/migration_02_drop_tenant_columns.sql; then
    echo -e "${GREEN}✅ Phase 2 completed successfully${NC}"
else
    echo -e "${RED}❌ Phase 2 failed!${NC}"
    echo "Please restore from backup immediately:"
    LATEST_BACKUP=$(ls -t database/backups/*.sql 2>/dev/null | head -1)
    echo "  psql \$DATABASE_URL < $LATEST_BACKUP"
    exit 1
fi

echo ""
read -p "Press Enter to continue to Phase 3..."
echo ""

# ============================================================================
# Phase 3: Update SQL Functions
# ============================================================================
echo "============================================"
echo "⚙️  Phase 3: Updating SQL Functions"
echo "============================================"
echo ""

if psql "$DB_URL" -f database/migration_03_update_functions.sql; then
    echo -e "${GREEN}✅ Phase 3 completed successfully${NC}"
else
    echo -e "${RED}❌ Phase 3 failed!${NC}"
    echo "Please restore from backup:"
    LATEST_BACKUP=$(ls -t database/backups/*.sql 2>/dev/null | head -1)
    echo "  psql \$DATABASE_URL < $LATEST_BACKUP"
    exit 1
fi

echo ""
echo ""

# ============================================================================
# Verification
# ============================================================================
echo "============================================"
echo "🔍 Running Verification Tests"
echo "============================================"
echo ""

if bash tests/verify_single_tenant.sh; then
    echo ""
    echo "============================================"
    echo -e "${GREEN}🎯 MIGRATION SUCCESSFUL!${NC}"
    echo "============================================"
    echo ""
    echo "Next steps:"
    echo "  1. Update N8N workflows to remove tenant_id references"
    echo "  2. Test workflows end-to-end"
    echo "  3. Update documentation (GEMINI.md)"
    echo ""
    echo "Migration artifacts saved in:"
    echo "  - Backup: database/backups/"
    echo "  - Migration scripts: database/migration_*.sql"
    echo ""
else
    echo ""
    echo "============================================"
    echo -e "${YELLOW}⚠️  VERIFICATION FAILED${NC}"
    echo "============================================"
    echo ""
    echo "The migration may have completed but some"
    echo "verification tests failed. Review the output"
    echo "above to determine if this is critical."
    echo ""
    echo "To rollback:"
    LATEST_BACKUP=$(ls -t database/backups/*.sql 2>/dev/null | head -1)
    echo "  psql \$DATABASE_URL < $LATEST_BACKUP"
    echo ""
    exit 1
fi
