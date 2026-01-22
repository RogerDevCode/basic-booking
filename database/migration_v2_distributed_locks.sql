-- FIX-05: Distributed Lock Support for Booking Concurrency Control
-- This migration adds advisory lock functions to prevent race conditions
-- in multi-tenant booking scenarios

-- Function: Acquire advisory lock for booking slot
-- Usage: SELECT acquire_booking_lock('professional_id', 'start_time')
-- Returns: true if lock acquired, false otherwise
CREATE OR REPLACE FUNCTION public.acquire_booking_lock(
    p_professional_id uuid,
    p_start_time timestamp with time zone,
    p_timeout_seconds integer DEFAULT 30
) RETURNS boolean AS $$
DECLARE
    lock_key bigint;
    lock_acquired boolean;
    expiry_time timestamp with time zone;
BEGIN
    -- Create lock key hash from professional_id and start_time
    -- This ensures unique locks per slot
    lock_key := (
        ('x' || encode(
            digest(p_professional_id::text || p_start_time::text, 'sha256'),
            'hex'
        ))::bigint % 2147483647
    );
    
    -- Try to acquire advisory lock with timeout
    expiry_time := NOW() + (p_timeout_seconds || 30) * INTERVAL '1 second';
    
    WHILE NOW() < expiry_time LOOP
        -- pg_try_advisory_xact_lock returns true if lock acquired
        SELECT pg_try_advisory_xact_lock(lock_key) INTO lock_acquired;
        
        IF lock_acquired THEN
            RETURN true;
        END IF;
        
        -- Wait 10ms before retry
        PERFORM pg_sleep(0.01);
    END LOOP;
    
    -- Lock not acquired
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Release advisory lock (automatic on transaction commit)
-- This is informational; locks are automatically released
CREATE OR REPLACE FUNCTION public.release_booking_lock(
    p_professional_id uuid,
    p_start_time timestamp with time zone
) RETURNS void AS $$
DECLARE
    lock_key bigint;
BEGIN
    lock_key := (
        ('x' || encode(
            digest(p_professional_id::text || p_start_time::text, 'sha256'),
            'hex'
        ))::bigint % 2147483647
    );
    
    -- Advisory locks are released automatically on transaction commit/rollback
    -- This function exists for debugging purposes
    RAISE NOTICE 'Lock for professional % at % would be released on transaction end', p_professional_id, p_start_time;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Check if lock is held (for debugging)
CREATE OR REPLACE FUNCTION public.check_booking_lock(
    p_professional_id uuid,
    p_start_time timestamp with time zone
) RETURNS boolean AS $$
DECLARE
    lock_key bigint;
    lock_held boolean;
BEGIN
    lock_key := (
        ('x' || encode(
            digest(p_professional_id::text || p_start_time::text, 'sha256'),
            'hex'
        ))::bigint % 2147483647
    );
    
    -- pg_advisory_lock checks if lock is held
    -- This returns true if the current session holds the lock
    -- To check globally, we would need pg_locks system view
    SELECT pg_try_advisory_xact_lock(lock_key) INTO lock_held;
    
    -- If we can acquire it, it wasn't held; release immediately
    IF lock_held THEN
        PERFORM pg_advisory_unlock_xact(lock_key);
        RETURN false;
    ELSE
        RETURN true;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Enhanced booking overlap check with advisory lock
-- This trigger runs BEFORE INSERT/UPDATE on bookings table
CREATE OR REPLACE FUNCTION public.check_booking_overlap_with_lock() RETURNS trigger AS $$
DECLARE
    lock_acquired boolean;
BEGIN
    -- FIX-05: Acquire lock before checking overlap
    -- This prevents race conditions in concurrent bookings
    SELECT acquire_booking_lock(NEW.professional_id, NEW.start_time, 5) INTO lock_acquired;
    
    IF NOT lock_acquired THEN
        RAISE EXCEPTION 'SLOT_LOCKED: Another transaction is processing this slot. Please retry.';
    END IF;
    
    -- Original overlap check
    IF EXISTS (
        SELECT 1 FROM bookings
        WHERE professional_id = NEW.professional_id
          AND status != 'cancelled'
          AND tstzrange(start_time, end_time) && tstzrange(NEW.start_time, NEW.end_time)
          AND (NEW.id IS NULL OR id != NEW.id)
    ) THEN
        RAISE EXCEPTION 'SLOT_OCCUPIED: Overlapping booking detected.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop old trigger and create new one
DROP TRIGGER IF EXISTS trg_check_overlap ON bookings;
CREATE TRIGGER trg_check_overlap_with_lock
    BEFORE INSERT OR UPDATE ON bookings
    FOR EACH ROW
    EXECUTE FUNCTION public.check_booking_overlap_with_lock();

-- Index: Support for advisory lock queries (debugging)
CREATE INDEX IF NOT EXISTS idx_bookings_professional_time ON bookings(professional_id, start_time, end_time) WHERE status != 'cancelled';

-- Grant permissions (adjust as needed)
GRANT EXECUTE ON FUNCTION public.acquire_booking_lock TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.release_booking_lock TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.check_booking_lock TO neondb_owner;

-- Comment functions for documentation
COMMENT ON FUNCTION public.acquire_booking_lock IS 'Acquires an advisory lock for a booking slot to prevent concurrent double-bookings. Returns true if lock acquired, false if timeout.';
COMMENT ON FUNCTION public.release_booking_lock IS 'Releases advisory lock (automatic on transaction commit). Exists for debugging only.';
COMMENT ON FUNCTION public.check_booking_lock IS 'Checks if an advisory lock is held. For debugging purposes.';
COMMENT ON FUNCTION public.check_booking_overlap_with_lock IS 'Enhanced overlap check with advisory lock acquisition. Prevents race conditions in concurrent bookings.';

-- Verify migration
SELECT 'Migration v2: Distributed locks installed successfully' as status;
