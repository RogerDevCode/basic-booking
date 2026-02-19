-- ============================================================================
-- VERIFICACIÓN DE SEED DATA
-- Ejecutar después de todos los scripts de seeds
-- ============================================================================

SELECT 'Resumen de datos insertados:' as titulo;

SELECT 'users (seed)' as tabla, COUNT(*) as total 
FROM public.users WHERE metadata->>'source' = 'seed_test'
UNION ALL
SELECT 'providers', COUNT(*) FROM public.providers WHERE slug LIKE 'dr-%' OR slug LIKE 'dra-%'
UNION ALL
SELECT 'services', COUNT(*) FROM public.services
UNION ALL
SELECT 'schedules', COUNT(*) FROM public.schedules
UNION ALL
SELECT 'bookings', COUNT(*) FROM public.bookings
UNION ALL
SELECT 'firewall', COUNT(*) FROM public.security_firewall
UNION ALL
SELECT 'notifications', COUNT(*) FROM public.notification_queue
UNION ALL
SELECT 'circuit_breakers', COUNT(*) FROM public.circuit_breaker_state
UNION ALL
SELECT 'system_errors', COUNT(*) FROM public.system_errors
UNION ALL
SELECT 'error_metrics', COUNT(*) FROM public.error_metrics
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM public.audit_logs
UNION ALL
SELECT 'provider_cache', COUNT(*) FROM public.provider_cache;

-- Verificar integridad referencial
SELECT 'Verificando integridad referencial...' as paso;

SELECT 'bookings sin user' as problema, COUNT(*) as total FROM public.bookings b
WHERE NOT EXISTS (SELECT 1 FROM public.users u WHERE u.id = b.user_id)
UNION ALL
SELECT 'bookings sin provider', COUNT(*) FROM public.bookings b
WHERE NOT EXISTS (SELECT 1 FROM public.providers p WHERE p.id = b.provider_id)
UNION ALL
SELECT 'services sin provider', COUNT(*) FROM public.services s
WHERE NOT EXISTS (SELECT 1 FROM public.providers p WHERE p.id = s.provider_id)
UNION ALL
SELECT 'schedules sin provider', COUNT(*) FROM public.schedules sch
WHERE NOT EXISTS (SELECT 1 FROM public.providers p WHERE p.id = sch.provider_id);

SELECT 'Verificación completada' as status;
