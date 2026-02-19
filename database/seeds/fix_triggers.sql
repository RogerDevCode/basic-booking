-- ============================================================================
-- FIX TRIGGERS - Corregir funciones de locking
-- ============================================================================

-- 1. Eliminar trigger primero
DROP TRIGGER IF EXISTS trg_check_overlap_with_lock ON public.bookings;

-- 2. Eliminar función con lock problemático
DROP FUNCTION IF EXISTS public.check_booking_overlap_with_lock();
DROP FUNCTION IF EXISTS public.acquire_booking_lock(uuid, timestamp with time zone, integer);

-- 3. Crear función acquire_booking_lock corregida
CREATE FUNCTION public.acquire_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone, p_timeout_seconds integer DEFAULT 30) 
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    lock_key bigint;
    lock_acquired boolean;
    expiry_time timestamp with time zone;
    hash_text text;
BEGIN
    hash_text := p_provider_id::text || p_start_time::text;
    lock_key := ('x' || substring(encode(sha256(hash_text::bytea), 'hex'), 1, 15))::bit(64)::bigint;
    
    expiry_time := NOW() + (p_timeout_seconds || ' seconds')::interval;
    
    WHILE NOW() < expiry_time LOOP
        SELECT pg_try_advisory_xact_lock(lock_key) INTO lock_acquired;
        
        IF lock_acquired THEN
            RETURN true;
        END IF;
        
        PERFORM pg_sleep(0.01);
    END LOOP;
    
    RETURN false;
END;
$$;

-- 4. Crear función check_booking_overlap_with_lock corregida
CREATE FUNCTION public.check_booking_overlap_with_lock() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    lock_acquired boolean;
    lock_key bigint;
    hash_text text;
BEGIN
    hash_text := NEW.provider_id::text || NEW.start_time::text;
    lock_key := ('x' || substring(encode(sha256(hash_text::bytea), 'hex'), 1, 15))::bit(64)::bigint;
    
    SELECT pg_try_advisory_xact_lock(lock_key) INTO lock_acquired;
    
    IF NOT lock_acquired THEN
        RAISE EXCEPTION 'SLOT_LOCKED: Another transaction is processing this slot. Please retry.';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM bookings
        WHERE provider_id = NEW.provider_id
          AND status != 'cancelled'
          AND tstzrange(start_time, end_time) && tstzrange(NEW.start_time, NEW.end_time)
          AND (NEW.id IS NULL OR id != NEW.id)
    ) THEN
        RAISE EXCEPTION 'SLOT_OCCUPIED: Overlapping booking detected.';
    END IF;
    
    RETURN NEW;
END;
$$;

-- 5. Recrear el trigger
CREATE TRIGGER trg_check_overlap_with_lock
    BEFORE INSERT OR UPDATE ON public.bookings
    FOR EACH ROW
    EXECUTE FUNCTION public.check_booking_overlap_with_lock();

SELECT 'Triggers corregidos' as status;
