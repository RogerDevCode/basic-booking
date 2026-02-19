-- ============================================================================
-- SEED DATA - Part 4: SCHEDULES
-- Horarios para providers
-- ============================================================================

-- Dr. Alejandro Vera (Lun-Vie 9-18)
INSERT INTO public.schedules (id, provider_id, day_of_week, start_time, end_time, is_active)
SELECT gen_random_uuid(), 'b1b2b3b4-c5d6-7890-abcd-000000000001', d.day, '09:00:00'::time, '18:00:00'::time, true
FROM (VALUES ('Monday'::public.day_of_week), ('Tuesday'), ('Wednesday'), ('Thursday'), ('Friday')) AS d(day)
WHERE NOT EXISTS (SELECT 1 FROM public.schedules WHERE provider_id = 'b1b2b3b4-c5d6-7890-abcd-000000000001' AND day_of_week = d.day);

-- Dra. Carmen Luz (Lun, Mie, Vie 10-19)
INSERT INTO public.schedules (id, provider_id, day_of_week, start_time, end_time, is_active)
SELECT gen_random_uuid(), 'b1b2b3b4-c5d6-7890-abcd-000000000002', d.day, '10:00:00'::time, '19:00:00'::time, true
FROM (VALUES ('Monday'::public.day_of_week), ('Wednesday'), ('Friday')) AS d(day)
WHERE NOT EXISTS (SELECT 1 FROM public.schedules WHERE provider_id = 'b1b2b3b4-c5d6-7890-abcd-000000000002' AND day_of_week = d.day);

-- Dr. Roberto Fuentes (Mar, Jue 8-20)
INSERT INTO public.schedules (id, provider_id, day_of_week, start_time, end_time, is_active)
SELECT gen_random_uuid(), 'b1b2b3b4-c5d6-7890-abcd-000000000003', d.day, '08:00:00'::time, '20:00:00'::time, true
FROM (VALUES ('Tuesday'::public.day_of_week), ('Thursday')) AS d(day)
WHERE NOT EXISTS (SELECT 1 FROM public.schedules WHERE provider_id = 'b1b2b3b4-c5d6-7890-abcd-000000000003' AND day_of_week = d.day);

-- Dra. Lucia Mendez (Lun-Sab 7-21)
INSERT INTO public.schedules (id, provider_id, day_of_week, start_time, end_time, is_active)
SELECT gen_random_uuid(), 'b1b2b3b4-c5d6-7890-abcd-000000000004', d.day, '07:00:00'::time, '21:00:00'::time, true
FROM (VALUES ('Monday'::public.day_of_week), ('Tuesday'), ('Wednesday'), ('Thursday'), ('Friday'), ('Saturday')) AS d(day)
WHERE NOT EXISTS (SELECT 1 FROM public.schedules WHERE provider_id = 'b1b2b3b4-c5d6-7890-abcd-000000000004' AND day_of_week = d.day);

-- Dr. Schedule Test (Lun-Vie 9-17)
INSERT INTO public.schedules (id, provider_id, day_of_week, start_time, end_time, is_active)
SELECT gen_random_uuid(), 'b1b2b3b4-c5d6-7890-abcd-000000000008', d.day, '09:00:00'::time, '17:00:00'::time, true
FROM (VALUES ('Monday'::public.day_of_week), ('Tuesday'), ('Wednesday'), ('Thursday'), ('Friday')) AS d(day)
WHERE NOT EXISTS (SELECT 1 FROM public.schedules WHERE provider_id = 'b1b2b3b4-c5d6-7890-abcd-000000000008' AND day_of_week = d.day);

-- Dr. Weekend Only (Sab-Dom 9-15)
INSERT INTO public.schedules (id, provider_id, day_of_week, start_time, end_time, is_active)
SELECT gen_random_uuid(), 'b1b2b3b4-c5d6-7890-abcd-000000000009', d.day, '09:00:00'::time, '15:00:00'::time, true
FROM (VALUES ('Saturday'::public.day_of_week), ('Sunday')) AS d(day)
WHERE NOT EXISTS (SELECT 1 FROM public.schedules WHERE provider_id = 'b1b2b3b4-c5d6-7890-abcd-000000000009' AND day_of_week = d.day);

-- Dr. Night Shift (Lun, Mie, vie 18-23)
INSERT INTO public.schedules (id, provider_id, day_of_week, start_time, end_time, is_active)
SELECT gen_random_uuid(), 'b1b2b3b4-c5d6-7890-abcd-000000000010', d.day, '18:00:00'::time, '23:00:00'::time, true
FROM (VALUES ('Monday'::public.day_of_week), ('Wednesday'), ('Friday')) AS d(day)
WHERE NOT EXISTS (SELECT 1 FROM public.schedules WHERE provider_id = 'b1b2b3b4-c5d6-7890-abcd-000000000010' AND day_of_week = d.day);
