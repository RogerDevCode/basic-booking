-- ============================================================================
-- FIX schema.sql - Corregir función check_booking_lock
-- Esta función tiene el cálculo de lock_key incorrecto que causa:
-- ERROR: invalid input syntax for type bigint
-- ============================================================================

DROP FUNCTION IF EXISTS public.check_booking_lock(uuid, timestamp with time zone);

CREATE FUNCTION public.check_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone) 
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    lock_key bigint;
    lock_held boolean;
    hash_text text;
BEGIN
    hash_text := p_provider_id::text || p_start_time::text;
    lock_key := ('x' || substring(encode(sha256(hash_text::bytea), 'hex'), 1, 15))::bit(64)::bigint;
    
    SELECT pg_try_advisory_xact_lock(lock_key) INTO lock_held;
    
    IF lock_held THEN
        PERFORM pg_advisory_unlock_xact(lock_key);
        RETURN false;
    ELSE
        RETURN true;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.check_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone) 
IS 'Checks if an advisory lock is held. For debugging purposes.';

SELECT 'Función check_booking_lock corregida' as status;
