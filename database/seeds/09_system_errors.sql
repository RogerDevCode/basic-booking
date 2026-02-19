-- ============================================================================
-- SEED DATA - Part 9: SYSTEM_ERRORS & ERROR_METRICS
-- Errores del sistema y métricas
-- ============================================================================

-- System Errors
INSERT INTO public.system_errors (error_id, workflow_name, workflow_execution_id, error_type, severity, error_message, error_stack, error_context, user_id, created_at, resolved_at, is_resolved, resolution_notes)
VALUES
    (gen_random_uuid(), 'BB_03_Availability_Engine', 'exec_001', 'DATABASE', 'LOW', 'Query timeout on availability check', 'Error at line 45', '{"query": "SELECT slots..."}', NULL, NOW() - INTERVAL '2 hours', NULL, false, NULL),
    (gen_random_uuid(), 'BB_04_GCal_Sync', 'exec_002', 'API', 'MEDIUM', 'Google Calendar API rate limit', NULL, '{"api": "gcal", "status": 429}', NULL, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '30 minutes', true, 'Rate limit reset'),
    (gen_random_uuid(), 'BB_05_Reminder_Worker', 'exec_003', 'NETWORK', 'HIGH', 'Failed to send Telegram notification', 'Connection refused', '{"chat_id": "3000001"}', (SELECT id FROM public.users WHERE telegram_id = 3000001), NOW() - INTERVAL '45 minutes', NULL, false, NULL),
    (gen_random_uuid(), 'BB_01_Telegram_Bot', 'exec_004', 'VALIDATION', 'LOW', 'Invalid message format received', NULL, '{"message_id": 12345}', (SELECT id FROM public.users WHERE telegram_id = 3000002), NOW() - INTERVAL '30 minutes', NULL, false, NULL),
    (gen_random_uuid(), 'BB_02_Booking_Flow', 'exec_005', 'LOGIC', 'MEDIUM', 'Concurrent booking attempt detected', NULL, '{"provider_id": "b1b2b3b4-c5d6-7890-abcd-000000000001"}', NULL, NOW() - INTERVAL '15 minutes', NULL, false, NULL);

-- Error Metrics
INSERT INTO public.error_metrics (id, metric_date, workflow_name, severity, error_count, first_occurrence, last_occurrence, created_at, updated_at)
VALUES
    (gen_random_uuid(), CURRENT_DATE - INTERVAL '1 day', 'BB_03_Availability_Engine', 'LOW', 5, NOW() - INTERVAL '25 hours', NOW() - INTERVAL '24 hours', NOW() - INTERVAL '24 hours', NOW()),
    (gen_random_uuid(), CURRENT_DATE - INTERVAL '1 day', 'BB_04_GCal_Sync', 'MEDIUM', 3, NOW() - INTERVAL '26 hours', NOW() - INTERVAL '24 hours', NOW() - INTERVAL '24 hours', NOW()),
    (gen_random_uuid(), CURRENT_DATE, 'BB_03_Availability_Engine', 'LOW', 2, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 hour', NOW(), NOW());
