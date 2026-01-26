-- ============================================================================
-- Migration 02: Drop tenant_id Columns and tenants Table
-- ============================================================================
-- Purpose: Remove all tenant_id columns and the tenants table itself
-- 
-- WARNING: This is PHASE 2. Must run AFTER migration_01
-- ============================================================================

BEGIN;

-- Step 1: Drop tenant_id columns from all tables
-- -----------------------------------------------

DO $$ 
BEGIN
    -- Drop from admin_users
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admin_users' 
        AND column_name = 'tenant_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.admin_users DROP COLUMN tenant_id;
        RAISE NOTICE '✓ Dropped tenant_id from admin_users';
    END IF;

    -- Drop from app_config
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'app_config' 
        AND column_name = 'tenant_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.app_config DROP COLUMN tenant_id;
        RAISE NOTICE '✓ Dropped tenant_id from app_config';
    END IF;

    -- Drop from app_messages
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'app_messages' 
        AND column_name = 'tenant_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.app_messages DROP COLUMN tenant_id;
        RAISE NOTICE '✓ Dropped tenant_id from app_messages';
    END IF;

    -- Drop from bookings
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bookings' 
        AND column_name = 'tenant_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.bookings DROP COLUMN tenant_id;
        RAISE NOTICE '✓ Dropped tenant_id from bookings';
    END IF;

    -- Drop from notification_configs
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notification_configs' 
        AND column_name = 'tenant_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.notification_configs DROP COLUMN tenant_id;
        RAISE NOTICE '✓ Dropped tenant_id from notification_configs';
    END IF;

    -- Drop from professionals
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'professionals' 
        AND column_name = 'tenant_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.professionals DROP COLUMN tenant_id;
        RAISE NOTICE '✓ Dropped tenant_id from professionals';
    END IF;

    -- Drop from system_errors (nullable, no FK)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_errors' 
        AND column_name = 'tenant_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.system_errors DROP COLUMN tenant_id;
        RAISE NOTICE '✓ Dropped tenant_id from system_errors';
    END IF;
END $$;

-- Step 2: Recreate UNIQUE constraints without tenant_id
-- ------------------------------------------------------

-- app_config: key must be unique globally
ALTER TABLE public.app_config 
ADD CONSTRAINT app_config_key_unique UNIQUE (key);

-- app_messages: (code, lang) must be unique globally
ALTER TABLE public.app_messages 
ADD CONSTRAINT app_messages_code_lang_unique UNIQUE (code, lang);

RAISE NOTICE '✓ Recreated unique constraints without tenant_id';

-- Step 3: Drop the tenants table
-- -------------------------------

DROP TABLE IF EXISTS public.tenants CASCADE;
RAISE NOTICE '✓ Dropped tenants table';

-- Verification
-- ------------
DO $$
DECLARE
    v_tenant_columns integer;
    v_tenants_exists boolean;
BEGIN
    -- Check for remaining tenant_id columns
    SELECT COUNT(*) INTO v_tenant_columns
    FROM information_schema.columns 
    WHERE column_name = 'tenant_id' 
    AND table_schema = 'public';
    
    -- Check if tenants table exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'tenants' 
        AND table_schema = 'public'
    ) INTO v_tenants_exists;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Phase 2 Verification:';
    RAISE NOTICE '  - Remaining tenant_id columns: %', v_tenant_columns;
    RAISE NOTICE '  - Tenants table exists: %', v_tenants_exists;
    
    IF v_tenant_columns = 0 AND NOT v_tenants_exists THEN
        RAISE NOTICE '  ✅ All tenant schema elements removed!';
    ELSE
        RAISE WARNING '  ⚠️ Some tenant elements remain!';
    END IF;
    RAISE NOTICE '========================================';
END $$;

COMMIT;

RAISE NOTICE 'Phase 2 Complete: Tenant Schema Removed';
RAISE NOTICE 'Next: Run migration_03_update_functions.sql';
