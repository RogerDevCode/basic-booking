-- ============================================================================
-- SEED DATA - Part 2: PROVIDERS
-- Proveedores con diferentes configuraciones
-- ============================================================================

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000001', 'Dr. Alejandro Vera', 'alejandro.vera@clinic.com', 'alejandro.vera@gmail.com', 30, 4, true, NOW() - INTERVAL '60 days', NULL, 'dr-alejandro-vera', 30
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000001');

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000002', 'Dra. Carmen Luz', 'carmen.luz@clinic.com', NULL, 45, 2, true, NOW() - INTERVAL '45 days', NULL, 'dra-carmen-luz', 45
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000002');

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000003', 'Dr. Roberto Fuentes', 'roberto.fuentes@therapy.com', 'roberto.f@gmail.com', 60, 24, true, NOW() - INTERVAL '30 days', NULL, 'dr-roberto-fuentes', 60
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000003');

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000004', 'Dra. Lucia Mendez', 'lucia.mendez@quick.com', NULL, 15, 1, true, NOW() - INTERVAL '20 days', NULL, 'dra-lucia-mendez', 15
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000004');

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000005', 'Dr. Disabled Test', 'disabled@test.com', NULL, 30, 2, false, NOW() - INTERVAL '15 days', NULL, 'dr-disabled-seed', 30
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000005');

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000006', 'Dr. Old Provider', 'old@provider.com', NULL, 30, 2, true, NOW() - INTERVAL '90 days', NOW() - INTERVAL '30 days', 'dr-old-provider-seed', 30
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000006');

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000008', 'Dr. Schedule Test', 'schedule@test.com', NULL, 30, 2, true, NOW(), NULL, 'dr-schedule-test', 30
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000008');

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000009', 'Dr. Weekend Only', 'weekend@test.com', NULL, 30, 2, true, NOW(), NULL, 'dr-weekend-only', 30
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000009');

INSERT INTO public.providers (id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins)
SELECT 'b1b2b3b4-c5d6-7890-abcd-000000000010', 'Dr. Night Shift', 'night@test.com', NULL, 30, 2, true, NOW(), NULL, 'dr-night-shift', 30
WHERE NOT EXISTS (SELECT 1 FROM public.providers WHERE id = 'b1b2b3b4-c5d6-7890-abcd-000000000010');
