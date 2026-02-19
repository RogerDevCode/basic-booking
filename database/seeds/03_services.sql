-- ============================================================================
-- SEED DATA - Part 3: SERVICES
-- Servicios para cada provider activo
-- ============================================================================

INSERT INTO public.services (id, provider_id, name, description, duration_minutes, price, tier, active)
SELECT gen_random_uuid(), p.id, 'Consulta General', 'Consulta médica general', 30, 50.00, 'standard', true
FROM public.providers p
WHERE p.slug IN ('dr-alejandro-vera', 'dra-carmen-luz', 'dr-roberto-fuentes', 'dra-lucia-mendez', 'dr-schedule-test', 'dr-weekend-only', 'dr-night-shift')
  AND NOT EXISTS (SELECT 1 FROM public.services s WHERE s.provider_id = p.id AND s.name = 'Consulta General');

INSERT INTO public.services (id, provider_id, name, description, duration_minutes, price, tier, active)
SELECT gen_random_uuid(), p.id, 'Consulta Especializada', 'Consulta con especialista', 45, 80.00, 'premium', true
FROM public.providers p
WHERE p.slug IN ('dr-alejandro-vera', 'dra-carmen-luz', 'dr-roberto-fuentes', 'dr-schedule-test')
  AND NOT EXISTS (SELECT 1 FROM public.services s WHERE s.provider_id = p.id AND s.name = 'Consulta Especializada');

INSERT INTO public.services (id, provider_id, name, description, duration_minutes, price, tier, active)
SELECT gen_random_uuid(), p.id, 'Urgencia', 'Atención de urgencia', 20, 120.00, 'emergency', true
FROM public.providers p
WHERE p.slug IN ('dr-alejandro-vera', 'dra-carmen-luz', 'dra-lucia-mendez', 'dr-schedule-test')
  AND NOT EXISTS (SELECT 1 FROM public.services s WHERE s.provider_id = p.id AND s.name = 'Urgencia');
