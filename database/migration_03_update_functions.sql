-- ============================================================================
-- Migration 03: Update SQL Functions for Single-Tenant
-- ============================================================================
-- Purpose: Remove tenant_id parameters from all functions and simplify logic
-- 
-- WARNING: This is PHASE 3. Must run AFTER migration_02
-- ============================================================================

BEGIN;

-- ============================================================================
-- Function 1: create_admin_user (Remove p_tenant_id parameter)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_admin_user(
    p_username text,
    p_password text,
    p_role text DEFAULT 'admin'::text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    INSERT INTO public.admin_users (username, password_hash, role)
    VALUES (
        p_username,
        crypt(p_password, gen_salt('bf')),
        p_role
    )
    RETURNING id INTO v_user_id;
    
    RETURN v_user_id;
END;
$$;

COMMENT ON FUNCTION public.create_admin_user(text, text, text) IS 
'Helper function to create new admin users with hashed passwords. Single-tenant version.';

RAISE NOTICE '✓ Updated create_admin_user() - removed p_tenant_id';

-- ============================================================================
-- Function 2: get_config (Remove p_tenant_id parameter)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_config(
    p_key text,
    p_default text DEFAULT NULL::text
) RETURNS text
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_val text;
BEGIN
    SELECT value INTO v_val 
    FROM public.app_config 
    WHERE key = p_key;
    
    RETURN COALESCE(v_val, p_default);
END;
$$;

COMMENT ON FUNCTION public.get_config(text, text) IS 
'Retrieves configuration value by key. Single-tenant version.';

RAISE NOTICE '✓ Updated get_config() - removed p_tenant_id';

-- ============================================================================
-- Function 3: get_message (Remove p_tenant_id parameter)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_message(
    p_code text,
    p_lang text DEFAULT 'es'::text
) RETURNS text
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_msg text;
BEGIN
    -- Try to get message in requested language
    SELECT message INTO v_msg
    FROM app_messages
    WHERE code = p_code AND lang = p_lang;
    
    -- Fallback to Spanish if not found
    IF v_msg IS NULL AND p_lang != 'es' THEN
        SELECT message INTO v_msg
        FROM app_messages
        WHERE code = p_code AND lang = 'es';
    END IF;
    
    -- Return code itself if no message found (defensive)
    RETURN COALESCE(v_msg, p_code);
END;
$$;

COMMENT ON FUNCTION public.get_message(text, text) IS 
'Retrieves i18n message by code and language. Single-tenant version.';

RAISE NOTICE '✓ Updated get_message() - removed p_tenant_id';

-- ============================================================================
-- Function 4: get_public_config_json (Remove p_tenant_id parameter)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_public_config_json() RETURNS jsonb
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_json jsonb;
BEGIN
    SELECT jsonb_object_agg(key, 
        CASE 
            WHEN type = 'number' THEN to_jsonb(value::numeric)
            WHEN type = 'boolean' THEN to_jsonb(value::boolean)
            WHEN type = 'json' THEN value::jsonb
            ELSE to_jsonb(value)
        END
    ) INTO v_json
    FROM public.app_config
    WHERE is_public = true;
    
    RETURN COALESCE(v_json, '{}'::jsonb);
END;
$$;

COMMENT ON FUNCTION public.get_public_config_json() IS 
'Returns all public configuration as JSONB. Single-tenant version.';

RAISE NOTICE '✓ Updated get_public_config_json() - removed p_tenant_id';

-- ============================================================================
-- Function 5: get_config_json (Renamed from get_tenant_config_json)
-- ============================================================================

-- Drop old function if exists
DROP FUNCTION IF EXISTS public.get_tenant_config_json(uuid);

-- Create new simplified function
CREATE OR REPLACE FUNCTION public.get_config_json() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
    v_legacy jsonb;
    v_dynamic jsonb;
    v_merged jsonb;
BEGIN
    -- 1. Get Legacy Config from notification_configs
    --    (Single-tenant: only 1 row exists)
    SELECT row_to_json(nc)::jsonb INTO v_legacy
    FROM notification_configs nc
    LIMIT 1;
    
    -- 2. Get Dynamic Config (Type Safe)
    SELECT jsonb_object_agg(key, 
        CASE 
            WHEN type = 'number' THEN to_jsonb(value::numeric)
            WHEN type = 'boolean' THEN to_jsonb(value::boolean)
            WHEN type = 'json' THEN value::jsonb
            ELSE to_jsonb(value)
        END
    ) INTO v_dynamic
    FROM app_config;

    -- 3. Merge configurations
    v_legacy := COALESCE(v_legacy, '{}'::jsonb);
    v_dynamic := COALESCE(v_dynamic, '{}'::jsonb);
    
    v_merged := v_legacy || v_dynamic;
    
    -- 4. Inject default values if missing
    IF (v_merged->>'SLOT_DURATION_MINS') IS NULL THEN
        v_merged := jsonb_set(v_merged, '{SLOT_DURATION_MINS}', '30');
    END IF;
    
    RETURN v_merged;
END;
$$;

COMMENT ON FUNCTION public.get_config_json() IS 
'Returns merged configuration from notification_configs and app_config as JSONB. Single-tenant version.';

RAISE NOTICE '✓ Created get_config_json() - replaced get_tenant_config_json()';

-- ============================================================================
-- Function 6: verify_admin_credentials (Remove tenant_id from return)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.verify_admin_credentials(
    p_username text,
    p_password text
) RETURNS TABLE(
    valid boolean,
    user_id uuid,
    role public.user_role
)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_user_record record;
BEGIN
    SELECT * INTO v_user_record 
    FROM public.users 
    WHERE username = p_username;
    
    IF v_user_record IS NULL THEN
        RETURN QUERY SELECT false, null::uuid, null::public.user_role;
        RETURN;
    END IF;

    -- Verify password hash
    IF v_user_record.password_hash = crypt(p_password, v_user_record.password_hash) THEN
         RETURN QUERY SELECT true, v_user_record.id, v_user_record.role;
    ELSE
         RETURN QUERY SELECT false, null::uuid, null::public.user_role;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.verify_admin_credentials(text, text) IS 
'Verifies admin credentials and returns user info. Single-tenant version.';

RAISE NOTICE '✓ Updated verify_admin_credentials() - removed tenant_id from return';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
    v_function_count integer;
BEGIN
    -- Count functions that still have p_tenant_id parameter
    SELECT COUNT(*) INTO v_function_count
    FROM information_schema.parameters
    WHERE parameter_name = 'p_tenant_id'
    AND specific_schema = 'public';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Phase 3 Verification:';
    RAISE NOTICE '  - Functions with p_tenant_id param: %', v_function_count;
    
    IF v_function_count = 0 THEN
        RAISE NOTICE '  ✅ All functions updated successfully!';
    ELSE
        RAISE WARNING '  ⚠️ Some functions still have tenant parameters!';
    END IF;
    RAISE NOTICE '========================================';
END $$;

COMMIT;

RAISE NOTICE 'Phase 3 Complete: Functions Updated for Single-Tenant';
RAISE NOTICE 'Next: Update N8N Workflows to use new function signatures';
