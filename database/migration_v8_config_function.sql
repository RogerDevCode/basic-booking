-- FIX: Unified Configuration Accessor (Migration V8 - Type Safe)
CREATE OR REPLACE FUNCTION public.get_tenant_config_json(p_tenant_id uuid)
RETURNS jsonb AS $$
DECLARE
    v_legacy jsonb;
    v_dynamic jsonb;
    v_merged jsonb;
BEGIN
    -- 1. Get Legacy Config
    SELECT row_to_json(nc)::jsonb INTO v_legacy
    FROM notification_configs nc
    WHERE tenant_id = p_tenant_id;
    
    -- 2. Get Dynamic Config (Type Safe)
    SELECT jsonb_object_agg(key, 
        CASE 
            WHEN type = 'number' THEN to_jsonb(value::numeric)
            WHEN type = 'boolean' THEN to_jsonb(value::boolean)
            WHEN type = 'json' THEN value::jsonb
            ELSE to_jsonb(value)
        END
    ) INTO v_dynamic
    FROM app_config
    WHERE tenant_id = p_tenant_id;

    -- 3. Merge
    v_legacy := COALESCE(v_legacy, '{}'::jsonb);
    v_dynamic := COALESCE(v_dynamic, '{}'::jsonb);
    
    v_merged := v_legacy || v_dynamic;
    
    -- 4. Inject Defaults
    IF (v_merged->>'SLOT_DURATION_MINS') IS NULL THEN
        v_merged := jsonb_set(v_merged, '{SLOT_DURATION_MINS}', '30');
    END IF;
    
    RETURN v_merged;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

SELECT public.get_tenant_config_json('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');