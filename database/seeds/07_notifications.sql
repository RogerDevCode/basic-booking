-- ============================================================================
-- SEED DATA - Part 7: NOTIFICATION_QUEUE
-- Notificaciones en cola
-- ============================================================================

-- Notificaciones pendientes basadas en bookings confirmados futuros
INSERT INTO public.notification_queue (id, booking_id, user_id, message, priority, status, retry_count, created_at, updated_at, channel, recipient, payload, max_retries, expires_at)
SELECT gen_random_uuid(), b.id, b.user_id,
    'Recordatorio: Tu reserva es mañana a las ' || to_char(b.start_time, 'HH24:MI'),
    1, 'pending', 0, NOW(), NOW(), 'telegram', u.telegram_id::text,
    jsonb_build_object('booking_id', b.id, 'start_time', b.start_time),
    3, b.start_time - INTERVAL '1 hour'
FROM public.bookings b
JOIN public.users u ON u.id = b.user_id
WHERE b.status = 'confirmed' AND b.start_time > NOW() AND b.start_time < NOW() + INTERVAL '3 days'
LIMIT 3;

-- Notificación fallida para retry testing
INSERT INTO public.notification_queue (id, booking_id, user_id, message, priority, status, retry_count, error_message, created_at, updated_at, channel, recipient, payload, max_retries, expires_at)
SELECT gen_random_uuid(), NULL, id, 'Test notification failed', 0, 'failed', 3, 'Max retries exceeded', NOW() - INTERVAL '1 hour', NOW(), 'telegram', telegram_id::text, '{}', 3, NOW() + INTERVAL '1 hour'
FROM public.users WHERE telegram_id = 3000001
LIMIT 1;

-- Notificación con retry pendiente
INSERT INTO public.notification_queue (id, booking_id, user_id, message, priority, status, retry_count, error_message, created_at, updated_at, channel, recipient, payload, max_retries, expires_at)
SELECT gen_random_uuid(), NULL, id, 'Test notification retry', 0, 'pending', 2, 'Network timeout', NOW() - INTERVAL '30 minutes', NOW(), 'telegram', telegram_id::text, '{}', 3, NOW() + INTERVAL '2 hours'
FROM public.users WHERE telegram_id = 3000002
LIMIT 1;
