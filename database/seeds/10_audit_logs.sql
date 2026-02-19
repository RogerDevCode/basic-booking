-- ============================================================================
-- SEED DATA - Part 10: AUDIT_LOGS & PROVIDER_CACHE
-- Logs de auditoría y cache
-- ============================================================================

-- Audit Logs (sin ON CONFLICT - cada registro es único por ID)
INSERT INTO public.audit_logs (id, table_name, record_id, action, old_values, new_values, performed_by, ip_address, created_at, event_type, event_data)
SELECT gen_random_uuid(), 'users', id, 'INSERT', NULL, '{"telegram_id": 3000001}', 'system', NULL, NOW() - INTERVAL '30 days', 'USER_CREATED', '{"source": "seed"}'
FROM public.users WHERE telegram_id = 3000001
LIMIT 1;

INSERT INTO public.audit_logs (id, table_name, record_id, action, old_values, new_values, performed_by, ip_address, created_at, event_type, event_data)
SELECT gen_random_uuid(), 'providers', 'b1b2b3b4-c5d6-7890-abcd-000000000001', 'INSERT', NULL, '{"name": "Dr. Alejandro Vera"}', 'system', NULL, NOW() - INTERVAL '60 days', 'PROVIDER_CREATED', '{"source": "seed"}'
WHERE EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000001');

INSERT INTO public.audit_logs (id, table_name, record_id, action, old_values, new_values, performed_by, ip_address, created_at, event_type, event_data)
SELECT gen_random_uuid(), 'security_firewall', gen_random_uuid(), 'UPDATE', '{"strike_count": 4}', '{"strike_count": 5}', 'system', NULL, NOW() - INTERVAL '30 minutes', 'STRIKE_ADDED', '{"entity_id": "telegram:3000016"}'
WHERE EXISTS (SELECT 1 FROM public.security_firewall WHERE entity_id = 'telegram:3000016');

INSERT INTO public.audit_logs (id, table_name, record_id, action, old_values, new_values, performed_by, ip_address, created_at, event_type, event_data)
SELECT gen_random_uuid(), 'users', id, 'SOFT_DELETE', '{"deleted_at": null}', '{"deleted_at": "now"}', 'admin', '192.168.1.100'::inet, NOW() - INTERVAL '5 days', 'USER_SOFT_DELETED', '{"reason": "test"}'
FROM public.users WHERE telegram_id = 3000017
LIMIT 1;

-- Provider Cache (upsert manual)
DELETE FROM public.provider_cache WHERE provider_id IN (
    SELECT id FROM public.providers WHERE deleted_at IS NULL AND public_booking_enabled = true
);

INSERT INTO public.provider_cache (id, provider_id, provider_slug, data, cached_at, expires_at, created_at)
SELECT gen_random_uuid(), p.id, p.slug,
    jsonb_build_object(
        'name', p.name,
        'email', p.email,
        'slot_duration', p.slot_duration_mins,
        'services', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'duration', s.duration_minutes)) FROM public.services s WHERE s.provider_id = p.id), '[]'::jsonb),
        'schedules', COALESCE((SELECT jsonb_agg(jsonb_build_object('day', sch.day_of_week, 'start', sch.start_time, 'end', sch.end_time)) FROM public.schedules sch WHERE sch.provider_id = p.id), '[]'::jsonb)
    ),
    NOW(), NOW() + INTERVAL '1 hour', NOW()
FROM public.providers p
WHERE p.deleted_at IS NULL AND p.public_booking_enabled = true;

SELECT 'Audit logs y cache insertados' as status;
