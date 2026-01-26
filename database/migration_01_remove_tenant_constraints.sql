-- ============================================================================
-- Migration 01: Remove Tenant Foreign Key Constraints
-- ============================================================================
-- Purpose: Prepare database for single-tenant migration by removing all FK
--          constraints that reference the tenants table.
-- 
-- WARNING: This is PHASE 1 of the migration. Execute in order!
-- ============================================================================

BEGIN;

-- Step 1: Drop Foreign Key Constraints to tenants table
-- -------------------------------------------------------

DO $$ 
BEGIN
    -- Drop FK from admin_users
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'admin_users_tenant_id_fkey'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.admin_users DROP CONSTRAINT admin_users_tenant_id_fkey;
        RAISE NOTICE '✓ Dropped admin_users_tenant_id_fkey';
    END IF;

    -- Drop FK from bookings
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'bookings_tenant_id_fkey'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.bookings DROP CONSTRAINT bookings_tenant_id_fkey;
        RAISE NOTICE '✓ Dropped bookings_tenant_id_fkey';
    END IF;

    -- Drop FK from notification_configs
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'notification_configs_tenant_id_fkey'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notification_configs DROP CONSTRAINT notification_configs_tenant_id_fkey;
        RAISE NOTICE '✓ Dropped notification_configs_tenant_id_fkey';
    END IF;

    -- Drop FK from professionals
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'professionals_tenant_id_fkey'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.professionals DROP CONSTRAINT professionals_tenant_id_fkey;
        RAISE NOTICE '✓ Dropped professionals_tenant_id_fkey';
    END IF;
END $$;

-- Step 2: Drop Tenant-based UNIQUE constraints (will recreate without tenant_id)
-- -------------------------------------------------------------------------------

DO $$ 
BEGIN
    -- Drop app_config unique constraint (tenant_id, key)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'app_config_tenant_id_key_key'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.app_config DROP CONSTRAINT app_config_tenant_id_key_key;
        RAISE NOTICE '✓ Dropped app_config_tenant_id_key_key';
    END IF;

    -- Drop app_messages unique constraint (tenant_id, code, lang)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'app_messages_tenant_id_code_lang_key'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.app_messages DROP CONSTRAINT app_messages_tenant_id_code_lang_key;
        RAISE NOTICE '✓ Dropped app_messages_tenant_id_code_lang_key';
    END IF;

    -- Drop notification_configs unique constraint (tenant_id)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'unique_tenant_config'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notification_configs DROP CONSTRAINT unique_tenant_config;
        RAISE NOTICE '✓ Dropped unique_tenant_config';
    END IF;
END $$;

-- Verification
-- ------------
SELECT 
    'Foreign Keys to tenants' as check_type,
    COUNT(*) as remaining_fks
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
WHERE ccu.table_name = 'tenants' 
    AND tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'public';

COMMIT;

RAISE NOTICE '========================================';
RAISE NOTICE 'Phase 1 Complete: Constraints Removed';
RAISE NOTICE 'Next: Run migration_02_drop_tenant_columns.sql';
RAISE NOTICE '========================================';
