-- FIX: Centralized Configuration System (Migration V7 - FINAL & COMPLETE)
-- Replaces hardcoded values with a dynamic Key-Value store per tenant

-- 1. Create app_config table
CREATE TABLE IF NOT EXISTS public.app_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    key varchar(100) NOT NULL,
    value text NOT NULL,
    type varchar(20) DEFAULT 'string' CHECK (type IN ('string', 'number', 'boolean', 'json', 'color', 'array')),
    category varchar(50) DEFAULT 'general',
    description text,
    is_public boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    UNIQUE(tenant_id, key)
);

CREATE INDEX IF NOT EXISTS idx_app_config_lookup ON public.app_config(tenant_id, key);
CREATE INDEX IF NOT EXISTS idx_app_config_public ON public.app_config(tenant_id) WHERE is_public = true;

-- Trigger to update timestamp
DROP TRIGGER IF EXISTS trg_app_config_timestamp ON public.app_config;
CREATE TRIGGER trg_app_config_timestamp
    BEFORE UPDATE ON public.app_config
    FOR EACH ROW EXECUTE FUNCTION public.update_notification_queue_timestamp();

-- 2. Seed Default Configs
DO $$
DECLARE
    v_tenant_id uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
BEGIN
    INSERT INTO public.tenants (id, name, slug)
    VALUES (v_tenant_id, 'Demo Tenant', 'demo')
    ON CONFLICT (id) DO NOTHING;

    -- CALENDAR
    INSERT INTO public.app_config (tenant_id, key, value, type, category, is_public) VALUES
    (v_tenant_id, 'SCHEDULE_START_HOUR', '9', 'number', 'calendar', true),
    (v_tenant_id, 'SCHEDULE_END_HOUR', '18', 'number', 'calendar', true),
    (v_tenant_id, 'SCHEDULE_DAYS', '[1,2,3,4,5]', 'json', 'calendar', true),
    (v_tenant_id, 'SLOT_DURATION_MINS', '30', 'number', 'calendar', true),
    (v_tenant_id, 'CALENDAR_MIN_TIME', '07:00:00', 'string', 'calendar', true),
    (v_tenant_id, 'CALENDAR_MAX_TIME', '21:00:00', 'string', 'calendar', true),
    (v_tenant_id, 'TIMEZONE', 'America/Santiago', 'string', 'calendar', true)
    ON CONFLICT (tenant_id, key) DO UPDATE SET value = EXCLUDED.value;

    -- BRANDING
    INSERT INTO public.app_config (tenant_id, key, value, type, category, is_public) VALUES
    (v_tenant_id, 'APP_TITLE', 'AutoAgenda Admin', 'string', 'branding', true),
    (v_tenant_id, 'COLOR_PRIMARY', '#2563eb', 'color', 'branding', true),
    (v_tenant_id, 'COLOR_PRIMARY_HOVER', '#1d4ed8', 'color', 'branding', true),
    (v_tenant_id, 'COLOR_SUCCESS', '#10b981', 'color', 'branding', true),
    (v_tenant_id, 'COLOR_DANGER', '#ef4444', 'color', 'branding', true),
    (v_tenant_id, 'COLOR_EVENT_CONFIRMED', '#dcfce7', 'color', 'branding', true),
    (v_tenant_id, 'COLOR_EVENT_PENDING', '#fff7ed', 'color', 'branding', true),
    (v_tenant_id, 'COLOR_EVENT_TEXT', '#0f172a', 'color', 'branding', true)
    ON CONFLICT (tenant_id, key) DO UPDATE SET value = EXCLUDED.value;

    -- BUSINESS LOGIC
    INSERT INTO public.app_config (tenant_id, key, value, type, category, is_public) VALUES
    (v_tenant_id, 'BOOKING_MIN_NOTICE_HOURS', '2', 'number', 'business', true),
    (v_tenant_id, 'BOOKING_MAX_NOTICE_DAYS', '60', 'number', 'business', true),
    (v_tenant_id, 'DEFAULT_DURATION_MIN', '30', 'number', 'business', true),
    (v_tenant_id, 'MIN_DURATION_MIN', '15', 'number', 'business', true),
    (v_tenant_id, 'MAX_DURATION_MIN', '120', 'number', 'business', true),
    (v_tenant_id, 'DEFAULT_PROFESSIONAL_ID', '2eebc9bc-c2f8-46f8-9e78-7da0909fcca4', 'string', 'business', true),
    (v_tenant_id, 'DEFAULT_SERVICE_ID', 'a7a019cb-3442-4f57-8877-1b04a1749c01', 'string', 'business', true)
    ON CONFLICT (tenant_id, key) DO UPDATE SET value = EXCLUDED.value;

    -- SYSTEM / ALERTS
    INSERT INTO public.app_config (tenant_id, key, value, type, category, is_public) VALUES
    (v_tenant_id, 'ERROR_ALERT_CHAT_ID', '5391760292', 'string', 'system', false),
    (v_tenant_id, 'NOTIFICATION_CRON_MINUTES', '15', 'number', 'notifications', false),
    (v_tenant_id, 'RETRY_WORKER_CRON_MINUTES', '5', 'number', 'notifications', false),
    (v_tenant_id, 'NOTIFICATION_BATCH_LIMIT', '50', 'number', 'notifications', false),
    (v_tenant_id, 'NOTIFICATION_MAX_RETRIES', '3', 'number', 'notifications', false)
    ON CONFLICT (tenant_id, key) DO UPDATE SET value = EXCLUDED.value;

END $$;

SELECT public.get_tenant_config_json('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');