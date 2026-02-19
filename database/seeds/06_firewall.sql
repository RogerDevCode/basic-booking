-- ============================================================================
-- SEED DATA - Part 6: SECURITY_FIREWALL
-- Estados de firewall para testing
-- ============================================================================

INSERT INTO public.security_firewall (id, entity_id, strike_count, is_blocked, blocked_until, last_strike_at, created_at, updated_at)
VALUES
    (gen_random_uuid(), 'telegram:3000014', 1, false, NULL, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'telegram:3000015', 3, false, NULL, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'telegram:3000016', 5, true, NOW() + INTERVAL '2 hours', NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'telegram:999999001', 0, false, NULL, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'telegram:999999002', 10, true, NULL, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'ip:192.168.1.100', 2, false, NULL, NOW(), NOW(), NOW()),
    (gen_random_uuid(), 'ip:10.0.0.50', 7, true, NOW() + INTERVAL '24 hours', NOW(), NOW(), NOW())
ON CONFLICT DO NOTHING;
