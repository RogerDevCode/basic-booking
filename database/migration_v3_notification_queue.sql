-- FIX-06: Notification Queue for Retry Worker
-- This migration creates the notification_queue table for async notifications
-- with retry support and deduplication

-- Create notification_queue table
CREATE TABLE IF NOT EXISTS public.notification_queue (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    booking_id uuid,
    user_id uuid,
    message text NOT NULL,
    priority integer DEFAULT 0,
    status public.notification_status DEFAULT 'pending',
    retry_count integer DEFAULT 0,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    sent_at timestamp with time zone,
    CONSTRAINT notification_queue_check CHECK ((status = 'pending'::public.notification_status) OR (status = 'sent'::public.notification_status) OR (status = 'failed'::public.notification_status)),
    CONSTRAINT notification_queue_retry_count_check CHECK ((retry_count >= 0) AND (retry_count <= 10))
);

-- Create notification_status enum type
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_status') THEN
        CREATE TYPE public.notification_status AS ENUM ('pending', 'sent', 'failed');
    END IF;
END $$;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_notification_queue_status ON public.notification_queue(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_notification_queue_user_id ON public.notification_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_booking_id ON public.notification_queue(booking_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_priority ON public.notification_queue(priority DESC, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_notification_queue_created_at ON public.notification_queue(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_queue_retry ON public.notification_queue(status, retry_count) WHERE status = 'pending' AND retry_count < 3;

-- Function: Add notification to queue
CREATE OR REPLACE FUNCTION public.queue_notification(
    p_booking_id uuid,
    p_user_id uuid,
    p_message text,
    p_priority integer DEFAULT 0
) RETURNS uuid AS $$
DECLARE
    v_id uuid;
BEGIN
    -- Check if notification already queued for this booking
    SELECT id INTO v_id
    FROM notification_queue
    WHERE booking_id = p_booking_id
      AND status = 'pending'
      AND created_at > NOW() - INTERVAL '5 minutes'
    LIMIT 1;
    
    IF v_id IS NOT NULL THEN
        RETURN v_id; -- Return existing notification ID (deduplication)
    END IF;
    
    -- Insert new notification
    INSERT INTO notification_queue (booking_id, user_id, message, priority)
    VALUES (p_booking_id, p_user_id, p_message, p_priority)
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Process pending notifications
-- This is called by BB_07 retry worker
CREATE OR REPLACE FUNCTION public.process_pending_notifications(
    p_limit integer DEFAULT 50,
    p_max_age_hours integer DEFAULT 24
) RETURNS TABLE (
    id uuid,
    booking_id uuid,
    user_id uuid,
    message text,
    retry_count integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT id, booking_id, user_id, message, retry_count
    FROM notification_queue
    WHERE status = 'pending'
      AND retry_count < 3
      AND created_at > NOW() - (p_max_age_hours || ' hours')::interval
    ORDER BY priority DESC, created_at ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Mark notification as sent
CREATE OR REPLACE FUNCTION public.mark_notification_sent(
    p_id uuid
) RETURNS void AS $$
BEGIN
    UPDATE notification_queue
    SET status = 'sent',
        sent_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Mark notification as failed
CREATE OR REPLACE FUNCTION public.mark_notification_failed(
    p_id uuid,
    p_error_message text
) RETURNS void AS $$
DECLARE
    v_retry_count integer;
BEGIN
    -- Get current retry count
    SELECT retry_count INTO v_retry_count
    FROM notification_queue
    WHERE id = p_id;
    
    -- Increment retry count
    UPDATE notification_queue
    SET retry_count = v_retry_count + 1,
        error_message = p_error_message,
        updated_at = NOW(),
        status = CASE 
            WHEN v_retry_count + 1 >= 3 THEN 'failed'
            ELSE 'pending'
        END
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger: Auto-update updated_at
CREATE OR REPLACE FUNCTION public.update_notification_queue_timestamp() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_notification_queue_update_timestamp
    BEFORE UPDATE ON notification_queue
    FOR EACH ROW
    EXECUTE FUNCTION public.update_notification_queue_timestamp();

-- Cleanup function: Delete old sent notifications
CREATE OR REPLACE FUNCTION public.cleanup_old_notifications(
    p_days_to_keep integer DEFAULT 30
) RETURNS integer AS $$
DECLARE
    v_deleted_count integer;
BEGIN
    DELETE FROM notification_queue
    WHERE status = 'sent'
      AND sent_at < NOW() - (p_days_to_keep || ' days')::interval;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT ALL ON TABLE public.notification_queue TO neondb_owner;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.queue_notification TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.process_pending_notifications TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.mark_notification_sent TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.mark_notification_failed TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.cleanup_old_notifications TO neondb_owner;

-- Comments for documentation
COMMENT ON TABLE public.notification_queue IS 'Queue for asynchronous notifications with retry support. Processed by BB_07 retry worker.';
COMMENT ON FUNCTION public.queue_notification IS 'Adds a notification to the queue. Deduplicates if notification already queued for same booking within 5 minutes.';
COMMENT ON FUNCTION public.process_pending_notifications IS 'Returns pending notifications for processing. Called by BB_07 retry worker.';
COMMENT ON FUNCTION public.mark_notification_sent IS 'Marks a notification as successfully sent.';
COMMENT ON FUNCTION public.mark_notification_failed IS 'Marks a notification as failed and increments retry count. Changes status to failed after 3 retries.';
COMMENT ON FUNCTION public.cleanup_old_notifications IS 'Deletes old sent notifications to keep table size manageable.';

-- Verify migration
SELECT 'Migration v3: Notification queue installed successfully' as status;
