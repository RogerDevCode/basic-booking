-- ============================================================================
-- SEED DATA - Part 5: BOOKINGS
-- Reservas con diferentes estados y fechas
-- NOTA: Ejecutar después de providers y services
-- ============================================================================

-- Obtener IDs necesarios para las reservas
DO $$
DECLARE
    v_user_1 uuid;
    v_user_2 uuid;
    v_user_3 uuid;
    v_user_4 uuid;
    v_user_5 uuid;
    v_user_6 uuid;
    v_provider_1 uuid;
    v_provider_2 uuid;
    v_provider_3 uuid;
    v_service_general_1 uuid;
    v_service_general_2 uuid;
    v_service_special_1 uuid;
    v_service_urgency_1 uuid;
    v_service_general_3 uuid;
BEGIN
    -- Obtener user IDs
    SELECT id INTO v_user_1 FROM public.users WHERE telegram_id = 3000001;
    SELECT id INTO v_user_2 FROM public.users WHERE telegram_id = 3000002;
    SELECT id INTO v_user_3 FROM public.users WHERE telegram_id = 3000003;
    SELECT id INTO v_user_4 FROM public.users WHERE telegram_id = 3000004;
    SELECT id INTO v_user_5 FROM public.users WHERE telegram_id = 3000005;
    SELECT id INTO v_user_6 FROM public.users WHERE telegram_id = 3000006;
    
    -- Obtener provider IDs
    SELECT id INTO v_provider_1 FROM public.providers WHERE slug = 'dr-alejandro-vera';
    SELECT id INTO v_provider_2 FROM public.providers WHERE slug = 'dra-carmen-luz';
    SELECT id INTO v_provider_3 FROM public.providers WHERE slug = 'dr-roberto-fuentes';
    
    -- Obtener service IDs
    SELECT id INTO v_service_general_1 FROM public.services WHERE provider_id = v_provider_1 AND name = 'Consulta General';
    SELECT id INTO v_service_special_1 FROM public.services WHERE provider_id = v_provider_1 AND name = 'Consulta Especializada';
    SELECT id INTO v_service_urgency_1 FROM public.services WHERE provider_id = v_provider_1 AND name = 'Urgencia';
    SELECT id INTO v_service_general_2 FROM public.services WHERE provider_id = v_provider_2 AND name = 'Consulta General';
    SELECT id INTO v_service_general_3 FROM public.services WHERE provider_id = v_provider_3 AND name = 'Consulta General';
    
    -- Reserva confirmada futura
    IF v_user_1 IS NOT NULL AND v_provider_1 IS NOT NULL AND v_service_general_1 IS NOT NULL THEN
        INSERT INTO public.bookings (id, user_id, provider_id, service_id, start_time, end_time, status, notes, created_at, updated_at)
        VALUES (
            gen_random_uuid(), v_user_1, v_provider_1, v_service_general_1,
            NOW() + INTERVAL '2 days' + INTERVAL '10 hours',
            NOW() + INTERVAL '2 days' + INTERVAL '10.5 hours',
            'confirmed', 'Reserva de prueba - futura confirmada', NOW(), NOW()
        );
    END IF;
    
    -- Segunda reserva confirmada
    IF v_user_2 IS NOT NULL AND v_provider_1 IS NOT NULL AND v_service_special_1 IS NOT NULL THEN
        INSERT INTO public.bookings (id, user_id, provider_id, service_id, start_time, end_time, status, notes, created_at, updated_at)
        VALUES (
            gen_random_uuid(), v_user_2, v_provider_1, v_service_special_1,
            NOW() + INTERVAL '3 days' + INTERVAL '14 hours',
            NOW() + INTERVAL '3 days' + INTERVAL '14.75 hours',
            'confirmed', 'Consulta especializada - futura', NOW(), NOW()
        );
    END IF;
    
    -- Reserva pendiente
    IF v_user_3 IS NOT NULL AND v_provider_2 IS NOT NULL AND v_service_general_2 IS NOT NULL THEN
        INSERT INTO public.bookings (id, user_id, provider_id, service_id, start_time, end_time, status, notes, created_at, updated_at)
        VALUES (
            gen_random_uuid(), v_user_3, v_provider_2, v_service_general_2,
            NOW() + INTERVAL '5 days' + INTERVAL '11 hours',
            NOW() + INTERVAL '5 days' + INTERVAL '11.75 hours',
            'pending', 'Reserva pendiente de confirmación', NOW(), NOW()
        );
    END IF;
    
    -- Reserva cancelada
    IF v_user_4 IS NOT NULL AND v_provider_1 IS NOT NULL AND v_service_general_1 IS NOT NULL THEN
        INSERT INTO public.bookings (id, user_id, provider_id, service_id, start_time, end_time, status, notes, created_at, updated_at)
        VALUES (
            gen_random_uuid(), v_user_4, v_provider_1, v_service_general_1,
            NOW() + INTERVAL '1 day' + INTERVAL '9 hours',
            NOW() + INTERVAL '1 day' + INTERVAL '9.5 hours',
            'cancelled', 'CANCELADA - Usuario solicitó cancelación', NOW() - INTERVAL '2 days', NOW()
        );
    END IF;
    
    -- Reserva completada (pasada)
    IF v_user_5 IS NOT NULL AND v_provider_1 IS NOT NULL AND v_service_urgency_1 IS NOT NULL THEN
        INSERT INTO public.bookings (id, user_id, provider_id, service_id, start_time, end_time, status, notes, created_at, updated_at)
        VALUES (
            gen_random_uuid(), v_user_5, v_provider_1, v_service_urgency_1,
            NOW() - INTERVAL '7 days' + INTERVAL '15 hours',
            NOW() - INTERVAL '7 days' + INTERVAL '15.33 hours',
            'completed', 'Atención completada exitosamente', NOW() - INTERVAL '10 days', NOW() - INTERVAL '7 days'
        );
    END IF;
    
    -- Reserva no-show
    IF v_user_6 IS NOT NULL AND v_provider_2 IS NOT NULL AND v_service_general_2 IS NOT NULL THEN
        INSERT INTO public.bookings (id, user_id, provider_id, service_id, start_time, end_time, status, notes, created_at, updated_at)
        VALUES (
            gen_random_uuid(), v_user_6, v_provider_2, v_service_general_2,
            NOW() - INTERVAL '3 days' + INTERVAL '10 hours',
            NOW() - INTERVAL '3 days' + INTERVAL '10.75 hours',
            'no_show', 'NO_SHOW - Cliente no asistió', NOW() - INTERVAL '5 days', NOW() - INTERVAL '3 days'
        );
    END IF;
    
    -- Reserva rescheduled
    IF v_user_1 IS NOT NULL AND v_provider_3 IS NOT NULL AND v_service_general_3 IS NOT NULL THEN
        INSERT INTO public.bookings (id, user_id, provider_id, service_id, start_time, end_time, status, notes, created_at, updated_at)
        VALUES (
            gen_random_uuid(), v_user_1, v_provider_3, v_service_general_3,
            NOW() + INTERVAL '10 days' + INTERVAL '16 hours',
            NOW() + INTERVAL '10 days' + INTERVAL '17 hours',
            'rescheduled', 'REPROGRAMADA', NOW() - INTERVAL '1 day', NOW()
        );
    END IF;
    
    RAISE NOTICE 'Bookings insertados correctamente';
END $$;
