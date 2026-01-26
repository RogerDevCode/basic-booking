#!/bin/bash
# ============================================================================
# Pre-Migration Backup Script
# ============================================================================
# Purpose: Create a complete backup before executing the single-tenant migration
#
# Usage: bash database/backup_before_migration.sh
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Create backups directory
BACKUP_DIR="database/backups"
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/pre_single_tenant_migration_$TIMESTAMP.sql"

echo "============================================"
echo "🔒 Creating Pre-Migration Backup"
echo "============================================"
echo ""
echo "Database: $DATABASE_URL"
echo "Backup file: $BACKUP_FILE"
echo ""

# Extract connection details for pg_dump
# Neon format: postgresql://user:pass@host/dbname
DB_USER=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
DB_PASS=$(echo "$DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
DB_HOST=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^\/]*\)\/.*/\1/p')
DB_NAME=$(echo "$DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')

echo -e "${YELLOW}⏳ Creating backup... This may take a few minutes${NC}"

# Create backup using pg_dump
PGPASSWORD="$DB_PASS" pg_dump \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl \
    -f "$BACKUP_FILE"

# Check if backup was successful
if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo -e "${GREEN}✅ Backup created successfully${NC}"
    echo "   File: $BACKUP_FILE"
    echo "   Size: $BACKUP_SIZE"
    echo ""
    
    # Save backup metadata
    echo "Backup created: $TIMESTAMP" > "$BACKUP_DIR/last_backup_info.txt"
    echo "File: $BACKUP_FILE" >> "$BACKUP_DIR/last_backup_info.txt"
    echo "Size: $BACKUP_SIZE" >> "$BACKUP_DIR/last_backup_info.txt"
    
    # Create data snapshot for verification
    echo ""
    echo -e "${YELLOW}📊 Creating data snapshot...${NC}"
    
    SNAPSHOT_FILE="$BACKUP_DIR/data_snapshot_$TIMESTAMP.txt"
    
    psql "$DATABASE_URL" > "$SNAPSHOT_FILE" << 'EOF'
-- Data Snapshot for Migration Verification
\pset format unaligned
\pset tuples_only on

\echo '=========================================='
\echo 'Pre-Migration Data Snapshot'
\echo '=========================================='
\echo ''

\echo 'Table: tenants'
SELECT 'Count', COUNT(*) FROM tenants;
SELECT 'Sample', id, name FROM tenants LIMIT 3;
\echo ''

\echo 'Table: admin_users'
SELECT 'Count', COUNT(*) FROM admin_users;
SELECT 'With tenant_id', COUNT(*) FROM admin_users WHERE tenant_id IS NOT NULL;
\echo ''

\echo 'Table: app_config'
SELECT 'Count', COUNT(*) FROM app_config;
SELECT 'Unique keys', COUNT(DISTINCT key) FROM app_config;
SELECT 'With tenant_id', COUNT(*) FROM app_config WHERE tenant_id IS NOT NULL;
\echo ''

\echo 'Table: app_messages'
SELECT 'Count', COUNT(*) FROM app_messages;
SELECT 'Unique codes', COUNT(DISTINCT code) FROM app_messages;
\echo ''

\echo 'Table: bookings'
SELECT 'Count', COUNT(*) FROM bookings WHERE deleted_at IS NULL;
SELECT 'With tenant_id', COUNT(*) FROM bookings WHERE tenant_id IS NOT NULL;
\echo ''

\echo 'Table: professionals'
SELECT 'Count', COUNT(*) FROM professionals WHERE deleted_at IS NULL;
SELECT 'With tenant_id', COUNT(*) FROM professionals WHERE tenant_id IS NOT NULL;
\echo ''

\echo 'Table: users'
SELECT 'Count', COUNT(*) FROM users WHERE deleted_at IS NULL;
\echo ''

\echo '=========================================='
\echo 'End of Snapshot'
\echo '=========================================='
EOF
    
    echo -e "${GREEN}✅ Data snapshot created${NC}"
    echo "   File: $SNAPSHOT_FILE"
    echo ""
    
    echo "============================================"
    echo -e "${GREEN}🎯 Backup Complete!${NC}"
    echo "============================================"
    echo ""
    echo "You can now proceed with the migration:"
    echo "  bash database/run_migration.sh"
    echo ""
    echo "To restore from this backup if needed:"
    echo "  psql \$DATABASE_URL < $BACKUP_FILE"
    echo ""
    
else
    echo -e "${RED}❌ Backup failed!${NC}"
    exit 1
fi
