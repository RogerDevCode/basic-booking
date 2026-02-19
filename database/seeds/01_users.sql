-- ============================================================================
-- SEED DATA - Part 1: USERS
-- Usuarios con diferentes estados y roles
-- ============================================================================

INSERT INTO public.users (id, telegram_id, first_name, last_name, username, phone_number, rut, role, language_code, metadata, created_at, updated_at, deleted_at)
VALUES
    ('a1b2c3d4-e5f6-7890-abcd-000000000001', 3000001, 'Juan', 'Pérez', 'juan_perez', '+56912345678', '12345678-9', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '30 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000002', 3000002, 'María', 'González', 'maria_g', '+56923456789', '98765432-1', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '25 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000003', 3000003, 'Carlos', 'López', 'carlos_loy', '+56934567890', '11222333-4', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '20 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000004', 3000004, 'Ana', 'Martínez', 'ana_m', '+56945678901', '44555666-7', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '15 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000005', 3000005, 'Pedro', 'Sánchez', 'pedro_s', '+56956789012', '77888999-0', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '10 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000006', 3000006, 'Laura', 'Fernández', 'lauraf', '+56967890123', '11122333-4', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '8 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000007', 3000007, 'Diego', 'Rodríguez', 'diego_r', '+56978901234', '44555666-7', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '5 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000008', 3000008, 'Sofia', 'Díaz', 'sofia_d', '+56989012345', NULL, 'user', 'en', '{"source": "seed_test", "international": true}', NOW() - INTERVAL '3 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000009', 3000009, 'Miguel', 'Hernández', 'miguel_h', '+56990123456', '99887766-5', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '2 days', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000010', 3000010, 'Carmen', 'Ruiz', 'carmen_r', '+56901234567', '55443322-1', 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '1 day', NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000011', 3000011, 'José María', 'De la Cruz', 'jose_maria', NULL, NULL, 'user', 'es', '{"source": "seed_test"}', NOW(), NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000012', 3000012, 'François', 'Müller', 'francois_ms', NULL, NULL, 'user', 'en', '{"source": "seed_test"}', NOW(), NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000014', 3000014, 'User Strike 1', 'Test', 'strike_1', NULL, NULL, 'user', 'es', '{"source": "seed_test"}', NOW(), NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000015', 3000015, 'User Strike 3', 'Test', 'strike_3', NULL, NULL, 'user', 'es', '{"source": "seed_test"}', NOW(), NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000016', 3000016, 'User Strike 5', 'Test', 'strike_5', NULL, NULL, 'user', 'es', '{"source": "seed_test"}', NOW(), NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000017', 3000017, 'Deleted User', 'Test', 'deleted_user', NULL, NULL, 'user', 'es', '{"source": "seed_test"}', NOW() - INTERVAL '10 days', NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days'),
    ('a1b2c3d4-e5f6-7890-abcd-000000000018', 3000018, 'Load Test', 'User 1', 'load_1', NULL, NULL, 'user', 'es', '{"source": "seed_test"}', NOW(), NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000019', 3000019, 'Load Test', 'User 2', 'load_2', NULL, NULL, 'user', 'es', '{"source": "seed_test"}', NOW(), NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000020', 3000020, 'Load Test', 'User 3', 'load_3', NULL, NULL, 'user', 'es', '{"source": "seed_test"}', NOW(), NOW(), NULL),
    ('a1b2c3d4-e5f6-7890-abcd-000000000021', 3000021, 'Admin', 'Test', 'admin_test', NULL, NULL, 'admin', 'es', '{"source": "seed_test"}', NOW(), NOW(), NULL)
ON CONFLICT (telegram_id) DO NOTHING;
