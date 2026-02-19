-- ============================================================================
-- SEED DATA - Part 8: CIRCUIT_BREAKER_STATE
-- Estados de circuit breaker
-- ============================================================================

INSERT INTO public.circuit_breaker_state (id, workflow_name, state, failure_count, last_failure_at, opened_at, next_attempt_at, created_at, updated_at)
VALUES
    (gen_random_uuid(), 'BB_01_Telegram_Bot', 'CLOSED', 0, NULL, NULL, NULL, NOW(), NOW()),
    (gen_random_uuid(), 'BB_02_Booking_Flow', 'CLOSED', 2, NOW() - INTERVAL '1 hour', NULL, NULL, NOW(), NOW()),
    (gen_random_uuid(), 'BB_03_Availability_Engine', 'CLOSED', 0, NULL, NULL, NULL, NOW(), NOW()),
    (gen_random_uuid(), 'BB_04_GCal_Sync', 'HALF_OPEN', 4, NOW() - INTERVAL '5 minutes', NOW() - INTERVAL '10 minutes', NOW() + INTERVAL '5 minutes', NOW(), NOW()),
    (gen_random_uuid(), 'BB_05_Reminder_Worker', 'OPEN', 6, NOW() - INTERVAL '2 minutes', NOW() - INTERVAL '2 minutes', NOW() + INTERVAL '58 minutes', NOW(), NOW()),
    (gen_random_uuid(), 'BB_06_Notification_Retry', 'CLOSED', 1, NOW() - INTERVAL '30 minutes', NULL, NULL, NOW(), NOW())
ON CONFLICT (workflow_name) DO UPDATE SET
    state = EXCLUDED.state,
    failure_count = EXCLUDED.failure_count,
    last_failure_at = EXCLUDED.last_failure_at,
    opened_at = EXCLUDED.opened_at,
    next_attempt_at = EXCLUDED.next_attempt_at,
    updated_at = NOW();
