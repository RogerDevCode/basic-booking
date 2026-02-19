--
-- PostgreSQL database dump
--

\restrict 4L2uxobDP2tc8skXkDbO2x5ohsFYKM4SNH9aHPrln5OpK0ZMcWS7Lnyt5RfEF1G

-- Dumped from database version 17.7 (bdd1736)
-- Dumped by pg_dump version 17.7 (Ubuntu 17.7-0ubuntu0.25.10.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: error_handling; Type: SCHEMA; Schema: -; Owner: neondb_owner
--

CREATE SCHEMA error_handling;


ALTER SCHEMA error_handling OWNER TO neondb_owner;

--
-- Name: neon_auth; Type: SCHEMA; Schema: -; Owner: neon_auth
--

CREATE SCHEMA neon_auth;


ALTER SCHEMA neon_auth OWNER TO neon_auth;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: audit_action; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.audit_action AS ENUM (
    'INSERT',
    'UPDATE',
    'SOFT_DELETE',
    'HARD_DELETE',
    'LOGIN_ATTEMPT',
    'SECURITY_BLOCK',
    'DEEP_LINK_ACCESS',
    'DEEP_LINK_FAILURE',
    'ACCESS_CHECK',
    'ACCESS_DENIED'
);


ALTER TYPE public.audit_action OWNER TO neondb_owner;

--
-- Name: booking_status; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.booking_status AS ENUM (
    'pending',
    'confirmed',
    'cancelled',
    'completed',
    'no_show',
    'rescheduled'
);


ALTER TYPE public.booking_status OWNER TO neondb_owner;

--
-- Name: day_of_week; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.day_of_week AS ENUM (
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
);


ALTER TYPE public.day_of_week OWNER TO neondb_owner;

--
-- Name: error_severity; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.error_severity AS ENUM (
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL'
);


ALTER TYPE public.error_severity OWNER TO neondb_owner;

--
-- Name: error_type; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.error_type AS ENUM (
    'VALIDATION',
    'DATABASE',
    'API',
    'NETWORK',
    'LOGIC',
    'UNKNOWN'
);


ALTER TYPE public.error_type OWNER TO neondb_owner;

--
-- Name: notification_status; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.notification_status AS ENUM (
    'pending',
    'sent',
    'failed'
);


ALTER TYPE public.notification_status OWNER TO neondb_owner;

--
-- Name: service_tier; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.service_tier AS ENUM (
    'standard',
    'premium',
    'emergency'
);


ALTER TYPE public.service_tier OWNER TO neondb_owner;

--
-- Name: supported_lang; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.supported_lang AS ENUM (
    'es',
    'en',
    'pt'
);


ALTER TYPE public.supported_lang OWNER TO neondb_owner;

--
-- Name: user_role; Type: TYPE; Schema: public; Owner: neondb_owner
--

CREATE TYPE public.user_role AS ENUM (
    'user',
    'admin',
    'system'
);


ALTER TYPE public.user_role OWNER TO neondb_owner;

--
-- Name: check_error_recurrence(character varying, character varying, text, integer, boolean); Type: FUNCTION; Schema: error_handling; Owner: neondb_owner
--

CREATE FUNCTION error_handling.check_error_recurrence(p_workflow_name character varying, p_error_type character varying, p_error_message text DEFAULT NULL::text, p_time_window_minutes integer DEFAULT 10, p_use_fingerprint boolean DEFAULT true) RETURNS TABLE(occurrence_count integer, is_recurring boolean, severity_recommendation character varying, first_occurrence timestamp with time zone, last_occurrence timestamp with time zone)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_fingerprint VARCHAR(64);
    v_count INTEGER;
    v_first TIMESTAMP WITH TIME ZONE;
    v_last TIMESTAMP WITH TIME ZONE;
    v_severity VARCHAR(20);
BEGIN
    IF p_use_fingerprint AND p_error_message IS NOT NULL THEN
        v_fingerprint := error_handling.generate_error_fingerprint(
            p_workflow_name, 
            p_error_type, 
            p_error_message
        );
        
        SELECT 
            COUNT(*),
            MIN(created_at),
            MAX(created_at)
        INTO v_count, v_first, v_last
        FROM error_handling.error_logs
        WHERE error_fingerprint = v_fingerprint
          AND created_at > NOW() - (p_time_window_minutes || ' minutes')::INTERVAL;
    ELSE
        SELECT 
            COUNT(*),
            MIN(created_at),
            MAX(created_at)
        INTO v_count, v_first, v_last
        FROM error_handling.error_logs
        WHERE workflow_name = p_workflow_name
          AND error_type = p_error_type
          AND created_at > NOW() - (p_time_window_minutes || ' minutes')::INTERVAL;
    END IF;
    
    v_severity := CASE 
        WHEN v_count >= 20 THEN 'CRITICAL'
        WHEN v_count >= 10 THEN 'HIGH'
        WHEN v_count >= 3 THEN 'MEDIUM'
        ELSE 'LOW'
    END;
    
    RETURN QUERY SELECT 
        COALESCE(v_count, 0),
        COALESCE(v_count, 0) >= 3,
        v_severity,
        v_first,
        v_last;
END;
$$;


ALTER FUNCTION error_handling.check_error_recurrence(p_workflow_name character varying, p_error_type character varying, p_error_message text, p_time_window_minutes integer, p_use_fingerprint boolean) OWNER TO neondb_owner;

--
-- Name: cleanup_old_errors(integer); Type: FUNCTION; Schema: error_handling; Owner: neondb_owner
--

CREATE FUNCTION error_handling.cleanup_old_errors(p_days_to_keep integer DEFAULT 30) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM error_handling.error_logs
    WHERE created_at < NOW() - (p_days_to_keep || ' days')::INTERVAL
      AND resolved = TRUE;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN v_deleted_count;
END;
$$;


ALTER FUNCTION error_handling.cleanup_old_errors(p_days_to_keep integer) OWNER TO neondb_owner;

--
-- Name: count_error_recurrences(character varying, character varying, integer); Type: FUNCTION; Schema: error_handling; Owner: neondb_owner
--

CREATE FUNCTION error_handling.count_error_recurrences(p_workflow_name character varying, p_error_type character varying, p_time_window_minutes integer DEFAULT 10) RETURNS integer
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM error_handling.error_logs
    WHERE workflow_name = p_workflow_name
      AND error_type = p_error_type
      AND created_at > NOW() - (p_time_window_minutes || ' minutes')::INTERVAL;
    
    RETURN COALESCE(v_count, 0);
END;
$$;


ALTER FUNCTION error_handling.count_error_recurrences(p_workflow_name character varying, p_error_type character varying, p_time_window_minutes integer) OWNER TO neondb_owner;

--
-- Name: generate_error_fingerprint(text, text, text); Type: FUNCTION; Schema: error_handling; Owner: neondb_owner
--

CREATE FUNCTION error_handling.generate_error_fingerprint(p_workflow_name text, p_error_type text, p_error_message text) RETURNS character varying
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    v_normalized_message TEXT;
    v_fingerprint_source TEXT;
BEGIN
    v_normalized_message := p_error_message;
    v_normalized_message := REGEXP_REPLACE(v_normalized_message, '\d+', 'N', 'g');
    v_normalized_message := REGEXP_REPLACE(v_normalized_message, '[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', 'UUID', 'gi');
    v_normalized_message := REGEXP_REPLACE(v_normalized_message, '[a-f0-9]{32,}', 'HASH', 'gi');
    v_normalized_message := REGEXP_REPLACE(v_normalized_message, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}', 'IP', 'g');
    v_normalized_message := REGEXP_REPLACE(v_normalized_message, '\s+', ' ', 'g');
    v_normalized_message := LEFT(LOWER(TRIM(v_normalized_message)), 200);
    
    v_fingerprint_source := COALESCE(p_workflow_name, '') || ':' || 
                           COALESCE(p_error_type, '') || ':' || 
                           COALESCE(v_normalized_message, '');
    
    RETURN 'fp_' || MD5(v_fingerprint_source);
END;
$$;


ALTER FUNCTION error_handling.generate_error_fingerprint(p_workflow_name text, p_error_type text, p_error_message text) OWNER TO neondb_owner;

--
-- Name: update_updated_at(); Type: FUNCTION; Schema: error_handling; Owner: neondb_owner
--

CREATE FUNCTION error_handling.update_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION error_handling.update_updated_at() OWNER TO neondb_owner;

--
-- Name: acquire_booking_lock(uuid, timestamp with time zone, integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.acquire_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone, p_timeout_seconds integer DEFAULT 30) RETURNS boolean
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


ALTER FUNCTION public.acquire_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone, p_timeout_seconds integer) OWNER TO neondb_owner;

--
-- Name: check_booking_lock(uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.check_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone) RETURNS boolean
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


ALTER FUNCTION public.check_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone) OWNER TO neondb_owner;

--
-- Name: check_booking_overlap(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.check_booking_overlap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
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


ALTER FUNCTION public.check_booking_overlap() OWNER TO neondb_owner;

--
-- Name: check_booking_overlap_with_lock(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

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


ALTER FUNCTION public.check_booking_overlap_with_lock() OWNER TO neondb_owner;

--
-- Name: cleanup_old_notifications(integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.cleanup_old_notifications(p_days_to_keep integer DEFAULT 30) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_deleted_count integer;
BEGIN
    DELETE FROM notification_queue
    WHERE status = 'sent'
      AND sent_at < NOW() - (p_days_to_keep || ' days')::interval;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;


ALTER FUNCTION public.cleanup_old_notifications(p_days_to_keep integer) OWNER TO neondb_owner;

--
-- Name: FUNCTION cleanup_old_notifications(p_days_to_keep integer); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.cleanup_old_notifications(p_days_to_keep integer) IS 'Deletes old sent notifications to keep table size manageable.';


--
-- Name: create_admin_jwt(uuid, integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.create_admin_jwt(p_user_id uuid, p_hours integer) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_payload json;
    -- NOTE: Secret must match N8N env
    v_secret text := 'AutoAgenda_Secret_Key_2026_Secure'; 
BEGIN
    v_payload := json_build_object(
        'user_id', p_user_id,
        'role', 'admin',
        'exp', extract(epoch from now() + (p_hours || ' hours')::interval)::integer
    );
    
    RETURN public.sign_jwt(v_payload, v_secret);
END;
$$;


ALTER FUNCTION public.create_admin_jwt(p_user_id uuid, p_hours integer) OWNER TO neondb_owner;

--
-- Name: create_admin_user(text, text, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.create_admin_user(p_username text, p_password text, p_role text DEFAULT 'admin'::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id uuid;
BEGIN
    INSERT INTO public.admin_users (username, password_hash, role)
    VALUES (
        p_username,
        crypt(p_password, gen_salt('bf')),
        p_role
    )
    RETURNING id INTO v_user_id;
    
    RETURN v_user_id;
END;
$$;


ALTER FUNCTION public.create_admin_user(p_username text, p_password text, p_role text) OWNER TO neondb_owner;

--
-- Name: FUNCTION create_admin_user(p_username text, p_password text, p_role text); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.create_admin_user(p_username text, p_password text, p_role text) IS 'Helper function to create new admin users with hashed passwords. Single-tenant version.';


--
-- Name: create_admin_user(text, text, uuid, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.create_admin_user(p_username text, p_password text, p_tenant_id uuid DEFAULT 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid, p_role text DEFAULT 'admin'::text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_id uuid;
BEGIN
    INSERT INTO public.admin_users (username, password_hash, tenant_id, role)
    VALUES (
        p_username,
        crypt(p_password, gen_salt('bf')),
        p_tenant_id,
        p_role
    )
    RETURNING id INTO v_user_id;
    
    RETURN v_user_id;
END;
$$;


ALTER FUNCTION public.create_admin_user(p_username text, p_password text, p_tenant_id uuid, p_role text) OWNER TO neondb_owner;

--
-- Name: FUNCTION create_admin_user(p_username text, p_password text, p_tenant_id uuid, p_role text); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.create_admin_user(p_username text, p_password text, p_tenant_id uuid, p_role text) IS 'Helper function to create new admin users with hashed passwords.';


--
-- Name: get_app_config_json(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_app_config_json() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
    SELECT jsonb_object_agg(key, value) FROM public.app_config WHERE is_public = true;
$$;


ALTER FUNCTION public.get_app_config_json() OWNER TO neondb_owner;

--
-- Name: get_config(text, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_config(p_key text, p_default text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_val text;
BEGIN
    SELECT value INTO v_val 
    FROM public.app_config 
    WHERE key = p_key;
    
    RETURN COALESCE(v_val, p_default);
END;
$$;


ALTER FUNCTION public.get_config(p_key text, p_default text) OWNER TO neondb_owner;

--
-- Name: FUNCTION get_config(p_key text, p_default text); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.get_config(p_key text, p_default text) IS 'Retrieves configuration value by key. Single-tenant version.';


--
-- Name: get_message(text, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_message(p_code text, p_lang text DEFAULT 'es'::text) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_msg text;
BEGIN
    SELECT message INTO v_msg
    FROM app_messages
    WHERE code = p_code AND lang = p_lang;
    
    IF v_msg IS NULL AND p_lang != 'es' THEN
        SELECT message INTO v_msg
        FROM app_messages
        WHERE code = p_code AND lang = 'es';
    END IF;
    
    RETURN COALESCE(v_msg, p_code);
END;
$$;


ALTER FUNCTION public.get_message(p_code text, p_lang text) OWNER TO neondb_owner;

--
-- Name: FUNCTION get_message(p_code text, p_lang text); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.get_message(p_code text, p_lang text) IS 'Retrieves i18n message by code and language. Single-tenant version.';


--
-- Name: get_public_config_json(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.get_public_config_json() RETURNS jsonb
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_json jsonb;
BEGIN
    SELECT jsonb_object_agg(key, 
        CASE 
            WHEN type = 'number' THEN to_jsonb(value::numeric)
            WHEN type = 'boolean' THEN to_jsonb(value::boolean)
            WHEN type = 'json' THEN value::jsonb
            ELSE to_jsonb(value)
        END
    ) INTO v_json
    FROM public.app_config
    WHERE is_public = true;
    
    RETURN COALESCE(v_json, '{}'::jsonb);
END;
$$;


ALTER FUNCTION public.get_public_config_json() OWNER TO neondb_owner;

--
-- Name: FUNCTION get_public_config_json(); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.get_public_config_json() IS 'Returns all public configuration as JSONB. Single-tenant version.';


--
-- Name: mark_notification_failed(uuid, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.mark_notification_failed(p_id uuid, p_error_message text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_retry_count integer;
BEGIN
    -- Get current retry count
    SELECT retry_count INTO v_retry_count
    FROM notification_queue
    WHERE id = p_id;
    
    -- Increment retry count
    UPDATE notification_queue
    SET retry_count = COALESCE(v_retry_count, 0) + 1,
        error_message = p_error_message,
        updated_at = NOW(),
        status = CASE 
            WHEN COALESCE(v_retry_count, 0) + 1 >= 3 THEN 'failed'::public.notification_status
            ELSE 'pending'::public.notification_status
        END
    WHERE id = p_id;
END;
$$;


ALTER FUNCTION public.mark_notification_failed(p_id uuid, p_error_message text) OWNER TO neondb_owner;

--
-- Name: FUNCTION mark_notification_failed(p_id uuid, p_error_message text); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.mark_notification_failed(p_id uuid, p_error_message text) IS 'Marks a notification as failed and increments retry count. Changes status to failed after 3 retries.';


--
-- Name: mark_notification_sent(uuid); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.mark_notification_sent(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    UPDATE notification_queue
    SET status = 'sent',
        sent_at = NOW(),
        updated_at = NOW()
    WHERE id = p_id;
END;
$$;


ALTER FUNCTION public.mark_notification_sent(p_id uuid) OWNER TO neondb_owner;

--
-- Name: FUNCTION mark_notification_sent(p_id uuid); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.mark_notification_sent(p_id uuid) IS 'Marks a notification as successfully sent.';


--
-- Name: process_pending_notifications(integer, integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.process_pending_notifications(p_limit integer DEFAULT 50, p_max_age_hours integer DEFAULT 24) RETURNS TABLE(id uuid, booking_id uuid, user_id uuid, message text, retry_count integer)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT n.id, n.booking_id, n.user_id, n.message, n.retry_count
    FROM notification_queue n
    WHERE n.status = 'pending'
      AND n.retry_count < 3
      AND n.created_at > NOW() - (p_max_age_hours || ' hours')::interval
    ORDER BY n.priority DESC, n.created_at ASC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION public.process_pending_notifications(p_limit integer, p_max_age_hours integer) OWNER TO neondb_owner;

--
-- Name: FUNCTION process_pending_notifications(p_limit integer, p_max_age_hours integer); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.process_pending_notifications(p_limit integer, p_max_age_hours integer) IS 'Returns pending notifications for processing. Called by BB_07 retry worker.';


--
-- Name: queue_notification(uuid, uuid, text, integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.queue_notification(p_booking_id uuid, p_user_id uuid, p_message text, p_priority integer DEFAULT 0) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION public.queue_notification(p_booking_id uuid, p_user_id uuid, p_message text, p_priority integer) OWNER TO neondb_owner;

--
-- Name: FUNCTION queue_notification(p_booking_id uuid, p_user_id uuid, p_message text, p_priority integer); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.queue_notification(p_booking_id uuid, p_user_id uuid, p_message text, p_priority integer) IS 'Adds a notification to the queue. Deduplicates if notification already queued for same booking within 5 minutes.';


--
-- Name: release_booking_lock(uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.release_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    lock_key bigint;
BEGIN
    lock_key := (
        ('x' || encode(
            digest(p_provider_id::text || p_start_time::text, 'sha256'),
            'hex'
        ))::bigint % 2147483647
    );
    
    PERFORM pg_advisory_unlock_xact(lock_key);
END;
$$;


ALTER FUNCTION public.release_booking_lock(p_provider_id uuid, p_start_time timestamp with time zone) OWNER TO neondb_owner;

--
-- Name: update_modtime(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_modtime() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN 
    NEW.updated_at = NOW(); 
    RETURN NEW; 
END; 
$$;


ALTER FUNCTION public.update_modtime() OWNER TO neondb_owner;

--
-- Name: update_notification_queue_timestamp(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_notification_queue_timestamp() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_notification_queue_timestamp() OWNER TO neondb_owner;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO neondb_owner;

--
-- Name: validate_app_config_availability(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.validate_app_config_availability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  num_value numeric;
BEGIN
  IF NEW.key IN ('BOOKING_WINDOW_DAYS', 'MIN_BOOKING_ADVANCE_HOURS', 'MAX_SLOTS_PER_QUERY', 'DEFAULT_DAYS_RANGE') THEN
    num_value := NEW.value::numeric;

    IF NEW.key = 'BOOKING_WINDOW_DAYS' AND (num_value < 1 OR num_value > 90) THEN
      RAISE EXCEPTION 'BOOKING_WINDOW_DAYS fuera de rango (1-90)';
    END IF;

    IF NEW.key = 'MIN_BOOKING_ADVANCE_HOURS' AND (num_value < 0 OR num_value > 72) THEN
      RAISE EXCEPTION 'MIN_BOOKING_ADVANCE_HOURS fuera de rango (0-72)';
    END IF;

    IF NEW.key = 'MAX_SLOTS_PER_QUERY' AND (num_value < 100 OR num_value > 2000) THEN
      RAISE EXCEPTION 'MAX_SLOTS_PER_QUERY fuera de rango (100-2000)';
    END IF;

    IF NEW.key = 'DEFAULT_DAYS_RANGE' AND (num_value < 1 OR num_value > 30) THEN
      RAISE EXCEPTION 'DEFAULT_DAYS_RANGE fuera de rango (1-30)';
    END IF;
  END IF;

  IF NEW.key = 'TIMEZONE' AND NEW.value !~ '^[A-Za-z]+/[A-Za-z_]+' THEN
    RAISE EXCEPTION 'TIMEZONE debe tener formato Area/Location';
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_app_config_availability() OWNER TO neondb_owner;

--
-- Name: verify_admin_credentials(text, text); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.verify_admin_credentials(p_username text, p_password text) RETURNS TABLE(valid boolean, user_id uuid, role public.user_role)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_user_record record;
BEGIN
    SELECT * INTO v_user_record FROM public.users WHERE username = p_username;
    
    IF v_user_record IS NULL THEN
        RETURN QUERY SELECT false, null::uuid, null::public.user_role;
        RETURN;
    END IF;

    IF v_user_record.password_hash = crypt(p_password, v_user_record.password_hash) THEN
         RETURN QUERY SELECT true, v_user_record.id, v_user_record.role;
    ELSE
         RETURN QUERY SELECT false, null::uuid, null::public.user_role;
    END IF;
END;
$$;


ALTER FUNCTION public.verify_admin_credentials(p_username text, p_password text) OWNER TO neondb_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: error_aggregations; Type: TABLE; Schema: error_handling; Owner: neondb_owner
--

CREATE TABLE error_handling.error_aggregations (
    id bigint NOT NULL,
    workflow_name character varying(255) NOT NULL,
    error_type character varying(100) NOT NULL,
    error_fingerprint character varying(64),
    time_window_start timestamp with time zone NOT NULL,
    time_window_end timestamp with time zone NOT NULL,
    occurrence_count integer DEFAULT 0,
    severity_max character varying(20),
    first_occurrence timestamp with time zone,
    last_occurrence timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE error_handling.error_aggregations OWNER TO neondb_owner;

--
-- Name: error_aggregations_id_seq; Type: SEQUENCE; Schema: error_handling; Owner: neondb_owner
--

CREATE SEQUENCE error_handling.error_aggregations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE error_handling.error_aggregations_id_seq OWNER TO neondb_owner;

--
-- Name: error_aggregations_id_seq; Type: SEQUENCE OWNED BY; Schema: error_handling; Owner: neondb_owner
--

ALTER SEQUENCE error_handling.error_aggregations_id_seq OWNED BY error_handling.error_aggregations.id;


--
-- Name: error_logs; Type: TABLE; Schema: error_handling; Owner: neondb_owner
--

CREATE TABLE error_handling.error_logs (
    id bigint NOT NULL,
    workflow_name character varying(255) NOT NULL,
    error_type character varying(100) NOT NULL,
    error_message text NOT NULL,
    error_fingerprint character varying(64),
    severity character varying(20) DEFAULT 'MEDIUM'::character varying,
    occurrences integer DEFAULT 1,
    metadata jsonb DEFAULT '{}'::jsonb,
    input_data jsonb,
    stack_trace text,
    user_id character varying(100),
    session_id character varying(100),
    environment character varying(50) DEFAULT 'production'::character varying,
    resolved boolean DEFAULT false,
    resolved_at timestamp with time zone,
    resolved_by character varying(100),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE error_handling.error_logs OWNER TO neondb_owner;

--
-- Name: error_logs_id_seq; Type: SEQUENCE; Schema: error_handling; Owner: neondb_owner
--

CREATE SEQUENCE error_handling.error_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE error_handling.error_logs_id_seq OWNER TO neondb_owner;

--
-- Name: error_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: error_handling; Owner: neondb_owner
--

ALTER SEQUENCE error_handling.error_logs_id_seq OWNED BY error_handling.error_logs.id;


--
-- Name: recurrence_config; Type: TABLE; Schema: error_handling; Owner: neondb_owner
--

CREATE TABLE error_handling.recurrence_config (
    id integer NOT NULL,
    workflow_name character varying(255),
    error_type character varying(100),
    time_window_minutes integer DEFAULT 10,
    threshold_low integer DEFAULT 3,
    threshold_medium integer DEFAULT 5,
    threshold_high integer DEFAULT 10,
    threshold_critical integer DEFAULT 20,
    enabled boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE error_handling.recurrence_config OWNER TO neondb_owner;

--
-- Name: recurrence_config_id_seq; Type: SEQUENCE; Schema: error_handling; Owner: neondb_owner
--

CREATE SEQUENCE error_handling.recurrence_config_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE error_handling.recurrence_config_id_seq OWNER TO neondb_owner;

--
-- Name: recurrence_config_id_seq; Type: SEQUENCE OWNED BY; Schema: error_handling; Owner: neondb_owner
--

ALTER SEQUENCE error_handling.recurrence_config_id_seq OWNED BY error_handling.recurrence_config.id;


--
-- Name: v_recurring_errors; Type: VIEW; Schema: error_handling; Owner: neondb_owner
--

CREATE VIEW error_handling.v_recurring_errors AS
 SELECT workflow_name,
    error_type,
    error_fingerprint,
    severity,
    count(*) AS occurrence_count,
    max(created_at) AS last_occurrence,
    min(created_at) AS first_occurrence,
    array_agg(DISTINCT environment) AS environments,
        CASE
            WHEN (count(*) >= 20) THEN 'CRITICAL'::text
            WHEN (count(*) >= 10) THEN 'HIGH'::text
            WHEN (count(*) >= 3) THEN 'MEDIUM'::text
            ELSE 'LOW'::text
        END AS suggested_severity
   FROM error_handling.error_logs el
  WHERE ((created_at > (now() - '00:10:00'::interval)) AND (resolved = false))
  GROUP BY workflow_name, error_type, error_fingerprint, severity
 HAVING (count(*) >= 3);


ALTER VIEW error_handling.v_recurring_errors OWNER TO neondb_owner;

--
-- Name: account; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth.account (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "accountId" text NOT NULL,
    "providerId" text NOT NULL,
    "userId" uuid NOT NULL,
    "accessToken" text,
    "refreshToken" text,
    "idToken" text,
    "accessTokenExpiresAt" timestamp with time zone,
    "refreshTokenExpiresAt" timestamp with time zone,
    scope text,
    password text,
    "createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp with time zone NOT NULL
);


ALTER TABLE neon_auth.account OWNER TO neon_auth;

--
-- Name: invitation; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth.invitation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "organizationId" uuid NOT NULL,
    email text NOT NULL,
    role text,
    status text NOT NULL,
    "expiresAt" timestamp with time zone NOT NULL,
    "createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "inviterId" uuid NOT NULL
);


ALTER TABLE neon_auth.invitation OWNER TO neon_auth;

--
-- Name: jwks; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth.jwks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "publicKey" text NOT NULL,
    "privateKey" text NOT NULL,
    "createdAt" timestamp with time zone NOT NULL,
    "expiresAt" timestamp with time zone
);


ALTER TABLE neon_auth.jwks OWNER TO neon_auth;

--
-- Name: member; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth.member (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "organizationId" uuid NOT NULL,
    "userId" uuid NOT NULL,
    role text NOT NULL,
    "createdAt" timestamp with time zone NOT NULL
);


ALTER TABLE neon_auth.member OWNER TO neon_auth;

--
-- Name: organization; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth.organization (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    logo text,
    "createdAt" timestamp with time zone NOT NULL,
    metadata text
);


ALTER TABLE neon_auth.organization OWNER TO neon_auth;

--
-- Name: project_config; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth.project_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    endpoint_id text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    trusted_origins jsonb NOT NULL,
    social_providers jsonb NOT NULL,
    email_provider jsonb,
    email_and_password jsonb,
    allow_localhost boolean NOT NULL
);


ALTER TABLE neon_auth.project_config OWNER TO neon_auth;

--
-- Name: session; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth.session (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    "expiresAt" timestamp with time zone NOT NULL,
    token text NOT NULL,
    "createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp with time zone NOT NULL,
    "ipAddress" text,
    "userAgent" text,
    "userId" uuid NOT NULL,
    "impersonatedBy" text,
    "activeOrganizationId" text
);


ALTER TABLE neon_auth.session OWNER TO neon_auth;

--
-- Name: user; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth."user" (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    "emailVerified" boolean NOT NULL,
    image text,
    "createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    role text,
    banned boolean,
    "banReason" text,
    "banExpires" timestamp with time zone
);


ALTER TABLE neon_auth."user" OWNER TO neon_auth;

--
-- Name: verification; Type: TABLE; Schema: neon_auth; Owner: neon_auth
--

CREATE TABLE neon_auth.verification (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    identifier text NOT NULL,
    value text NOT NULL,
    "expiresAt" timestamp with time zone NOT NULL,
    "createdAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    "updatedAt" timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE neon_auth.verification OWNER TO neon_auth;

--
-- Name: admin_sessions; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.admin_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    last_used_at timestamp with time zone DEFAULT now(),
    is_revoked boolean DEFAULT false
);


ALTER TABLE public.admin_sessions OWNER TO neondb_owner;

--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.admin_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username character varying(50) NOT NULL,
    password_hash text NOT NULL,
    role character varying(20) DEFAULT 'admin'::character varying,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT admin_users_role_check CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'superadmin'::character varying])::text[])))
);


ALTER TABLE public.admin_users OWNER TO neondb_owner;

--
-- Name: TABLE admin_users; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.admin_users IS 'Admin users for JWT-based authentication to the Admin Dashboard.';


--
-- Name: app_config; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.app_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(100) NOT NULL,
    value text NOT NULL,
    type character varying(20) DEFAULT 'string'::character varying,
    category character varying(50) DEFAULT 'general'::character varying,
    description text,
    is_public boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT app_config_type_check CHECK (((type)::text = ANY ((ARRAY['string'::character varying, 'number'::character varying, 'boolean'::character varying, 'json'::character varying, 'color'::character varying])::text[])))
);


ALTER TABLE public.app_config OWNER TO neondb_owner;

--
-- Name: TABLE app_config; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.app_config IS 'Global application configuration key-value store. Single-tenant architecture.';


--
-- Name: app_messages; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.app_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    lang character varying(10) DEFAULT 'es'::character varying NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.app_messages OWNER TO neondb_owner;

--
-- Name: TABLE app_messages; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.app_messages IS 'Internationalization (i18n) message repository. Single-tenant architecture.';


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    table_name text NOT NULL,
    record_id uuid NOT NULL,
    action public.audit_action NOT NULL,
    old_values jsonb,
    new_values jsonb,
    performed_by text DEFAULT 'system'::text,
    ip_address inet,
    created_at timestamp with time zone DEFAULT now(),
    event_type text,
    event_data jsonb
);


ALTER TABLE public.audit_logs OWNER TO neondb_owner;

--
-- Name: TABLE audit_logs; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.audit_logs IS 'Audit trail for all critical operations. Tracks INSERT, UPDATE, SOFT_DELETE, HARD_DELETE, and security events.';


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.bookings (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    provider_id uuid NOT NULL,
    service_id uuid,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone NOT NULL,
    status public.booking_status DEFAULT 'confirmed'::public.booking_status,
    gcal_event_id text,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    reminder_1_sent_at timestamp with time zone,
    reminder_2_sent_at timestamp with time zone,
    CONSTRAINT valid_booking_time CHECK ((end_time > start_time))
);


ALTER TABLE public.bookings OWNER TO neondb_owner;

--
-- Name: TABLE bookings; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.bookings IS 'Booking transactions. Links users, resources, and services. Syncs with Google Calendar via gcal_event_id. Single-tenant architecture.';


--
-- Name: circuit_breaker_state; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.circuit_breaker_state (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    workflow_name character varying(200) NOT NULL,
    state character varying(20) DEFAULT 'CLOSED'::character varying,
    failure_count integer DEFAULT 0,
    last_failure_at timestamp with time zone,
    opened_at timestamp with time zone,
    next_attempt_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT circuit_breaker_state_state_check CHECK (((state)::text = ANY ((ARRAY['CLOSED'::character varying, 'OPEN'::character varying, 'HALF_OPEN'::character varying])::text[])))
);


ALTER TABLE public.circuit_breaker_state OWNER TO neondb_owner;

--
-- Name: error_metrics; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.error_metrics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    metric_date date NOT NULL,
    workflow_name character varying(200) NOT NULL,
    severity character varying(20) NOT NULL,
    error_count integer DEFAULT 0,
    first_occurrence timestamp with time zone,
    last_occurrence timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.error_metrics OWNER TO neondb_owner;

--
-- Name: notification_configs; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.notification_configs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reminder_1_hours integer DEFAULT 24,
    reminder_2_hours integer DEFAULT 2,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    default_duration_min integer DEFAULT 30,
    min_duration_min integer DEFAULT 15,
    max_duration_min integer DEFAULT 120,
    CONSTRAINT notification_configs_check CHECK ((max_duration_min >= min_duration_min)),
    CONSTRAINT notification_configs_default_duration_min_check CHECK ((default_duration_min > 0)),
    CONSTRAINT notification_configs_min_duration_min_check CHECK ((min_duration_min > 0)),
    CONSTRAINT notification_configs_reminder_1_hours_check CHECK ((reminder_1_hours > 0)),
    CONSTRAINT notification_configs_reminder_2_hours_check CHECK ((reminder_2_hours > 0))
);


ALTER TABLE public.notification_configs OWNER TO neondb_owner;

--
-- Name: notification_queue; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.notification_queue (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid,
    user_id uuid,
    message text NOT NULL,
    priority integer DEFAULT 0,
    status public.notification_status DEFAULT 'pending'::public.notification_status,
    retry_count integer DEFAULT 0,
    error_message text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    sent_at timestamp with time zone,
    next_retry_at timestamp with time zone,
    channel character varying(50) DEFAULT 'telegram'::character varying,
    recipient text,
    payload jsonb DEFAULT '{}'::jsonb,
    max_retries integer DEFAULT 3,
    expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval),
    CONSTRAINT notification_queue_retry_count_check CHECK (((retry_count >= 0) AND (retry_count <= 10)))
);


ALTER TABLE public.notification_queue OWNER TO neondb_owner;

--
-- Name: TABLE notification_queue; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.notification_queue IS 'Queue for asynchronous notifications with retry support. Processed by BB_07 retry worker.';


--
-- Name: provider_cache; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.provider_cache (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_id uuid NOT NULL,
    provider_slug text NOT NULL,
    data jsonb NOT NULL,
    cached_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.provider_cache OWNER TO neondb_owner;

--
-- Name: providers; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.providers (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid,
    name text NOT NULL,
    email public.citext,
    google_calendar_id text,
    slot_duration_minutes integer DEFAULT 30,
    min_notice_hours integer DEFAULT 2,
    public_booking_enabled boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    slug text,
    slot_duration_mins integer DEFAULT 30 NOT NULL,
    CONSTRAINT check_min_notice_positive CHECK ((min_notice_hours >= 0)),
    CONSTRAINT check_provider_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0)),
    CONSTRAINT check_slot_duration_positive CHECK ((slot_duration_minutes > 0)),
    CONSTRAINT check_slug_format CHECK ((slug ~* '^[a-z0-9-]+$'::text)),
    CONSTRAINT valid_slot_duration CHECK (((slot_duration_mins >= 5) AND (slot_duration_mins <= 480)))
);


ALTER TABLE public.providers OWNER TO neondb_owner;

--
-- Name: TABLE providers; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.providers IS 'Service providers (specialists, practitioners). Modern single-tenant architecture with respectful terminology.';


--
-- Name: schedules; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.schedules (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    provider_id uuid NOT NULL,
    day_of_week public.day_of_week NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    is_active boolean DEFAULT true,
    CONSTRAINT valid_shift CHECK ((end_time > start_time))
);


ALTER TABLE public.schedules OWNER TO neondb_owner;

--
-- Name: TABLE schedules; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.schedules IS 'Weekly availability schedules for professionals. Defines working hours per day of week.';


--
-- Name: security_firewall; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.security_firewall (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    entity_id text NOT NULL,
    strike_count integer DEFAULT 0,
    is_blocked boolean DEFAULT false,
    blocked_until timestamp with time zone,
    last_strike_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.security_firewall OWNER TO neondb_owner;

--
-- Name: services; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.services (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    provider_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    duration_minutes integer NOT NULL,
    price numeric(10,2) DEFAULT 0,
    tier public.service_tier DEFAULT 'standard'::public.service_tier,
    active boolean DEFAULT true,
    CONSTRAINT check_duration_positive CHECK ((duration_minutes > 0)),
    CONSTRAINT check_price_non_negative CHECK ((price >= (0)::numeric)),
    CONSTRAINT check_service_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0))
);


ALTER TABLE public.services OWNER TO neondb_owner;

--
-- Name: TABLE services; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.services IS 'Services offered by professionals. Each service has a duration, price, and tier (standard/premium/emergency).';


--
-- Name: system_errors; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.system_errors (
    error_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    workflow_name text,
    workflow_execution_id text,
    error_type text,
    severity text,
    error_message text,
    error_stack text,
    error_context jsonb,
    user_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    resolved_at timestamp with time zone,
    is_resolved boolean DEFAULT false,
    resolution_notes text
);


ALTER TABLE public.system_errors OWNER TO neondb_owner;

--
-- Name: users; Type: TABLE; Schema: public; Owner: neondb_owner
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    telegram_id bigint NOT NULL,
    first_name text,
    last_name text,
    username text,
    phone_number text,
    rut text,
    role public.user_role DEFAULT 'user'::public.user_role,
    language_code public.supported_lang DEFAULT 'es'::public.supported_lang,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    password_hash text,
    last_selected_provider_id uuid,
    CONSTRAINT check_rut_format CHECK (((rut IS NULL) OR (rut ~* '^[0-9]+-[0-9kK]$'::text)))
);


ALTER TABLE public.users OWNER TO neondb_owner;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.users IS 'Global users table. Users can be customers (role=user) or administrators (role=admin). Soft delete enabled via deleted_at.';


--
-- Name: COLUMN users.rut; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON COLUMN public.users.rut IS 'Chilean national ID (RUT). Format: 12345678-K. Nullable for international users.';


--
-- Name: error_aggregations id; Type: DEFAULT; Schema: error_handling; Owner: neondb_owner
--

ALTER TABLE ONLY error_handling.error_aggregations ALTER COLUMN id SET DEFAULT nextval('error_handling.error_aggregations_id_seq'::regclass);


--
-- Name: error_logs id; Type: DEFAULT; Schema: error_handling; Owner: neondb_owner
--

ALTER TABLE ONLY error_handling.error_logs ALTER COLUMN id SET DEFAULT nextval('error_handling.error_logs_id_seq'::regclass);


--
-- Name: recurrence_config id; Type: DEFAULT; Schema: error_handling; Owner: neondb_owner
--

ALTER TABLE ONLY error_handling.recurrence_config ALTER COLUMN id SET DEFAULT nextval('error_handling.recurrence_config_id_seq'::regclass);


--
-- Data for Name: error_aggregations; Type: TABLE DATA; Schema: error_handling; Owner: neondb_owner
--

COPY error_handling.error_aggregations (id, workflow_name, error_type, error_fingerprint, time_window_start, time_window_end, occurrence_count, severity_max, first_occurrence, last_occurrence, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: error_logs; Type: TABLE DATA; Schema: error_handling; Owner: neondb_owner
--

COPY error_handling.error_logs (id, workflow_name, error_type, error_message, error_fingerprint, severity, occurrences, metadata, input_data, stack_trace, user_id, session_id, environment, resolved, resolved_at, resolved_by, created_at, updated_at) FROM stdin;
1	Manual_Test_Workflow	RUNTIME_ERROR	Unknown error	\N	CRITICAL	1	{"severity": "CRITICAL", "timestamp": "2026-02-16T23:12:01.063Z", "environment": "production", "workflow_id": "manual_test", "execution_id": "manual_test", "error_message": "Unknown error", "workflow_name": "Manual_Test_Workflow"}	\N	\N	\N	\N	production	f	\N	\N	2026-02-16 23:12:03.202723+00	2026-02-16 23:12:03.202723+00
2	Manual_Test_Workflow	RUNTIME_ERROR	Unknown error	\N	CRITICAL	1	{"severity": "CRITICAL", "timestamp": "2026-02-16T23:16:33.451Z", "environment": "production", "workflow_id": "manual_test", "execution_id": "manual_test", "error_message": "Unknown error", "workflow_name": "Manual_Test_Workflow"}	\N	\N	\N	\N	production	f	\N	\N	2026-02-16 23:16:34.833098+00	2026-02-16 23:16:34.833098+00
3	Manual_Test_Workflow	RUNTIME_ERROR	Unknown error	\N	CRITICAL	1	{"severity": "CRITICAL", "timestamp": "2026-02-16T23:26:55.822Z", "environment": "production", "workflow_id": "manual_test", "execution_id": "manual_test", "error_message": "Unknown error", "workflow_name": "Manual_Test_Workflow"}	\N	\N	\N	\N	production	f	\N	\N	2026-02-16 23:26:58.897041+00	2026-02-16 23:26:58.897041+00
4	Manual_Test_Workflow	RUNTIME_ERROR	Unknown error	\N	CRITICAL	1	{"severity": "CRITICAL", "timestamp": "2026-02-18T17:32:02.215Z", "environment": "production", "workflow_id": "manual_test", "execution_id": "manual_test", "error_message": "Unknown error", "workflow_name": "Manual_Test_Workflow"}	\N	\N	\N	\N	production	f	\N	\N	2026-02-18 17:32:04.897311+00	2026-02-18 17:32:04.897311+00
\.


--
-- Data for Name: recurrence_config; Type: TABLE DATA; Schema: error_handling; Owner: neondb_owner
--

COPY error_handling.recurrence_config (id, workflow_name, error_type, time_window_minutes, threshold_low, threshold_medium, threshold_high, threshold_critical, enabled, created_at, updated_at) FROM stdin;
1	DEFAULT	DEFAULT	10	3	5	10	20	t	2026-02-13 23:45:06.83855+00	2026-02-13 23:45:06.83855+00
\.


--
-- Data for Name: account; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth.account (id, "accountId", "providerId", "userId", "accessToken", "refreshToken", "idToken", "accessTokenExpiresAt", "refreshTokenExpiresAt", scope, password, "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: invitation; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth.invitation (id, "organizationId", email, role, status, "expiresAt", "createdAt", "inviterId") FROM stdin;
\.


--
-- Data for Name: jwks; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth.jwks (id, "publicKey", "privateKey", "createdAt", "expiresAt") FROM stdin;
\.


--
-- Data for Name: member; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth.member (id, "organizationId", "userId", role, "createdAt") FROM stdin;
\.


--
-- Data for Name: organization; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth.organization (id, name, slug, logo, "createdAt", metadata) FROM stdin;
\.


--
-- Data for Name: project_config; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth.project_config (id, name, endpoint_id, created_at, updated_at, trusted_origins, social_providers, email_provider, email_and_password, allow_localhost) FROM stdin;
52f6531d-2d52-4ba6-99a6-83348251f7b7	BasicBooking	ep-green-firefly-ahywl83k	2026-01-14 17:25:05.277+00	2026-01-14 17:25:05.277+00	[]	[{"id": "google", "isShared": true}]	{"type": "shared"}	{"enabled": true, "disableSignUp": false, "emailVerificationMethod": "otp", "requireEmailVerification": false, "autoSignInAfterVerification": true, "sendVerificationEmailOnSignIn": false, "sendVerificationEmailOnSignUp": false}	t
\.


--
-- Data for Name: session; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth.session (id, "expiresAt", token, "createdAt", "updatedAt", "ipAddress", "userAgent", "userId", "impersonatedBy", "activeOrganizationId") FROM stdin;
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth."user" (id, name, email, "emailVerified", image, "createdAt", "updatedAt", role, banned, "banReason", "banExpires") FROM stdin;
\.


--
-- Data for Name: verification; Type: TABLE DATA; Schema: neon_auth; Owner: neon_auth
--

COPY neon_auth.verification (id, identifier, value, "expiresAt", "createdAt", "updatedAt") FROM stdin;
\.


--
-- Data for Name: admin_sessions; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.admin_sessions (id, user_id, token_hash, expires_at, created_at, last_used_at, is_revoked) FROM stdin;
\.


--
-- Data for Name: admin_users; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.admin_users (id, username, password_hash, role, is_active, created_at, updated_at) FROM stdin;
71aa8d90-86a8-498a-910d-91074f4429be	admin	$2a$06$A3w0bjKgdWJJ8/A.Wx5hM.EREaAbstEkxtV1Zegn282E6FhVM4VPu	superadmin	t	2026-01-24 20:24:49.517632+00	2026-01-24 20:24:49.517632+00
\.


--
-- Data for Name: app_config; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.app_config (id, key, value, type, category, description, is_public, created_at, updated_at) FROM stdin;
c88c920f-a75f-43d9-8535-81c3a4677d1a	MAX_ADVANCE_DAYS	30	number	general	Maximum days in advance	t	2026-01-26 21:27:45.344063+00	2026-01-26 22:49:47.644924+00
47cd7cb6-d16d-40ce-8f93-31257e1f83e9	ADMIN_TELEGRAM_CHAT_IDS	["5391760292", "123456789"]	json	notifications	Lista de Chat IDs de administradores	f	2026-02-08 18:17:59.561687+00	2026-02-08 18:17:59.561687+00
89d8b452-a433-4b7f-ad5b-3b06072b3e2e	CALENDAR_MIN_TIME	07:00:00	string	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
a1435e9e-e46b-4beb-a0b8-c1a3e47d09a0	CALENDAR_MAX_TIME	21:00:00	string	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
ff736ac6-db86-4983-9daa-1f7a88759795	SECURITY_STRIKE_THRESHOLD	5	number	security	Cantidad de strikes para activar notificación crítica a BB_00	f	2026-02-09 14:53:44.646592+00	2026-02-09 14:53:44.646592+00
35b4b979-9df5-41e7-a961-cdb33663a32f	SECURITY_MAX_TELEGRAM_ID	9999999999999	number	security	Máximo valor permitido para telegram_id (13 dígitos)	f	2026-02-09 14:53:44.646592+00	2026-02-09 14:53:44.646592+00
0cbc39e6-0138-4441-91ac-2c5c1d840687	SECURITY_MAX_FIRST_NAME_LENGTH	255	number	security	Longitud máxima permitida para first_name	f	2026-02-09 14:53:44.646592+00	2026-02-09 14:53:44.646592+00
15a2944a-d892-4b3d-ae53-ab31ea179227	COLOR_PRIMARY_HOVER	#1d4ed8	color	branding	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
c707aa82-438e-4afc-9989-3b427dbc0020	COLOR_SUCCESS	#10b981	color	branding	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
99e79f48-b9cf-4c9e-9ea7-5ac35a81cb5d	COLOR_DANGER	#ef4444	color	branding	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
7a9afa97-4743-494e-a611-c8cbe5914c4e	COLOR_EVENT_CONFIRMED	#dcfce7	color	branding	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
b43fea76-743b-481b-8e74-54ba537a4eb0	COLOR_EVENT_PENDING	#fff7ed	color	branding	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
0c7b1257-b6c4-4e55-8d57-756579f4cc96	SECURITY_MAX_USERNAME_LENGTH	32	number	security	Longitud máxima permitida para username de Telegram	f	2026-02-09 14:53:44.646592+00	2026-02-09 14:53:44.646592+00
ae1b0424-9da8-42d1-a2f2-ddcb044dd5e5	BOOKING_MIN_NOTICE_HOURS	2	number	business	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
408c1b06-4f9b-4d6c-b4be-bec6fb77c485	BOOKING_MAX_DAYS_IN_ADVANCE	60	number	rules	Días máximos a futuro para reservar	t	2026-01-23 18:47:03.171944+00	2026-01-23 18:47:03.171944+00
614d2495-795f-4263-98f8-406c8ceb0c87	MIN_DURATION_MIN	15	number	business	\N	t	2026-01-22 18:06:43.27832+00	2026-01-23 18:47:03.171944+00
b90e80ed-f23b-4a5a-b672-cfa06ce9f076	MAX_DURATION_MIN	120	number	business	\N	t	2026-01-22 18:06:43.27832+00	2026-01-23 18:47:03.171944+00
1ea8a764-1ed5-4664-bda9-a3021ea26b2b	NOTIFICATION_MAX_RETRIES	3	number	notifications	\N	f	2026-01-22 19:47:44.609108+00	2026-01-23 18:47:03.171944+00
c59828ab-d32f-47b2-93fa-d1e94a737417	NOTIFICATION_TIMEOUT_MS	10000	number	notifications	Timeout de API Telegram	f	2026-01-23 18:47:03.171944+00	2026-01-23 18:47:03.171944+00
f60a8412-1a4c-419a-bfa1-1d51882dedd3	APP_TITLE	AutoAgenda Admin	string	branding	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
412f0683-4c25-4db3-8c7f-c60b8d7b3cb6	COLOR_PRIMARY	#2563eb	color	branding	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
6ac0e180-480a-4861-abe5-327c0542215e	DEFAULT_PROFESSIONAL_ID	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	string	business	\N	t	2026-01-22 18:25:56.253054+00	2026-01-23 18:47:03.171944+00
45a887b5-c1a7-4381-b933-fa6f4f2cf9a2	DEFAULT_SERVICE_ID	a7a019cb-3442-4f57-8877-1b04a1749c01	string	business	\N	t	2026-01-22 18:25:56.253054+00	2026-01-23 18:47:03.171944+00
97563212-643a-40e4-900f-07958c3ab2eb	TELEGRAM_BOT_USERNAME	AutoAgendaBot	string	telegram	Telegram bot username for BB_09 deep link redirects	t	2026-01-26 00:14:22.426419+00	2026-01-26 22:49:47.644924+00
de697b7c-78bd-41ba-930f-2e565cf05965	SLOT_DURATION_MINS	30	number	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-26 22:49:47.644924+00
d3a31e1a-feb5-44b1-9103-a9e4b8435d73	COLOR_EVENT_TEXT	#0f172a	color	branding	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
0f60d681-72d5-4e94-9dd1-90621a479ce3	BB_00_WORKFLOW_ID	_Za9GzqB2cS9HVwBglt43	string	workflows	ID del workflow BB_00_Global_Error_Handler para notificaciones	f	2026-02-09 14:53:44.646592+00	2026-02-09 23:32:43.856787+00
003006c0-dc55-4093-8ed4-1af37f619730	BOOKING_MAX_NOTICE_DAYS	60	number	business	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
2a3cf121-3013-4c4a-a718-8b0e3f98ad1b	DEFAULT_DURATION_MIN	30	number	business	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
ab76a620-58ec-439e-a675-8a07723933b7	TIMEZONE	America/Santiago	string	system	\N	t	2026-01-22 16:10:31.763132+00	2026-02-10 12:57:27.00693+00
eb4cd1b3-276d-470c-8200-1f914535d991	BOOKING_WINDOW_DAYS	14	number	booking	\N	t	2026-02-10 12:57:27.00693+00	2026-02-10 12:57:27.00693+00
91fbd250-dbd4-4553-98e2-2a1be70b1409	MIN_BOOKING_ADVANCE_HOURS	2	number	booking	\N	t	2026-02-10 12:57:27.00693+00	2026-02-10 12:57:27.00693+00
b18f62d6-36a6-4874-9b51-3f71ff6d2402	ERROR_ALERT_CHAT_ID	5391760292	string	system	\N	f	2026-01-22 18:25:56.253054+00	2026-01-22 19:47:44.609108+00
8e206285-12e8-442e-8fff-4f6297f2f008	NOTIFICATION_CRON_MINUTES	15	number	notifications	\N	f	2026-01-22 19:47:44.609108+00	2026-01-22 19:47:44.609108+00
e4cdc31d-f996-44ef-8e63-6edce55cc563	RETRY_WORKER_CRON_MINUTES	5	number	notifications	\N	f	2026-01-22 19:47:44.609108+00	2026-01-22 19:47:44.609108+00
38a205c6-5b9d-4223-aba2-a702aa930786	NOTIFICATION_BATCH_LIMIT	50	number	notifications	\N	f	2026-01-22 19:47:44.609108+00	2026-01-22 19:47:44.609108+00
14dda265-24f1-4042-b918-6afa94ee3989	WF_ID_AVAILABILITY_ENGINE	BB_03_Availability_Engine	string	general	\N	f	2026-01-22 21:09:13.096467+00	2026-01-22 21:09:13.096467+00
920214b9-d67a-4453-9cf7-b548e0865262	SCHEDULE_START_HOUR	9	number	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
1eead956-a6e6-40e8-be5c-8bb72c1dee3c	SCHEDULE_END_HOUR	18	number	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
17aaca59-e546-4a26-89c4-fa261498109d	SCHEDULE_DAYS	[1,2,3,4,5]	json	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
b8c75c61-7af2-4332-8a83-16da9ce3bf75	MAX_SLOTS_PER_QUERY	1000	number	availability	Limite de slots por consulta.	f	2026-02-11 14:42:43.922462+00	2026-02-11 14:42:43.922462+00
abc0a678-30e0-4b26-bf3f-e398cdf9dd3e	MIN_NOTICE_HOURS	2	number	general	Minimum notice hours	t	2026-01-26 21:27:45.344063+00	2026-01-26 22:49:47.644924+00
f39345f4-1142-4027-ab78-488390af23fd	DEFAULT_DAYS_RANGE	14	number	availability	Rango por defecto cuando no se especifica days_range.	f	2026-02-11 14:42:43.922462+00	2026-02-11 14:42:43.922462+00
\.


--
-- Data for Name: app_messages; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.app_messages (id, code, lang, message, created_at, updated_at) FROM stdin;
17730345-1557-448e-ace0-8fba7794e1a2	AUTH_MISSING_TOKEN	es	NO AUTORIZADO: Falta token	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
aa7ef49d-7b88-4429-8893-56c1202fd7eb	AUTH_INVALID_TOKEN	es	NO AUTORIZADO: Token inválido	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
9cbae254-e0b4-49bc-a8c7-faa9d0bc47f3	AUTH_EXPIRED_TOKEN	es	Token expirado	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
02390ea5-b577-46a0-9bdf-e30dfdf035c4	AUTH_FORBIDDEN	es	PROHIBIDO: Se requiere rol de admin	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
a35649e5-7988-4bb6-be5c-6f6bf37fbd14	ERR_INVALID_PRO	es	ID de profesional inválido	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
f029b1a1-a14a-4f30-8652-36bb9c03ba5e	ERR_INVALID_USER	es	ID de usuario inválido	2026-01-22 19:48:25.274639+00	2026-01-22 19:48:25.274639+00
fcac6ce5-13fd-4759-9cd8-fbe7f4c2deb5	ERR_INVALID_SRV	es	ID de servicio inválido	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
74e6a2c4-8621-4d0b-aceb-73675e3bebe5	ERR_INVALID_DATE	es	Fecha inválida	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
abd75d1d-de60-44cc-9aba-5b1d140e450c	ERR_INVALID_DATE_FORMAT	es	Formato de fecha incorrecto	2026-01-22 19:48:25.274639+00	2026-01-22 19:48:25.274639+00
d287ec6d-48cb-4a00-bf78-8077616bb512	ERR_INVALID_TIME_RANGE	es	Hora de inicio debe ser anterior al fin	2026-01-22 19:48:25.274639+00	2026-01-22 19:48:25.274639+00
fbd151b1-5b59-441c-8456-fb0b1be18650	ERR_DURATION_RANGE	es	Duración fuera de rango permitido	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
5d0deb79-3a1f-4e8e-bc6b-07c8cce1ba0e	ERR_NO_DATA	es	No se recibieron datos	2026-01-22 19:48:25.274639+00	2026-01-22 19:48:25.274639+00
6dd1d20d-bf19-4bd9-ac9b-a85879dd90e1	ERR_NO_BODY	es	Cuerpo de mensaje vacío	2026-01-22 19:48:25.274639+00	2026-01-22 19:48:25.274639+00
b532c270-deb3-4dc0-83ac-715b4f17e2e7	ERR_NO_CHAT_ID	es	Falta ID de chat	2026-01-22 19:48:25.274639+00	2026-01-22 19:48:25.274639+00
cadb7b3f-84f3-4dcb-b3f7-8d906b5a8582	ERR_SERVICE_ID_LENGTH	es	ID de servicio demasiado largo	2026-01-22 19:48:25.274639+00	2026-01-22 19:48:25.274639+00
6241c197-54f4-4d98-9a48-ccbe7b99bbf1	ERR_SRV_NOT_FOUND	es	Servicio no encontrado	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
1800bcf6-b5a8-4e59-bd27-6cd1cb400d37	ERR_NO_SCHEDULE	es	No hay horario disponible	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
97a06ae6-9ae0-485c-a353-6e3b478e9c52	ERR_SLOT_TAKEN	es	CONFLICTO: El horario ya está ocupado	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
df8cff77-c2e2-4a12-be2e-77b1e22f1f07	MSG_BOOKING_SUCCESS	es	Reserva procesada exitosamente	2026-01-22 18:27:03.244202+00	2026-01-22 18:27:03.244202+00
db6b9010-203d-4d51-b278-12367f3bb17e	ERR_GCAL_TIMEOUT	es	Error de sincronización con Google Calendar	2026-01-22 19:48:25.274639+00	2026-01-22 19:48:25.274639+00
\.


--
-- Data for Name: audit_logs; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.audit_logs (id, table_name, record_id, action, old_values, new_values, performed_by, ip_address, created_at, event_type, event_data) FROM stdin;
8d41d7fe-143b-4d3f-af3b-a979bb5aaade	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-18"}	\N	5391760292	\N	2026-01-17 14:15:26.866631+00	\N	\N
1f10e948-9b06-4b51-be9a-391f646386ad	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-18"}	\N	5391760292	\N	2026-01-17 14:16:24.807581+00	\N	\N
c6780342-70cb-49ef-916e-f718b378b851	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-18"}	\N	5391760292	\N	2026-01-17 14:21:30.651349+00	\N	\N
8914dce9-599b-4181-b983-31fbf2e1798b	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-18"}	\N	5391760292	\N	2026-01-17 14:35:46.862201+00	\N	\N
3d2be452-218d-4e54-8f28-653370a7cfc0	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-20"}	\N	5391760292	\N	2026-01-17 14:40:13.547601+00	\N	\N
b7023fdb-64e6-4874-9b17-f106820885f2	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-20"}	\N	5391760292	\N	2026-01-17 14:45:05.103451+00	\N	\N
586eaa10-9730-4672-9122-2e9e8cd59032	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-20"}	\N	5391760292	\N	2026-01-17 14:51:35.503829+00	\N	\N
3e98b4a2-2019-4dc9-9692-5bf4ed88c292	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test_verification"}	\N	123456	\N	2026-01-20 20:24:37.077949+00	\N	\N
fd410994-634e-490b-abfb-af31fe410bbd	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 20:25:12.396588+00	\N	\N
499bcf65-2f3b-48e4-b219-a0a6f463a4c4	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 20:25:19.834202+00	\N	\N
3c839f3c-f864-491c-b27f-4dc898cc0e2a	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 20:25:22.18538+00	\N	\N
12286d0f-72ff-4aeb-ae3f-8a603262d930	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 20:25:29.4485+00	\N	\N
03761c91-76fe-4015-9e03-865dafa009c9	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 20:25:36.827949+00	\N	\N
fa24edaa-4fae-4380-8d4f-5dc1ba4df173	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:25:51.572936+00	\N	\N
4846fc94-c905-4513-8c79-291c407f5391	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:25:59.177321+00	\N	\N
b597c811-e06f-4ba7-9d5a-eff5941a897f	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 20:26:06.426953+00	\N	\N
eec39550-1ba2-47c7-b9ef-ba45a4af6a59	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": ""}	\N	123	\N	2026-01-20 20:27:16.128886+00	\N	\N
7defdeac-7ee8-4ba6-a371-5219266fa3a9	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 20:27:38.958629+00	\N	\N
7bcfbc42-cb13-41bd-8e8f-f547806207e1	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 20:27:46.272023+00	\N	\N
9c86e47c-59cc-4cb9-a9a8-b30c5433d63f	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 20:28:14.112837+00	\N	\N
4eb600b0-dbeb-40bc-bbfb-9cd8e3522db6	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:28:35.149734+00	\N	\N
bc66125b-22b5-4373-a5d0-bd6256ce2b62	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "🔥💯🚀😎👍"}	\N	123	\N	2026-01-20 20:28:45.027695+00	\N	\N
20b7cfa6-041d-45c5-9310-456386f77955	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}	\N	123	\N	2026-01-20 20:28:59.773631+00	\N	\N
d76b70d5-c62e-4a3c-a211-3ddbd247e495	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 20:29:28.242535+00	\N	\N
acbcae05-1d00-41ad-8c86-13e5df8656f2	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 20:29:35.283347+00	\N	\N
66dc94ec-43b1-4e8b-8c04-78022dbd6600	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 20:29:42.588121+00	\N	\N
03b423b8-2d1b-4333-885a-3fabf4e00943	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 20:29:49.699507+00	\N	\N
ff01ff98-e456-4f16-97d0-30d2ceba3a86	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 20:29:56.793774+00	\N	\N
31409c6f-8b70-4a5d-9957-975b0e10a1ca	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:30:12.059944+00	\N	\N
6d997eac-5d49-4bcd-999a-0905bca7c1d1	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:30:19.20737+00	\N	\N
5031a754-2fe2-40ed-8b15-0d2d63496236	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 20:30:26.53273+00	\N	\N
78546c76-1716-4c62-bc37-99e37737df6d	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": ""}	\N	123	\N	2026-01-20 20:31:44.257899+00	\N	\N
4c88949b-5663-4433-a15f-bed6365d4b92	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 20:32:11.368773+00	\N	\N
71efb401-6609-4f5e-8f17-db962235ed1e	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 20:32:18.719326+00	\N	\N
26ade5f5-3914-46c6-aa54-17a2364bdb35	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 20:32:41.014411+00	\N	\N
381831a0-3772-4d19-bcea-ab3e8e1cd51e	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:32:56.938488+00	\N	\N
51b538f0-c57c-41f0-9780-e14326638f7a	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "🔥💯🚀😎👍"}	\N	123	\N	2026-01-20 20:33:18.308347+00	\N	\N
aad015d9-b7b0-4796-ae2a-d7bc1548396e	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}	\N	123	\N	2026-01-20 20:33:32.993881+00	\N	\N
f51096f1-6056-47d2-a0c5-a40bc0609f07	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 20:38:39.139165+00	\N	\N
a8e48662-d790-4bac-94c6-a74e86605563	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 20:38:46.438928+00	\N	\N
4ae20981-02c4-42b6-b713-d41833358a10	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 20:38:53.818417+00	\N	\N
40d51578-8fe2-4d1a-a336-e6f90e0cdc82	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 20:39:01.252813+00	\N	\N
31714873-f4fe-4661-bf99-febf4f0041eb	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 20:39:08.658059+00	\N	\N
1bf4f10a-409e-4e26-98ac-c11a16349467	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:39:23.71825+00	\N	\N
7014e614-84af-4a0e-a983-dde8ebb20673	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:39:30.938297+00	\N	\N
31504a92-233e-4616-9f2d-40eedd5b02f7	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 20:39:38.254838+00	\N	\N
dfb33f1b-962a-4185-a012-0f07e5bfeb39	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": ""}	\N	123	\N	2026-01-20 20:40:51.973227+00	\N	\N
a3ac117a-5ed2-40ae-acc7-adbf3a1794c9	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 20:41:19.728986+00	\N	\N
f714a0be-1556-48a7-a766-a66ebe6cc1df	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 20:41:26.989896+00	\N	\N
4503dc08-b60b-4b42-9594-b5f07cf9d3f4	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 20:41:49.224629+00	\N	\N
73116007-f78a-455c-bf89-58eaa8dbf9c4	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "🔥💯🚀😎👍"}	\N	123	\N	2026-01-20 20:42:29.566037+00	\N	\N
71e1d86e-95a8-44b7-9401-18fbe24e1b99	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}	\N	123	\N	2026-01-20 20:42:44.617867+00	\N	\N
cc7eca62-dabf-45ef-9c1f-f5fb25ecc008	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 20:43:08.483605+00	\N	\N
07ac5288-aa55-4765-9abe-87861084dad6	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 20:43:15.953736+00	\N	\N
e78f6c82-9275-4aca-9455-ec8be73c8c23	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 20:43:23.124153+00	\N	\N
08c2a09b-1897-4c80-827c-be12e94f6dba	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 20:43:30.288923+00	\N	\N
71ae3548-4d34-4d9b-8ce4-bc7a10c7677c	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 20:43:37.574127+00	\N	\N
2249f4aa-7ae9-4a97-8b4a-4ed23defd4dd	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:43:52.838393+00	\N	\N
2270f1d5-21ac-432d-9299-c0035999487e	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:44:00.262636+00	\N	\N
dd0410f1-b62e-4187-a410-8f2a0167ffc9	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 20:44:07.537285+00	\N	\N
5733cad2-875f-4c0d-95cd-f9c4a9faa492	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": ""}	\N	123	\N	2026-01-20 20:45:20.452866+00	\N	\N
95c52590-8a85-4a7d-9b0a-e0bceeafda61	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 20:45:47.819776+00	\N	\N
398193f6-9561-4e14-bdf8-1e0a67ce9d33	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 20:45:55.259234+00	\N	\N
5491082b-d465-45d7-9972-a7d028d1c2ce	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 20:46:22.532938+00	\N	\N
97b0172d-6db7-45b2-b582-929ed411c9ce	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "🔥💯🚀😎👍"}	\N	123	\N	2026-01-20 20:46:57.252638+00	\N	\N
5c8b9953-8a6d-4886-9fc2-22099cb5a14d	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}	\N	123	\N	2026-01-20 20:47:11.728282+00	\N	\N
56655967-8799-4ae1-a4c7-1a9c1669774c	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 20:47:37.052783+00	\N	\N
dabe0109-689b-4b06-b7da-a382e6980e21	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 20:47:44.33153+00	\N	\N
2ce8a546-11cc-4549-9edd-b9dfc3e5d445	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 20:47:46.594534+00	\N	\N
e7dc3179-4c0c-488d-be35-fb32115a9634	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 20:47:53.950255+00	\N	\N
5cde5a9f-c873-480f-9499-010477fdb08d	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 20:48:01.048332+00	\N	\N
7d56183b-9237-4dcb-aa17-92d2b9eb0ca3	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:48:15.928308+00	\N	\N
4337f94d-b777-4017-b80d-a2edc4827f93	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 20:48:23.068341+00	\N	\N
70c1de01-ba6a-4129-90be-ed3327eee01a	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 20:48:30.147667+00	\N	\N
e9045e78-d0ed-4819-96e8-e978bfb210f8	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": ""}	\N	123	\N	2026-01-20 20:49:43.129536+00	\N	\N
fb0c0ce8-9b54-43ec-a8c7-d91d3b087551	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 20:50:10.777658+00	\N	\N
4273444a-982d-40d5-a4ac-e83a0e043361	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 20:50:17.958724+00	\N	\N
3767db72-57f1-4a86-9b47-0cc40a3b3f46	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 20:50:45.429626+00	\N	\N
b64f6284-514f-43aa-98c2-ba136ace07f3	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "🔥💯🚀😎👍"}	\N	123	\N	2026-01-20 20:51:25.493152+00	\N	\N
d27d6b9f-29e2-425b-b5e7-1eea8129edc1	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}	\N	123	\N	2026-01-20 20:51:40.556935+00	\N	\N
142b8c36-1daa-4d3f-87b5-e832aad288c6	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 21:13:30.339084+00	\N	\N
b1116316-fb4d-4380-9a96-fd020fb4f556	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 21:13:38.034608+00	\N	\N
9070178f-0c36-430d-946f-b83c4eb6a205	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 21:13:45.167287+00	\N	\N
3e956284-087c-4747-ac2a-694bef921203	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 21:13:52.488777+00	\N	\N
16ec1651-d038-411c-ad97-327e07ba212f	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 21:13:54.808265+00	\N	\N
53640fbb-c4a0-42f8-a4bf-211c81155574	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 21:14:09.478927+00	\N	\N
cc6104a8-b55d-417d-876f-cda04ac9489d	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 21:14:16.758902+00	\N	\N
f34bb980-f339-490d-85d0-0a1db38045ce	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 21:14:24.037057+00	\N	\N
b02deb63-d082-4c46-994e-b1c274af4cd5	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": ""}	\N	123	\N	2026-01-20 21:15:42.063787+00	\N	\N
28b55da4-cbe5-432e-8105-ac86ac7d2d72	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 21:16:09.66907+00	\N	\N
b3975cae-87ca-4e87-af4e-74a0a8081f25	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 21:16:16.868416+00	\N	\N
b5b1b50f-9abe-42a9-8714-3aa98c63422e	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 21:16:44.540172+00	\N	\N
10468e04-e39b-4b7c-9dda-b4fe78624973	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "🔥💯🚀😎👍"}	\N	123	\N	2026-01-20 21:17:19.641538+00	\N	\N
bf568f31-ee85-4340-8946-64975191831a	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}	\N	123	\N	2026-01-20 21:17:34.392241+00	\N	\N
e7f7e605-988b-4967-91e6-e8f38d94aeec	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 22:29:30.818378+00	\N	\N
d13fa452-c3a2-4650-b107-97a1821ef047	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 22:29:38.257969+00	\N	\N
2e9d115a-9eaf-43b1-a1fc-4528f1339fc2	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 22:29:45.73385+00	\N	\N
c52c6b7f-f196-403f-bebe-4eebeaa65c34	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 22:29:53.073948+00	\N	\N
7bad7e35-45ef-42b8-8c61-ccc1f6a0c4be	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 22:30:00.548381+00	\N	\N
d785a10d-78af-4df5-8f43-5a9a18ef4887	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 22:30:15.258463+00	\N	\N
75aaf79e-913d-4c8c-8964-e8f43ed9d804	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 22:30:22.539253+00	\N	\N
382fadb3-9899-4ff4-a7dc-8aeac25b9fbe	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 22:30:25.109635+00	\N	\N
157940ca-564a-4fbf-86d6-e1ebdb13e1ae	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": ""}	\N	123	\N	2026-01-20 22:31:43.050189+00	\N	\N
75406880-2202-403a-b1f4-557aea63118a	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 22:32:10.629115+00	\N	\N
2e437a02-c2ba-4977-8737-ea88fd58812b	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 22:32:17.841962+00	\N	\N
68dc90c6-88d4-4d2d-9c0d-fbba0bf5edda	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 22:32:45.529021+00	\N	\N
608b88be-94c4-41e0-ab4d-d9f48785f92b	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 22:33:06.658549+00	\N	\N
9f4357de-bc5c-4a1e-9857-c0bb4f5a7705	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "🔥💯🚀😎👍"}	\N	123	\N	2026-01-20 22:33:28.108657+00	\N	\N
cd056b29-afe5-4465-8aa2-051ad910de4c	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}	\N	123	\N	2026-01-20 22:33:42.888763+00	\N	\N
68907efb-fbe3-4f8a-a2f0-d5c981caf604	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 23:35:25.992561+00	\N	\N
546a7e25-5022-4ea9-9b31-34d63dc41bf3	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 23:35:28.416419+00	\N	\N
d5bb5abe-24ed-448a-b6eb-829900153354	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 23:35:35.896835+00	\N	\N
de7ec4b8-1aac-4b06-b3d7-4607eff59303	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 23:35:43.172079+00	\N	\N
f1dbe255-75ab-413d-b9ab-3fe27af2af1c	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 23:35:50.777221+00	\N	\N
fbed088e-1492-4706-836b-2733eddb8594	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:36:05.397947+00	\N	\N
0aa56f12-eea6-4ed4-a0bf-5bad7fb9b215	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 23:36:06.617155+00	\N	\N
857c831c-afb0-489b-88c5-4ad1ebea3af8	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:36:12.796772+00	\N	\N
924b293c-9c72-4b81-a799-013c18e09f2c	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 23:36:13.919356+00	\N	\N
03cae447-7ced-49cb-86b5-95682f28a91f	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 23:36:20.05738+00	\N	\N
9a497fc7-d930-401b-8a7c-7b725bf40893	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 23:36:21.019205+00	\N	\N
f54d4559-5236-4c7a-9ab5-0ccc992498d6	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 23:36:28.31456+00	\N	\N
374c5b6c-c9c4-46fd-ba4f-09c8254bc182	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 23:36:35.577448+00	\N	\N
1158536b-12e2-46f2-83ea-4f17fa43bd81	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:36:50.041789+00	\N	\N
0f00b43c-3e5f-49cd-ad61-1aeeb3d39445	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 23:36:51.28377+00	\N	\N
7e1d743e-73d7-4a7c-b5c8-a45eaff313cb	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:36:57.307103+00	\N	\N
4ce89e70-e273-4184-80c2-d2a9adecacf0	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 23:36:58.546768+00	\N	\N
eb264e4f-a08b-4bc2-9ff1-863bc6999f19	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 23:37:04.50687+00	\N	\N
3baf6947-3f7d-4622-9182-6a6b38277eae	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 23:37:05.668991+00	\N	\N
cb965bc6-b988-4855-a099-e5242c9610a4	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 23:37:12.936926+00	\N	\N
09cf6283-12db-4c05-9514-70ff098c89df	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 23:37:20.266965+00	\N	\N
3cc8f7df-0551-45ea-ab67-2e063d6afcdb	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:37:35.018762+00	\N	\N
e307445e-1c43-4d4d-9b8e-40321339854f	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:37:42.513514+00	\N	\N
cbcc83e8-43d9-4439-ae8c-88bf22515567	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 23:37:49.746912+00	\N	\N
63e2a2ce-c7eb-4b07-9ea7-01e411646716	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 23:37:58.597019+00	\N	\N
3dbf77d2-d60f-4847-9bae-24723a87f44d	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 23:38:05.777213+00	\N	\N
e8caa7ab-50c3-411c-843e-fbec96047eab	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 23:38:27.957532+00	\N	\N
746d1eba-45e2-4794-82b4-94dd63f6d2d1	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	true	\N	2026-01-20 23:38:35.059281+00	\N	\N
428d8af9-7bc2-451d-9960-b140c987e841	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 23:38:36.079516+00	\N	\N
bb94a4e5-ab3d-4fa4-8044-2e5ea2e552b7	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 23:38:44.278212+00	\N	\N
32c0ecba-587a-4bc3-bc02-6bb479b7eccf	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:38:44.478285+00	\N	\N
2ff351d1-9061-4317-a5b7-d7668cc4453b	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:38:53.040473+00	\N	\N
3be3836f-62df-4afd-894c-30014537fbab	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 23:39:06.207888+00	\N	\N
01777618-340b-4eed-889f-d85e8baf3790	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	true	\N	2026-01-20 23:39:08.30419+00	\N	\N
fb13192a-2a23-4faa-96c8-a27443061bd9	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_book", "target_date": "2026-01-21"}	\N	5391760292	\N	2026-01-20 23:39:22.337147+00	\N	\N
7b0bdb40-abde-47e9-aac9-a48c0a86c76d	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:39:23.293496+00	\N	\N
e1f3a1cc-b0b8-4285-8497-dde637cb3546	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 23:39:25.716909+00	\N	\N
d323234d-f3cc-412c-b72c-db0f3f868630	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "cmd_start"}	\N	999888777	\N	2026-01-20 23:39:29.399689+00	\N	\N
3c2b6750-0aa5-43f5-b342-4f4022db2f40	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 23:39:32.903104+00	\N	\N
8b223b30-32ac-4da3-88b4-71b606515f88	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123456789	\N	2026-01-20 23:39:36.60764+00	\N	\N
0feb39c4-011c-4d45-bd0d-c337ead417b7	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:39:38.039311+00	\N	\N
a890f63d-e5cd-40a3-a675-e45d6f233e33	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	1	\N	2026-01-20 23:39:38.818675+00	\N	\N
a354054f-44c6-421e-8a2c-35fdb5213719	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	9007199254740991	\N	2026-01-20 23:39:41.058633+00	\N	\N
20bbb01e-408f-420b-976d-9e05edfa1b64	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:39:55.517844+00	\N	\N
d0ed3861-fd0c-4a1b-9aa2-fd1522ef050a	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 23:40:00.238661+00	\N	\N
43f0a981-3215-4c57-90f2-54bd71f527b8	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:40:03.097324+00	\N	\N
8efa43b1-82c8-4215-8ed4-f04fde0f9a7f	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	true	\N	2026-01-20 23:40:07.613736+00	\N	\N
c0f72588-76d4-42f6-aa86-6909a6799d90	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "a"}	\N	123	\N	2026-01-20 23:40:10.358338+00	\N	\N
8f0a4ca8-cbb1-418f-82cc-d9e29a1887e3	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:40:22.43276+00	\N	\N
6a6f847b-ad50-4aa6-9f16-06fdef846d5e	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:40:30.969135+00	\N	\N
539fe819-24e8-4054-9aa3-eb774307d7b3	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "<script>alert(1)</script>"}	\N	123	\N	2026-01-20 23:41:53.327823+00	\N	\N
ac665b65-3a39-4ec4-8709-6b525542b726	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "; rm -rf /"}	\N	123	\N	2026-01-20 23:41:55.512471+00	\N	\N
a9d9124a-9865-499c-8852-dc36149c3ec2	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	5391760292	\N	2026-01-20 23:42:17.968702+00	\N	\N
3d0e93f9-0477-41df-83a0-5161d364db82	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	true	\N	2026-01-20 23:42:25.222774+00	\N	\N
a48a4725-b383-4f11-9c89-c208166e69d1	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:42:39.85039+00	\N	\N
e6839086-53b2-4e08-9fbb-b927b5d23723	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{}	\N	123	\N	2026-01-20 23:42:54.993846+00	\N	\N
ca293dba-a4b3-4f57-aa74-096bfdea18d5	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "🔥💯🚀😎👍"}	\N	123	\N	2026-01-20 23:43:02.293142+00	\N	\N
dd37d93a-e8c4-498f-9606-e0b5fefd0494	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}	\N	123	\N	2026-01-20 23:43:17.179753+00	\N	\N
a2b1497b-1838-42d1-8ec9-126ffaefccd3	users	b9f03843-eee6-4607-ac5a-496c6faa9ea1	LOGIN_ATTEMPT	{"intent": "test"}	\N	123	\N	2026-01-24 16:45:41.207954+00	\N	\N
5d96814c-c32b-4d79-90d8-13a6f189f78b	security_firewall	540bd54c-cada-4af7-8658-8e63511d591a	ACCESS_CHECK	\N	\N	800800800	\N	2026-02-09 21:29:55.961995+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "540bd54c-cada-4af7-8658-8e63511d591a", "entity_id": "telegram:800800800", "is_banned": false, "timestamp": "2026-02-09T21:29:55.861Z", "ip_address": null, "is_blocked": false, "user_agent": null, "telegram_id": "800800800", "user_exists": true, "strike_count": 0}
2e2f1308-737e-4974-ab66-6024f7f196f0	security_firewall	47a581f5-59e0-4b80-9e3b-da8b422f5816	ACCESS_CHECK	\N	\N	800800801	\N	2026-02-09 21:29:56.716418+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "47a581f5-59e0-4b80-9e3b-da8b422f5816", "entity_id": "telegram:800800801", "is_banned": true, "timestamp": "2026-02-09T21:29:56.642Z", "ip_address": null, "is_blocked": false, "user_agent": null, "telegram_id": "800800801", "user_exists": true, "strike_count": 0}
c544ee3e-42a6-488d-9c4e-c049352c062a	security_firewall	47a581f5-59e0-4b80-9e3b-da8b422f5816	ACCESS_DENIED	\N	\N	800800801	\N	2026-02-09 21:29:56.921122+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "USER_BANNED", "user_id": "47a581f5-59e0-4b80-9e3b-da8b422f5816", "entity_id": "telegram:800800801", "timestamp": "2026-02-09T21:29:56.853Z", "telegram_id": "800800801", "error_message": "Usuario suspendido permanentemente"}
28607111-0dcd-4336-82ba-a08d461676b1	security_firewall	e92fd388-78e5-467a-8969-7b266934ce2a	ACCESS_CHECK	\N	\N	800800802	\N	2026-02-09 21:29:57.627518+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "e92fd388-78e5-467a-8969-7b266934ce2a", "entity_id": "telegram:800800802", "is_banned": false, "timestamp": "2026-02-09T21:29:57.560Z", "ip_address": null, "is_blocked": false, "user_agent": null, "telegram_id": "800800802", "user_exists": true, "strike_count": 3}
eea0c60a-c396-4bcb-8ace-ae2c26b5f4c1	security_firewall	fddc2cd9-ca5f-4c05-bb79-521b46b82523	ACCESS_CHECK	\N	\N	800800803	\N	2026-02-09 21:29:58.356977+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "fddc2cd9-ca5f-4c05-bb79-521b46b82523", "entity_id": "telegram:800800803", "is_banned": false, "timestamp": "2026-02-09T21:29:58.286Z", "ip_address": null, "is_blocked": false, "user_agent": null, "telegram_id": "800800803", "user_exists": true, "strike_count": 6}
a09bbb22-27c5-4ef5-8bde-2ee24900ee73	security_firewall	f7f1e897-5c96-4194-8e8d-542668e1ccde	ACCESS_CHECK	\N	\N	800800800	\N	2026-02-09 21:44:14.432156+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "f7f1e897-5c96-4194-8e8d-542668e1ccde", "entity_id": "telegram:800800800", "is_banned": false, "timestamp": "2026-02-09T21:44:14.354Z", "is_blocked": false, "telegram_id": "800800800", "user_exists": true, "strike_count": 0}
6f030ffc-8880-4071-b05f-72471fcdda56	security_firewall	acf7089f-34ec-4816-b4cd-499913978d93	ACCESS_CHECK	\N	\N	800800801	\N	2026-02-09 21:44:15.226404+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "acf7089f-34ec-4816-b4cd-499913978d93", "entity_id": "telegram:800800801", "is_banned": true, "timestamp": "2026-02-09T21:44:15.163Z", "is_blocked": false, "telegram_id": "800800801", "user_exists": true, "strike_count": 0}
74d12c78-e125-4d94-bf80-67b7e1df60dd	security_firewall	acf7089f-34ec-4816-b4cd-499913978d93	ACCESS_DENIED	\N	\N	800800801	\N	2026-02-09 21:44:15.446946+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "USER_BANNED", "user_id": "acf7089f-34ec-4816-b4cd-499913978d93", "entity_id": "telegram:800800801", "timestamp": "2026-02-09T21:44:15.375Z", "telegram_id": "800800801", "error_message": "Usuario suspendido permanentemente"}
2b483a61-7ad7-4f1d-9bf5-d7b6072c8533	security_firewall	ea9eae92-cba3-4da3-b97e-8de033d25c5c	ACCESS_CHECK	\N	\N	800800802	\N	2026-02-09 21:44:16.15111+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "ea9eae92-cba3-4da3-b97e-8de033d25c5c", "entity_id": "telegram:800800802", "is_banned": false, "timestamp": "2026-02-09T21:44:16.079Z", "is_blocked": false, "telegram_id": "800800802", "user_exists": true, "strike_count": 3}
10e239d8-9fad-42a6-bc04-48288c8544a6	providers	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 15:10:56.199175+00	availability_check	{"workflow": "BB_03", "days_range": 3, "target_date": "2026-03-01"}
a706e807-e47b-419e-bf7d-9a99729a7e80	security_firewall	97ff298c-03f8-4458-aab7-9fc70b0aaeb5	ACCESS_CHECK	\N	\N	800800803	\N	2026-02-09 21:44:16.871798+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "97ff298c-03f8-4458-aab7-9fc70b0aaeb5", "entity_id": "telegram:800800803", "is_banned": false, "timestamp": "2026-02-09T21:44:16.802Z", "is_blocked": false, "telegram_id": "800800803", "user_exists": true, "strike_count": 6}
a10508a5-0046-43c2-bfb0-4aebc8fb12a8	security_firewall	d1aa6090-f045-4c27-a8c8-745a0525fce8	ACCESS_CHECK	\N	\N	800800800	\N	2026-02-09 21:51:34.231634+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "d1aa6090-f045-4c27-a8c8-745a0525fce8", "entity_id": "telegram:800800800", "is_banned": false, "timestamp": "2026-02-09T21:51:34.159Z", "is_blocked": false, "telegram_id": "800800800", "user_exists": true, "strike_count": 0}
c59cbc12-5c3b-49db-980e-eeb32af96908	security_firewall	2430b7ba-fc2b-4e65-a1ce-3348a8f8e9f7	ACCESS_CHECK	\N	\N	800800801	\N	2026-02-09 21:51:34.939819+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "2430b7ba-fc2b-4e65-a1ce-3348a8f8e9f7", "entity_id": "telegram:800800801", "is_banned": true, "timestamp": "2026-02-09T21:51:34.871Z", "is_blocked": false, "telegram_id": "800800801", "user_exists": true, "strike_count": 0}
4e3dccae-a808-413c-ac98-852aa2cf67ac	security_firewall	2430b7ba-fc2b-4e65-a1ce-3348a8f8e9f7	ACCESS_DENIED	\N	\N	800800801	\N	2026-02-09 21:51:35.155339+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "USER_BANNED", "user_id": "2430b7ba-fc2b-4e65-a1ce-3348a8f8e9f7", "entity_id": "telegram:800800801", "timestamp": "2026-02-09T21:51:35.088Z", "telegram_id": "800800801", "error_message": "Usuario suspendido permanentemente"}
727caa85-4a40-40f7-a0b8-0737057648a9	security_firewall	7f72aa1b-c216-4128-b40d-0befee2bb0a6	ACCESS_CHECK	\N	\N	800800802	\N	2026-02-09 21:51:35.838783+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "7f72aa1b-c216-4128-b40d-0befee2bb0a6", "entity_id": "telegram:800800802", "is_banned": false, "timestamp": "2026-02-09T21:51:35.770Z", "is_blocked": false, "telegram_id": "800800802", "user_exists": true, "strike_count": 3}
63a0a459-980d-499a-a21a-a722a479aa61	security_firewall	abb2c332-279b-4c37-9dce-5b293def500f	ACCESS_CHECK	\N	\N	800800803	\N	2026-02-09 21:51:36.57333+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "abb2c332-279b-4c37-9dce-5b293def500f", "entity_id": "telegram:800800803", "is_banned": false, "timestamp": "2026-02-09T21:51:36.508Z", "is_blocked": false, "telegram_id": "800800803", "user_exists": true, "strike_count": 6}
cc1bff5b-8af1-4428-9a52-a096337e9ba3	security_firewall	c93a0716-c401-487b-8013-87fcb8a6d888	ACCESS_CHECK	\N	\N	800800802	\N	2026-02-09 21:52:18.15871+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "c93a0716-c401-487b-8013-87fcb8a6d888", "entity_id": "telegram:800800802", "is_banned": false, "timestamp": "2026-02-09T21:52:18.086Z", "is_blocked": false, "telegram_id": "800800802", "user_exists": true, "strike_count": 3}
2f6a81b7-4695-4212-bfef-3ea4b3949e5d	security_firewall	cc2358d8-e218-4295-b5ba-8717bd7bb167	ACCESS_CHECK	\N	\N	800800802	\N	2026-02-09 22:15:30.72862+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "cc2358d8-e218-4295-b5ba-8717bd7bb167", "entity_id": "telegram:800800802", "is_banned": false, "timestamp": "2026-02-09T22:15:30.628Z", "is_blocked": true, "telegram_id": "800800802", "user_exists": true, "strike_count": 3}
a1e135bb-b487-4fd0-a8de-1ae6ef60b326	security_firewall	69cb14d8-ecaa-4eb4-8a62-c2bc105d2db3	ACCESS_DENIED	\N	\N	800800802	\N	2026-02-09 22:15:31.119029+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800802", "timestamp": "2026-02-09T22:15:31.053Z", "telegram_id": "800800802", "strike_count": 3, "blocked_until": "2026-02-10T00:15:12.183Z", "error_message": "Acceso bloqueado hasta 2026-02-10T00:15:12.183Z"}
0718064d-66f0-4d4e-8c0c-c1b1a9e3b17a	security_firewall	bddd65a5-8910-4383-9963-81dd2c792aee	ACCESS_CHECK	\N	\N	800800800	\N	2026-02-09 22:15:59.267239+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "bddd65a5-8910-4383-9963-81dd2c792aee", "entity_id": "telegram:800800800", "is_banned": false, "timestamp": "2026-02-09T22:15:59.193Z", "is_blocked": false, "telegram_id": "800800800", "user_exists": true, "strike_count": 0}
35461811-7c2a-44a5-830e-fdfeb19aa02c	security_firewall	0b5cee52-a491-4a74-b941-09db533172ee	ACCESS_CHECK	\N	\N	800800801	\N	2026-02-09 22:15:59.986928+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "0b5cee52-a491-4a74-b941-09db533172ee", "entity_id": "telegram:800800801", "is_banned": true, "timestamp": "2026-02-09T22:15:59.912Z", "is_blocked": false, "telegram_id": "800800801", "user_exists": true, "strike_count": 0}
8eb15c2f-b6ac-479d-989e-d539080d932c	security_firewall	0b5cee52-a491-4a74-b941-09db533172ee	ACCESS_DENIED	\N	\N	800800801	\N	2026-02-09 22:16:00.186957+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "USER_BANNED", "user_id": "0b5cee52-a491-4a74-b941-09db533172ee", "entity_id": "telegram:800800801", "timestamp": "2026-02-09T22:16:00.112Z", "telegram_id": "800800801", "error_message": "Usuario suspendido permanentemente"}
75c6c6ad-8a6c-4917-aea6-f9cf7e0a149e	security_firewall	63130694-5b40-4280-a438-163a4098cbd2	ACCESS_CHECK	\N	\N	800800802	\N	2026-02-09 22:16:00.766752+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "63130694-5b40-4280-a438-163a4098cbd2", "entity_id": "telegram:800800802", "is_banned": false, "timestamp": "2026-02-09T22:16:00.705Z", "is_blocked": true, "telegram_id": "800800802", "user_exists": true, "strike_count": 3}
47b33b5d-f349-403d-9ad1-7469c7bfed73	security_firewall	1b4a4f8e-741d-47d8-b459-7288d126ac57	ACCESS_DENIED	\N	\N	800800802	\N	2026-02-09 22:16:00.957767+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800802", "timestamp": "2026-02-09T22:16:00.880Z", "telegram_id": "800800802", "strike_count": 3, "blocked_until": "2026-02-10T00:15:55.495Z", "error_message": "Acceso bloqueado hasta 2026-02-10T00:15:55.495Z"}
c5975556-4457-4868-9c1b-9e8ce9d96327	security_firewall	3ef038ad-631b-4243-8ac0-4fd163e19671	ACCESS_CHECK	\N	\N	800800803	\N	2026-02-09 22:16:01.625064+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "3ef038ad-631b-4243-8ac0-4fd163e19671", "entity_id": "telegram:800800803", "is_banned": false, "timestamp": "2026-02-09T22:16:01.544Z", "is_blocked": false, "telegram_id": "800800803", "user_exists": true, "strike_count": 6}
51a981eb-4ad4-4758-a056-cba92621630b	security_firewall	6b991a66-cbb1-4910-9507-5f43fc07983a	ACCESS_CHECK	\N	\N	999999999	\N	2026-02-09 22:16:02.298154+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "6b991a66-cbb1-4910-9507-5f43fc07983a", "entity_id": "telegram:999999999", "is_banned": false, "timestamp": "2026-02-09T22:16:02.223Z", "is_blocked": false, "telegram_id": "999999999", "user_exists": true, "strike_count": 0}
2502a3cf-66d5-4d50-b112-9b4fc20dbb25	security_firewall	92341a81-10f0-4369-b8da-29486bd5f241	ACCESS_CHECK	\N	\N	800800800	\N	2026-02-09 22:23:35.673309+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "92341a81-10f0-4369-b8da-29486bd5f241", "entity_id": "telegram:800800800", "is_banned": false, "timestamp": "2026-02-09T22:23:35.577Z", "is_blocked": false, "telegram_id": "800800800", "user_exists": true, "strike_count": 0}
690d72a2-1bf9-4cd7-b37a-03c5341f83ae	security_firewall	97792104-97db-42df-9685-cba90cd546cd	ACCESS_CHECK	\N	\N	800800801	\N	2026-02-09 22:23:36.373503+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "97792104-97db-42df-9685-cba90cd546cd", "entity_id": "telegram:800800801", "is_banned": true, "timestamp": "2026-02-09T22:23:36.284Z", "is_blocked": false, "telegram_id": "800800801", "user_exists": true, "strike_count": 0}
59b42adb-a9df-465e-a293-de33d1373864	security_firewall	97792104-97db-42df-9685-cba90cd546cd	ACCESS_DENIED	\N	\N	800800801	\N	2026-02-09 22:23:36.581693+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "USER_BANNED", "user_id": "97792104-97db-42df-9685-cba90cd546cd", "entity_id": "telegram:800800801", "timestamp": "2026-02-09T22:23:36.496Z", "telegram_id": "800800801", "error_message": "Usuario suspendido permanentemente"}
36d34f9a-207c-4fa4-958a-a6240966f0ed	security_firewall	c4f48f21-fa05-4021-8124-ab4c04d9437e	ACCESS_CHECK	\N	\N	anonymous	\N	2026-02-09 23:39:29.528487+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "timestamp": "2026-02-09T23:39:29.426Z"}
c530b0c0-82e6-434c-acb8-d24d9e61ef73	security_firewall	2ebe8bb0-f382-4043-8b30-6b09833e31a3	ACCESS_CHECK	\N	\N	800800802	\N	2026-02-09 22:23:37.182531+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "2ebe8bb0-f382-4043-8b30-6b09833e31a3", "entity_id": "telegram:800800802", "is_banned": false, "timestamp": "2026-02-09T22:23:37.103Z", "is_blocked": true, "telegram_id": "800800802", "user_exists": true, "strike_count": 3}
e545c16a-d3fa-4c22-9040-327fdfe9294e	security_firewall	ba642e65-bb99-41be-8e58-5e1ba6f77c6b	ACCESS_DENIED	\N	\N	800800802	\N	2026-02-09 22:23:37.403601+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800802", "timestamp": "2026-02-09T22:23:37.317Z", "telegram_id": "800800802", "strike_count": 3, "blocked_until": "2026-02-10T00:23:31.768Z", "error_message": "Acceso bloqueado hasta 2026-02-10T00:23:31.768Z"}
6c6726c3-b647-4691-8164-227adb869695	security_firewall	3e6ad3fa-81a3-4968-897c-dbec50bc1f4e	ACCESS_CHECK	\N	\N	800800803	\N	2026-02-09 22:23:38.010277+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "3e6ad3fa-81a3-4968-897c-dbec50bc1f4e", "entity_id": "telegram:800800803", "is_banned": false, "timestamp": "2026-02-09T22:23:37.922Z", "is_blocked": false, "telegram_id": "800800803", "user_exists": true, "strike_count": 6}
af9eba70-e5c7-453f-83e3-766d220d5014	security_firewall	1bd20457-f754-497c-8cd2-67f8ac340546	ACCESS_CHECK	\N	\N	999999999	\N	2026-02-09 22:23:38.627805+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999999", "is_banned": false, "timestamp": "2026-02-09T22:23:38.537Z", "is_blocked": false, "telegram_id": "999999999", "user_exists": false, "strike_count": 0}
a4107859-9164-41f1-96fd-30123c6b2895	security_firewall	d5ff81b6-0623-4e62-b462-12f8900df212	ACCESS_CHECK	\N	\N	999999990	\N	2026-02-09 22:38:55.323254+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999990", "is_banned": false, "timestamp": "2026-02-09T22:38:55.212Z", "is_blocked": false, "telegram_id": "999999990", "user_exists": false, "strike_count": 0}
47682b8c-40c7-45ba-805f-3ad3d210dd78	security_firewall	0e7739db-6689-4ce5-904c-7a03a12e5f6e	ACCESS_CHECK	\N	\N	999999991	\N	2026-02-09 22:38:56.744227+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999991", "is_banned": false, "timestamp": "2026-02-09T22:38:56.638Z", "is_blocked": false, "telegram_id": "999999991", "user_exists": false, "strike_count": 0}
4a25aee2-60b2-4522-8189-c68cc59f369b	security_firewall	7b65aabd-c1dc-4775-9e5b-a75496adf4ef	ACCESS_CHECK	\N	\N	999999992	\N	2026-02-09 22:38:57.673065+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999992", "is_banned": false, "timestamp": "2026-02-09T22:38:57.571Z", "is_blocked": false, "telegram_id": "999999992", "user_exists": false, "strike_count": 0}
8c20315d-4452-4ca2-bfc0-6f779728fb78	security_firewall	252d2a76-d038-4d87-b453-3c1b1df75803	ACCESS_CHECK	\N	\N	800800810	\N	2026-02-09 22:38:58.891488+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:800800810", "is_banned": false, "timestamp": "2026-02-09T22:38:58.786Z", "is_blocked": false, "telegram_id": "800800810", "user_exists": false, "strike_count": 2}
5cdbde15-b4bd-4d27-9f68-f6283c721175	security_firewall	f5ff03f9-3cc2-40a2-9fdd-471fd5d544ed	ACCESS_CHECK	\N	\N	800800811	\N	2026-02-09 22:39:00.223204+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "f5ff03f9-3cc2-40a2-9fdd-471fd5d544ed", "entity_id": "telegram:800800811", "is_banned": false, "timestamp": "2026-02-09T22:39:00.118Z", "is_blocked": false, "telegram_id": "800800811", "user_exists": true, "strike_count": 0}
d243186d-75ed-494f-8d2a-e04e654d350f	security_firewall	d9bf34f5-f0f8-4aa4-af6f-7453614562c7	ACCESS_CHECK	\N	\N	800800812	\N	2026-02-09 22:39:01.547357+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "d9bf34f5-f0f8-4aa4-af6f-7453614562c7", "entity_id": "telegram:800800812", "is_banned": false, "timestamp": "2026-02-09T22:39:01.450Z", "is_blocked": false, "telegram_id": "800800812", "user_exists": true, "strike_count": 0}
82c1fee8-8948-47e6-91c0-55e6b43eda3c	security_firewall	8e63a646-cb4f-4e65-b1f5-2a3ee67e3c3e	ACCESS_CHECK	\N	\N	800800813	\N	2026-02-09 22:39:03.392749+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "8e63a646-cb4f-4e65-b1f5-2a3ee67e3c3e", "entity_id": "telegram:800800813", "is_banned": false, "timestamp": "2026-02-09T22:39:03.297Z", "is_blocked": false, "telegram_id": "800800813", "user_exists": true, "strike_count": 3}
ab1e51fa-b3c7-41e4-a375-b7e785cafee8	security_firewall	21c3c46b-6e4c-4f25-a6d2-c6182f071dcf	ACCESS_CHECK	\N	\N	800800814	\N	2026-02-09 22:39:05.347884+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "21c3c46b-6e4c-4f25-a6d2-c6182f071dcf", "entity_id": "telegram:800800814", "is_banned": false, "timestamp": "2026-02-09T22:39:05.238Z", "is_blocked": false, "telegram_id": "800800814", "user_exists": true, "strike_count": 5}
e7ec85a3-2ac3-4fc2-ac02-eb92aae7a4e5	security_firewall	3850ce79-ff85-4b21-955e-1d7e5a0a4b36	ACCESS_CHECK	\N	\N	800800815	\N	2026-02-09 22:39:06.568473+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "3850ce79-ff85-4b21-955e-1d7e5a0a4b36", "entity_id": "telegram:800800815", "is_banned": true, "timestamp": "2026-02-09T22:39:06.469Z", "is_blocked": false, "telegram_id": "800800815", "user_exists": true, "strike_count": 0}
075fbfd3-059f-4f4a-a6b2-48c2f6ae83fd	security_firewall	3850ce79-ff85-4b21-955e-1d7e5a0a4b36	ACCESS_DENIED	\N	\N	800800815	\N	2026-02-09 22:39:06.814784+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "USER_BANNED", "user_id": "3850ce79-ff85-4b21-955e-1d7e5a0a4b36", "entity_id": "telegram:800800815", "timestamp": "2026-02-09T22:39:06.700Z", "telegram_id": "800800815", "error_message": "Usuario suspendido permanentemente"}
6f89549b-6eee-4a36-a6c8-b2e554cbb819	security_firewall	34a867d2-18e4-4727-aadc-b0f67e90dca1	ACCESS_CHECK	\N	\N	800800816	\N	2026-02-09 22:39:08.718374+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "34a867d2-18e4-4727-aadc-b0f67e90dca1", "entity_id": "telegram:800800816", "is_banned": true, "timestamp": "2026-02-09T22:39:08.618Z", "is_blocked": true, "telegram_id": "800800816", "user_exists": true, "strike_count": 0}
af397669-a5c6-4a24-9ae0-0445b1758189	security_firewall	1ae1c0e8-6db0-4912-ab1d-21626d39bbfe	ACCESS_DENIED	\N	\N	800800816	\N	2026-02-09 22:39:08.924224+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800816", "timestamp": "2026-02-09T22:39:08.826Z", "telegram_id": "800800816", "strike_count": 0, "blocked_until": "2026-02-10T00:39:07.585Z", "error_message": "Acceso bloqueado hasta 2026-02-10T00:39:07.585Z"}
0098a07f-5e10-4142-8522-03fce9b3daad	security_firewall	74ae15a7-523a-4018-a045-acbe75f68cf6	ACCESS_CHECK	\N	\N	800800817	\N	2026-02-09 22:39:10.260638+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "74ae15a7-523a-4018-a045-acbe75f68cf6", "entity_id": "telegram:800800817", "is_banned": true, "timestamp": "2026-02-09T22:39:10.153Z", "is_blocked": false, "telegram_id": "800800817", "user_exists": true, "strike_count": 0}
8aa567a4-57c6-47a1-9a5f-8c872aae7cca	security_firewall	74ae15a7-523a-4018-a045-acbe75f68cf6	ACCESS_DENIED	\N	\N	800800817	\N	2026-02-09 22:39:10.473258+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "USER_BANNED", "user_id": "74ae15a7-523a-4018-a045-acbe75f68cf6", "entity_id": "telegram:800800817", "timestamp": "2026-02-09T22:39:10.368Z", "telegram_id": "800800817", "error_message": "Usuario suspendido permanentemente"}
701b74a5-07cf-401f-ae55-e127dfb1de5e	security_firewall	7d4e2b99-e37e-4787-89b1-5bf39ede49a0	ACCESS_CHECK	\N	\N	800800818	\N	2026-02-09 22:39:12.309314+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "7d4e2b99-e37e-4787-89b1-5bf39ede49a0", "entity_id": "telegram:800800818", "is_banned": false, "timestamp": "2026-02-09T22:39:12.202Z", "is_blocked": true, "telegram_id": "800800818", "user_exists": true, "strike_count": 3}
57e119fb-542d-486d-9a96-5ccfb2a97076	security_firewall	b9f03843-eee6-4607-ac5a-496c6faa9ea1	ACCESS_CHECK	\N	\N	5391760292	\N	2026-02-09 23:39:35.374196+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "b9f03843-eee6-4607-ac5a-496c6faa9ea1", "entity_id": "telegram:5391760292", "is_banned": false, "timestamp": "2026-02-09T23:39:35.276Z", "is_blocked": false, "telegram_id": "5391760292", "user_exists": true, "strike_count": 1}
7a530867-42f5-475e-a617-0c23b1e799b4	security_firewall	c5ea7734-7b19-4215-a3cc-4cc467e88b7c	ACCESS_DENIED	\N	\N	800800818	\N	2026-02-09 22:39:12.503136+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800818", "timestamp": "2026-02-09T22:39:12.411Z", "telegram_id": "800800818", "strike_count": 3, "blocked_until": "2026-02-10T00:39:11.169Z", "error_message": "Acceso bloqueado hasta 2026-02-10T00:39:11.169Z"}
5822f750-796d-4ba0-a220-420f1ff16641	security_firewall	cfcc43e9-51a3-4c30-97ca-f7c96c9d5f6e	ACCESS_CHECK	\N	\N	800800819	\N	2026-02-09 22:39:14.267865+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "cfcc43e9-51a3-4c30-97ca-f7c96c9d5f6e", "entity_id": "telegram:800800819", "is_banned": false, "timestamp": "2026-02-09T22:39:14.157Z", "is_blocked": true, "telegram_id": "800800819", "user_exists": true, "strike_count": 10}
ad0a79be-962e-4b05-9507-b0f723282c12	security_firewall	7044b8e6-441c-435f-97da-0f6bbd5c58b2	ACCESS_DENIED	\N	\N	800800819	\N	2026-02-09 22:39:14.463035+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800819", "timestamp": "2026-02-09T22:39:14.358Z", "telegram_id": "800800819", "strike_count": 10, "blocked_until": "indefinido", "error_message": "Acceso bloqueado hasta indefinido"}
4f74448b-72df-4207-b722-d31dedea3fe0	security_firewall	9ea08ba5-1494-476c-8657-3298c168c38e	ACCESS_CHECK	\N	\N	800800820	\N	2026-02-09 22:39:16.287511+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "9ea08ba5-1494-476c-8657-3298c168c38e", "entity_id": "telegram:800800820", "is_banned": false, "timestamp": "2026-02-09T22:39:16.196Z", "is_blocked": true, "telegram_id": "800800820", "user_exists": true, "strike_count": 0}
2e662fc1-e3ad-43de-a94f-12c6f11ef7da	security_firewall	41dd2366-90f9-4321-81e4-cbf01115caa8	ACCESS_DENIED	\N	\N	800800820	\N	2026-02-09 22:39:16.508168+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800820", "timestamp": "2026-02-09T22:39:16.406Z", "telegram_id": "800800820", "strike_count": 0, "blocked_until": "2026-02-09T22:40:15.162Z", "error_message": "Acceso bloqueado hasta 2026-02-09T22:40:15.162Z"}
c2732fe0-3e89-4bad-a761-8643dc3800ce	security_firewall	a6bdb7d4-dd57-452b-9c85-e9948721ee78	ACCESS_CHECK	\N	\N	800800821	\N	2026-02-09 22:39:17.732406+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:800800821", "is_banned": false, "timestamp": "2026-02-09T22:39:17.630Z", "is_blocked": true, "telegram_id": "800800821", "user_exists": false, "strike_count": 5}
3d8d8263-0c1d-42bf-a7fe-030ef063b676	security_firewall	e4b381af-c505-4126-a5da-b126b17b688b	ACCESS_DENIED	\N	\N	800800821	\N	2026-02-09 22:39:17.94484+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800821", "timestamp": "2026-02-09T22:39:17.841Z", "telegram_id": "800800821", "strike_count": 5, "blocked_until": "2026-02-09T23:39:16.602Z", "error_message": "Acceso bloqueado hasta 2026-02-09T23:39:16.602Z"}
bbab65d8-ee5a-48fc-a571-c3b09f4dcd24	security_firewall	d1ddb303-3ad8-43e0-b0cc-0d42c0265fb0	ACCESS_CHECK	\N	\N	800800822	\N	2026-02-09 22:39:19.773172+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "d1ddb303-3ad8-43e0-b0cc-0d42c0265fb0", "entity_id": "telegram:800800822", "is_banned": false, "timestamp": "2026-02-09T22:39:19.677Z", "is_blocked": false, "telegram_id": "800800822", "user_exists": true, "strike_count": 6}
9e0f87b4-0601-4f71-bc66-22ef980d6bed	security_firewall	b9e71618-0679-491e-a08f-d138a83f2645	ACCESS_CHECK	\N	\N	800800823	\N	2026-02-09 22:39:21.627668+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "b9e71618-0679-491e-a08f-d138a83f2645", "entity_id": "telegram:800800823", "is_banned": false, "timestamp": "2026-02-09T22:39:21.520Z", "is_blocked": false, "telegram_id": "800800823", "user_exists": true, "strike_count": 5}
2103727c-db1b-4357-8c1e-1e6bdb545f72	security_firewall	0cf10863-1091-444e-81c0-0196edefc438	ACCESS_CHECK	\N	\N	800800824	\N	2026-02-09 22:39:23.463535+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "0cf10863-1091-444e-81c0-0196edefc438", "entity_id": "telegram:800800824", "is_banned": false, "timestamp": "2026-02-09T22:39:23.365Z", "is_blocked": false, "telegram_id": "800800824", "user_exists": true, "strike_count": 0}
0b67e1f0-5160-4c67-8843-b601bb4957c5	security_firewall	e00135aa-1535-4c70-ae07-cb12ba25027c	ACCESS_CHECK	\N	\N	9999999999	\N	2026-02-09 22:39:24.179711+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:9999999999", "is_banned": false, "timestamp": "2026-02-09T22:39:24.079Z", "is_blocked": false, "telegram_id": "9999999999", "user_exists": false, "strike_count": 0}
f940b914-3ae4-4e06-b322-97bd29ec7aa9	security_firewall	4842ad73-0fc8-4498-8e6b-20054af3364f	ACCESS_CHECK	\N	\N	999999993	\N	2026-02-09 22:39:24.887533+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999993", "is_banned": false, "timestamp": "2026-02-09T22:39:24.795Z", "is_blocked": false, "telegram_id": "999999993", "user_exists": false, "strike_count": 0}
6ae49a2a-653a-4c42-aaad-66e7ca295a8f	security_firewall	84eaea57-e79a-4ff9-be24-0ca2ed2f5a86	ACCESS_CHECK	\N	\N	999999994	\N	2026-02-09 22:39:25.612947+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999994", "is_banned": false, "timestamp": "2026-02-09T22:39:25.513Z", "is_blocked": false, "telegram_id": "999999994", "user_exists": false, "strike_count": 0}
eca4a34e-afbe-463a-992c-a44110c23e23	security_firewall	fb7ec7bd-eb21-4dde-a7be-a2587d1fa523	ACCESS_CHECK	\N	\N	800800825	\N	2026-02-09 22:39:26.742937+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "fb7ec7bd-eb21-4dde-a7be-a2587d1fa523", "entity_id": "telegram:800800825", "is_banned": false, "timestamp": "2026-02-09T22:39:26.639Z", "is_blocked": false, "telegram_id": "800800825", "user_exists": true, "strike_count": 0}
94c67f80-5934-4ccc-9893-63e0d19f5273	security_firewall	fb7ec7bd-eb21-4dde-a7be-a2587d1fa523	ACCESS_CHECK	\N	\N	800800825	\N	2026-02-09 22:39:27.353441+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "fb7ec7bd-eb21-4dde-a7be-a2587d1fa523", "entity_id": "telegram:800800825", "is_banned": false, "timestamp": "2026-02-09T22:39:27.254Z", "is_blocked": false, "telegram_id": "800800825", "user_exists": true, "strike_count": 0}
8570c71b-bb87-48c5-90c6-e6d12f04416c	security_firewall	fb7ec7bd-eb21-4dde-a7be-a2587d1fa523	ACCESS_CHECK	\N	\N	800800825	\N	2026-02-09 22:39:27.971066+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "fb7ec7bd-eb21-4dde-a7be-a2587d1fa523", "entity_id": "telegram:800800825", "is_banned": false, "timestamp": "2026-02-09T22:39:27.868Z", "is_blocked": false, "telegram_id": "800800825", "user_exists": true, "strike_count": 0}
f6b8c229-cbb5-4ed6-85e5-03a4655e4c12	security_firewall	ae665c73-6ee6-4615-ba2f-8c4d720f3c1c	ACCESS_CHECK	\N	\N	999999995	\N	2026-02-09 22:39:28.647766+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999995", "is_banned": false, "timestamp": "2026-02-09T22:39:28.547Z", "is_blocked": false, "telegram_id": "999999995", "user_exists": false, "strike_count": 0}
8982b9cd-e3e0-4b3d-b309-815675f5ecab	security_firewall	864eacd5-2076-4877-95eb-348db8c14727	ACCESS_CHECK	\N	\N	999999996	\N	2026-02-09 22:39:29.407335+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999996", "is_banned": false, "timestamp": "2026-02-09T22:39:29.302Z", "is_blocked": false, "telegram_id": "999999996", "user_exists": false, "strike_count": 0}
cafcd430-a268-46f3-a674-418f8b27222e	security_firewall	938dd03b-549b-4722-9655-71c5cd5c2196	ACCESS_CHECK	\N	\N	800800826	\N	2026-02-09 22:39:31.568435+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "938dd03b-549b-4722-9655-71c5cd5c2196", "entity_id": "telegram:800800826", "is_banned": false, "timestamp": "2026-02-09T22:39:31.453Z", "is_blocked": true, "telegram_id": "800800826", "user_exists": true, "strike_count": 0}
276f0780-4f7f-4c56-93ed-7ef6d8061250	providers	11111111-1111-1111-1111-111111111111	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 13:34:06.673681+00	\N	{"workflow": "BB_03", "days_range": 5, "target_date": "2026-03-01"}
b911776f-863d-4cf6-8fbe-de6870891cc6	providers	11111111-1111-1111-1111-111111111111	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 13:40:24.739574+00	\N	{"workflow": "BB_03", "days_range": 5, "target_date": "2026-03-01"}
bf0925b2-4140-445a-bdd3-b37c3e24042f	security_firewall	9ac903cc-a5c1-4903-9f25-c9caa53a0983	ACCESS_DENIED	\N	\N	800800826	\N	2026-02-09 22:39:31.778158+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800826", "timestamp": "2026-02-09T22:39:31.671Z", "telegram_id": "800800826", "strike_count": 0, "blocked_until": "2026-02-09T23:39:30.420Z", "error_message": "Acceso bloqueado hasta 2026-02-09T23:39:30.420Z"}
3a375500-f75a-4ac5-bd09-3b7dd5bd984f	security_firewall	3e89661e-b103-4e70-aae4-e994a068819a	ACCESS_CHECK	\N	\N	800800827	\N	2026-02-09 22:39:33.602943+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "3e89661e-b103-4e70-aae4-e994a068819a", "entity_id": "telegram:800800827", "is_banned": true, "timestamp": "2026-02-09T22:39:33.499Z", "is_blocked": true, "telegram_id": "800800827", "user_exists": true, "strike_count": 0}
52784e47-0a22-4b4d-839e-f71a728e4dd0	security_firewall	b917ab8f-8ed3-4d04-9bb1-4e449a1ef7ae	ACCESS_DENIED	\N	\N	800800827	\N	2026-02-09 22:39:33.822843+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "FIREWALL_BLOCKED", "entity_id": "telegram:800800827", "timestamp": "2026-02-09T22:39:33.708Z", "telegram_id": "800800827", "strike_count": 0, "blocked_until": "2026-02-09T23:39:32.468Z", "error_message": "Acceso bloqueado hasta 2026-02-09T23:39:32.468Z"}
13962bfd-f665-49b0-bb55-bea05a2f3d40	security_firewall	4d279750-220b-44ec-bd41-4226d18a3623	ACCESS_CHECK	\N	\N	800800828	\N	2026-02-09 22:39:35.042983+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "4d279750-220b-44ec-bd41-4226d18a3623", "entity_id": "telegram:800800828", "is_banned": true, "timestamp": "2026-02-09T22:39:34.935Z", "is_blocked": false, "telegram_id": "800800828", "user_exists": true, "strike_count": 0}
2a659e00-388e-43a2-8322-4035010a3f71	security_firewall	4d279750-220b-44ec-bd41-4226d18a3623	ACCESS_DENIED	\N	\N	800800828	\N	2026-02-09 22:39:35.249123+00	FIREWALL_ACCESS_DENIED	{"action": "ACCESS_DENIED", "reason": "USER_BANNED", "user_id": "4d279750-220b-44ec-bd41-4226d18a3623", "entity_id": "telegram:800800828", "timestamp": "2026-02-09T22:39:35.146Z", "telegram_id": "800800828", "error_message": "Usuario suspendido permanentemente"}
37ff7ce8-5a5a-4e2a-bcfd-da29e40d6595	security_firewall	b9f03843-eee6-4607-ac5a-496c6faa9ea1	ACCESS_CHECK	\N	\N	5391760292	\N	2026-02-09 23:30:38.977461+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "b9f03843-eee6-4607-ac5a-496c6faa9ea1", "entity_id": "telegram:5391760292", "is_banned": false, "timestamp": "2026-02-09T23:30:38.863Z", "is_blocked": false, "telegram_id": "5391760292", "user_exists": true, "strike_count": 1}
5092e413-219b-4a49-af9a-6ef789bf4813	security_firewall	fb1e666a-70be-4c79-9363-948ef3a291cc	ACCESS_CHECK	\N	\N	999999999	\N	2026-02-09 23:30:57.65961+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": null, "entity_id": "telegram:999999999", "is_banned": false, "timestamp": "2026-02-09T23:30:57.553Z", "is_blocked": false, "telegram_id": "999999999", "user_exists": false, "strike_count": 0}
0b9f5396-5521-4d2c-9826-4fd80d44811f	security_firewall	b9f03843-eee6-4607-ac5a-496c6faa9ea1	ACCESS_CHECK	\N	\N	5391760292	\N	2026-02-09 23:42:15.491809+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "b9f03843-eee6-4607-ac5a-496c6faa9ea1", "entity_id": "telegram:5391760292", "is_banned": false, "timestamp": "2026-02-09T23:42:15.384Z", "is_blocked": false, "telegram_id": "5391760292", "user_exists": true, "strike_count": 1}
4353b2e9-55eb-424f-a3ef-98afaef0d48b	security_firewall	b9f03843-eee6-4607-ac5a-496c6faa9ea1	ACCESS_CHECK	\N	\N	5391760292	\N	2026-02-09 23:43:52.246607+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "b9f03843-eee6-4607-ac5a-496c6faa9ea1", "entity_id": "telegram:5391760292", "is_banned": false, "timestamp": "2026-02-09T23:43:52.153Z", "is_blocked": false, "telegram_id": "5391760292", "user_exists": true, "strike_count": 1}
fa491fc0-e95b-42ba-9851-a13d3873afdd	security_firewall	b9f03843-eee6-4607-ac5a-496c6faa9ea1	ACCESS_CHECK	\N	\N	5391760292	\N	2026-02-10 23:04:13.290943+00	FIREWALL_ACCESS_ATTEMPT	{"action": "ACCESS_CHECK", "user_id": "b9f03843-eee6-4607-ac5a-496c6faa9ea1", "entity_id": "telegram:5391760292", "is_banned": false, "timestamp": "2026-02-10T23:04:13.000Z", "is_blocked": false, "telegram_id": "5391760292", "user_exists": true, "strike_count": 1}
fa5e90f6-5859-4857-afe0-db9889a8bcdd	providers	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 15:12:15.339478+00	availability_check	{"workflow": "BB_03", "days_range": 3, "target_date": "2026-03-01"}
76c18120-e5d8-4f27-818e-fa1c5497974c	providers	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 15:12:48.158184+00	availability_check	{"workflow": "BB_03", "days_range": 3, "target_date": "2026-03-01"}
b24b7b23-b257-419e-bdbc-19dd4185d049	providers	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 15:13:21.587962+00	availability_check	{"workflow": "BB_03", "days_range": 3, "target_date": "2026-03-01"}
2311ffd3-7806-4028-985c-342c55aba3b1	providers	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 15:13:47.075715+00	availability_check	{"workflow": "BB_03", "days_range": 3, "target_date": "2026-03-01"}
ce60c07c-511a-4af2-8b12-1bba41574ac7	providers	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 15:14:27.019572+00	availability_check	{"workflow": "BB_03", "days_range": 3, "target_date": "2026-03-01"}
00027b1f-7d28-43ef-80b6-7e0379135440	providers	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	ACCESS_CHECK	\N	\N	system	\N	2026-02-11 15:15:42.309606+00	availability_check	{"workflow": "BB_03", "days_range": 3, "target_date": "2026-03-01"}
298f9e92-6bba-4164-8a72-f413a101779f	users	a1b2c3d4-e5f6-7890-abcd-000000000001	INSERT	\N	{"telegram_id": 3000001}	system	\N	2026-01-19 23:58:01.030811+00	USER_CREATED	{"source": "seed"}
4a3def7c-1011-48d4-9304-c8a16783a5ae	providers	b1b2b3b4-c5d6-7890-abcd-000000000001	INSERT	\N	{"name": "Dr. Alejandro Vera"}	system	\N	2025-12-20 23:58:01.030811+00	PROVIDER_CREATED	{"source": "seed"}
1fef9bde-ce48-4144-890f-5c53e254244a	security_firewall	6e0f74e8-997a-4f14-83a5-d91508ba414a	UPDATE	{"strike_count": 4}	{"strike_count": 5}	system	\N	2026-02-18 23:28:01.030811+00	STRIKE_ADDED	{"entity_id": "telegram:3000016"}
20625ba3-18e1-4915-8958-5ee2af41bb11	users	a1b2c3d4-e5f6-7890-abcd-000000000017	SOFT_DELETE	{"deleted_at": null}	{"deleted_at": "now"}	admin	192.168.1.100	2026-02-13 23:58:01.030811+00	USER_SOFT_DELETED	{"reason": "test"}
1edcee89-7579-4a05-bfcc-9f3c7954e331	users	a1b2c3d4-e5f6-7890-abcd-000000000001	INSERT	\N	{"telegram_id": 3000001}	system	\N	2026-01-19 23:59:54.652148+00	USER_CREATED	{"source": "seed"}
24beeca3-a51f-43f3-8a17-afd0681e0722	providers	b1b2b3b4-c5d6-7890-abcd-000000000001	INSERT	\N	{"name": "Dr. Alejandro Vera"}	system	\N	2025-12-20 23:59:54.831695+00	PROVIDER_CREATED	{"source": "seed"}
05da5ccb-9206-4388-8797-1934434d64ab	security_firewall	48817624-21ef-4e50-a4e9-646d99b0b771	UPDATE	{"strike_count": 4}	{"strike_count": 5}	system	\N	2026-02-18 23:29:55.08666+00	STRIKE_ADDED	{"entity_id": "telegram:3000016"}
69f22ba9-af87-4d11-a519-bc9a9f947a09	users	a1b2c3d4-e5f6-7890-abcd-000000000017	SOFT_DELETE	{"deleted_at": null}	{"deleted_at": "now"}	admin	192.168.1.100	2026-02-13 23:59:55.251246+00	USER_SOFT_DELETED	{"reason": "test"}
\.


--
-- Data for Name: bookings; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.bookings (id, user_id, provider_id, service_id, start_time, end_time, status, gcal_event_id, notes, created_at, updated_at, deleted_at, reminder_1_sent_at, reminder_2_sent_at) FROM stdin;
e4b85c4d-f90b-4ed3-af08-683d292a0aaf	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	\N	2026-01-20 13:00:00+00	2026-01-20 13:30:00+00	confirmed	\N	\N	2026-01-16 22:51:03.642962+00	2026-01-16 22:51:03.642962+00	\N	\N	\N
d4dbcad6-7df8-4b9f-b2a2-8b78c9e0ef42	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 09:00:00+00	2026-01-20 09:30:00+00	confirmed	\N	\N	2026-01-17 15:12:27.225645+00	2026-01-17 15:12:27.225645+00	\N	\N	\N
75bb1da4-abad-4736-b7fb-67a8ac7967c9	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 16:00:00+00	2026-01-20 16:30:00+00	confirmed	\N	\N	2026-01-17 16:10:06.188147+00	2026-01-17 16:10:06.188147+00	\N	\N	\N
c00f8874-4c3f-48de-9979-bef854e3b267	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 17:00:00+00	2026-01-20 17:30:00+00	confirmed	\N	\N	2026-01-17 16:15:52.719737+00	2026-01-17 16:15:52.719737+00	\N	\N	\N
0e34b7c7-d44f-4a49-aa4a-3d2e21eabfc9	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-18 18:30:51.226785+00	2026-01-18 19:00:51.226785+00	confirmed	\N	\N	2026-01-17 19:30:51.226785+00	2026-01-17 20:56:23.622832+00	\N	2026-01-17 20:56:23.622832+00	\N
0006b96b-88f9-4058-bc84-5ad288cbb8c5	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-02-01 10:00:00+00	2026-02-01 10:30:00+00	confirmed	\N	\N	2026-01-17 22:40:26.085836+00	2026-01-17 22:40:26.085836+00	\N	\N	\N
775ad457-2428-4e5a-81ee-dfb86a7bcce8	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 08:00:00+00	2026-01-20 08:30:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
d812ae20-1c79-41b9-9a29-df4f28e2dbed	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 08:30:00+00	2026-01-20 09:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
e18b34f1-aa2c-47b1-b4d6-3410b57cd0f0	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 09:30:00+00	2026-01-20 10:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
e32aa626-ecfe-4d41-861f-fc59bc72a75e	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 10:00:00+00	2026-01-20 10:30:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
108c754b-0a54-4289-8bee-60ca37a7e1b6	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 10:30:00+00	2026-01-20 11:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
2cba94e3-35f8-4682-ba2c-11129a4ec26b	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 11:00:00+00	2026-01-20 11:30:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
6406dd7f-b8b6-4ae2-b5b7-e03f9b37f363	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 11:30:00+00	2026-01-20 12:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
896148a5-ef26-4ce8-b037-682e43e27f74	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 12:00:00+00	2026-01-20 12:30:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
9964c586-21cd-4ce9-8da2-5732cea2a376	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 12:30:00+00	2026-01-20 13:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
db90536e-bbf3-49c1-b1d4-d384327647d2	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 13:30:00+00	2026-01-20 14:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
4eafae23-68bc-40a1-9ab1-d8ce4c467962	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 14:00:00+00	2026-01-20 14:30:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
9433c138-12d4-4cd4-a0b4-200c34b690e7	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 14:30:00+00	2026-01-20 15:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
b2ef2fc4-f3db-42f6-a65e-0040fedf74c5	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 15:00:00+00	2026-01-20 15:30:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
b6cfcd94-28bc-471d-9e26-e4bba4d75860	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 15:30:00+00	2026-01-20 16:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
71b87e2a-7ad7-434a-b960-798f73357e1e	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 16:30:00+00	2026-01-20 17:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
2ee68846-4538-44bb-a83a-eddcc5674118	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 17:30:00+00	2026-01-20 18:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
e236195b-375a-409d-9950-cd014e74d636	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 18:00:00+00	2026-01-20 18:30:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
1b7415dc-0786-4d57-8460-84bcfcf543e8	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 18:30:00+00	2026-01-20 19:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
41601676-6547-4110-ac68-9538de62a19c	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 19:00:00+00	2026-01-20 19:30:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
37a09820-1231-414e-a465-8d996f016bd3	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-20 19:30:00+00	2026-01-20 20:00:00+00	confirmed	\N	STRESS_TEST	2026-01-18 14:08:08.859169+00	2026-01-18 14:08:08.859169+00	\N	\N	\N
3461dc78-98e7-46b9-ab2f-5e4616fab81e	7b76edda-dd8a-41a1-8391-99bbe2f5fcf1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-19 11:00:00+00	2026-01-19 11:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
d4c71a9c-a9d2-4b94-8ae3-6d6ad4530f51	7b76edda-dd8a-41a1-8391-99bbe2f5fcf1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-19 17:00:00+00	2026-01-19 17:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
e93d5aed-74ff-43eb-bfe2-c7fad20ea47c	ca49f72a-6c1a-47d4-9780-6f0408c11211	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-19 09:00:00+00	2026-01-19 09:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
ccd7670b-02b1-4469-a7bd-c9d3a3a174b0	ca49f72a-6c1a-47d4-9780-6f0408c11211	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-22 13:00:00+00	2026-01-22 13:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
83f3fece-635a-43fe-b9a6-0cbdd7ba6c01	ca49f72a-6c1a-47d4-9780-6f0408c11211	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-21 13:00:00+00	2026-01-21 13:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
de1b80d7-11f3-4bb3-807f-788e2ca9882b	5f9f9676-93db-4df1-8131-0c4a69bd0c95	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-21 09:00:00+00	2026-01-21 09:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
a6eb8ec0-10ad-4f04-a340-dbe1b198ec91	5f9f9676-93db-4df1-8131-0c4a69bd0c95	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-19 10:00:00+00	2026-01-19 10:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
f1fdb524-5300-4eb1-ace0-8d48166cc060	663bfa7a-7341-49c9-b495-9f912b170230	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-19 16:00:00+00	2026-01-19 16:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
07f2a9f0-8894-4350-8152-e951380ea639	663bfa7a-7341-49c9-b495-9f912b170230	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-23 16:00:00+00	2026-01-23 16:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
ea40ac53-eeed-43cd-bba3-eba628bc4a08	663bfa7a-7341-49c9-b495-9f912b170230	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-23 13:00:00+00	2026-01-23 13:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
59a93d9a-8a81-477f-b8e7-91fbf70804f8	7bf2f8a4-051d-4956-913a-7adc652f0618	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-21 11:00:00+00	2026-01-21 11:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
15eb1ad1-e8a5-475c-9efa-4a54c7f3ac53	7bf2f8a4-051d-4956-913a-7adc652f0618	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-23 14:00:00+00	2026-01-23 14:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
295238b3-aa3a-4e4f-995f-b05d75cebc69	7bf2f8a4-051d-4956-913a-7adc652f0618	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-23 17:00:00+00	2026-01-23 17:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
8ac0b1ec-0d30-4a1b-8925-44491dd946df	4becd89e-11f4-4c4f-ba3a-1eabd7394c39	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-22 12:00:00+00	2026-01-22 12:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
d7f45fbd-fc81-4976-8ca6-91395391ea9b	cbb0be91-868b-4fd0-9786-1d52adc4e1dc	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-21 12:00:00+00	2026-01-21 12:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
c685f619-58de-4d55-ba86-d81d5e71625d	0bf4f0c1-aac3-4bfd-80a8-fa9cf150b99a	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-22 17:00:00+00	2026-01-22 17:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
2c9fe34a-9aad-43dc-87ac-1ae30682704f	e2d55df3-6398-4957-8024-ef7200df3119	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-21 10:00:00+00	2026-01-21 10:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
fa3d46f9-99e6-4b9a-b06d-263250d11402	e2d55df3-6398-4957-8024-ef7200df3119	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-19 14:00:00+00	2026-01-19 14:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
6c2016ff-16c7-41d6-b088-9cb5cdd3083a	0a621361-57a2-4826-aabc-1c5a914f22a7	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-23 11:00:00+00	2026-01-23 11:30:00+00	confirmed	\N	CURRENT_WEEK_TEST	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
b8fb179b-7555-4f17-a950-f8e077bb3952	988c553b-7051-47cf-bf06-29abcfcf34b3	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-25 12:00:00+00	2026-01-25 12:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
79e5b967-b8eb-4932-95b0-746bd0064aee	988c553b-7051-47cf-bf06-29abcfcf34b3	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-24 13:00:00+00	2026-01-24 13:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
900f63ae-e0a1-47af-b8f7-f154452c2f02	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-02-20 10:00:00+00	2026-02-20 10:45:00+00	confirmed	\N	\N	2026-01-19 16:04:41.336758+00	2026-01-19 16:04:41.336758+00	\N	\N	\N
aa4c68f6-cb09-4b35-8282-5ed237e9d0ee	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-17 22:16:34.587363+00	2026-01-17 22:46:34.587363+00	confirmed	\N	\N	2026-01-17 20:26:34.587363+00	2026-01-17 21:29:42.638684+00	\N	\N	2026-01-17 21:29:42.638684+00
e6527639-3998-4a27-a07c-b952b7c67b58	988c553b-7051-47cf-bf06-29abcfcf34b3	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-26 11:00:00+00	2026-01-26 11:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
9b07bd95-d96b-4f13-a4c3-fc333b7136a5	db5f3969-2684-494e-abd8-5e452660cdd6	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-25 16:00:00+00	2026-01-25 16:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
c8c30ed4-4e63-4dba-a557-48b60ca0f5a7	db5f3969-2684-494e-abd8-5e452660cdd6	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-26 12:00:00+00	2026-01-26 12:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
06e2ba9b-9d6d-4510-b28e-1df6c0750457	db5f3969-2684-494e-abd8-5e452660cdd6	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-28 17:00:00+00	2026-01-28 17:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
98b431ff-16e1-4483-b403-2bc42e04fb3a	af1172c7-508b-44bc-a82a-5d368d7fd631	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-27 10:00:00+00	2026-01-27 10:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
f856c794-4bb5-4c88-af68-8267520278e1	af1172c7-508b-44bc-a82a-5d368d7fd631	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-26 14:00:00+00	2026-01-26 14:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
20a73880-ba64-47b4-bbb3-d5e4890c7a97	af1172c7-508b-44bc-a82a-5d368d7fd631	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-23 12:00:00+00	2026-01-23 12:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
a5651f13-fe26-4fad-9665-796f9d907cb3	64e6cb11-989f-44bc-a5e8-07dfb536c1b2	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-27 16:00:00+00	2026-01-27 16:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
b961c7af-567b-4cf3-ba4b-511e9696a817	64e6cb11-989f-44bc-a5e8-07dfb536c1b2	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-23 09:00:00+00	2026-01-23 09:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
37c39946-63e9-4f44-9e6d-75662f7572e1	2cb9bc11-2006-4d43-94b2-ce5e06614f0e	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-24 12:00:00+00	2026-01-24 12:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
b5502fb2-5b6c-4ed6-9894-f2dbdbf18971	2cb9bc11-2006-4d43-94b2-ce5e06614f0e	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-19 12:00:00+00	2026-01-19 12:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
3fda4614-a595-4504-8f30-80dc2115be00	2cb9bc11-2006-4d43-94b2-ce5e06614f0e	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-19 15:00:00+00	2026-01-19 15:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
815f4b90-be83-45cd-979d-c4e7159fa887	2cb9bc11-2006-4d43-94b2-ce5e06614f0e	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-23 10:00:00+00	2026-01-23 10:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
c8764991-d21b-4516-a511-74f7026d9719	3cf62705-6d46-44b0-91b0-42163da9dee2	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-25 11:00:00+00	2026-01-25 11:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
4db57cf4-4d58-4182-9172-53504148c449	3cf62705-6d46-44b0-91b0-42163da9dee2	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-26 17:00:00+00	2026-01-26 17:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
4d45d8d8-1092-4ced-b7f8-e7809e2fd76a	3cf62705-6d46-44b0-91b0-42163da9dee2	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-24 10:00:00+00	2026-01-24 10:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
29e429de-4add-4b5c-8783-9fbaf50c148f	3cf62705-6d46-44b0-91b0-42163da9dee2	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-22 16:00:00+00	2026-01-22 16:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
24fd8640-8dfb-4ed0-bdf3-156ed1b87dc2	0323236a-52f0-45c3-b46c-eaf20cc5c934	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-26 10:00:00+00	2026-01-26 10:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
f68a73bd-7a97-4348-b972-fd49af6eb3ab	0323236a-52f0-45c3-b46c-eaf20cc5c934	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-28 15:00:00+00	2026-01-28 15:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
8c8fe9c5-c5d8-47fd-9bd5-2123ccf6e89b	0323236a-52f0-45c3-b46c-eaf20cc5c934	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-22 08:00:00+00	2026-01-22 08:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
3411dc77-0408-492d-ad27-ff3ecbfcb053	0323236a-52f0-45c3-b46c-eaf20cc5c934	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-24 11:00:00+00	2026-01-24 11:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
5b86be2e-5860-4b55-8825-0377a2cd2d04	0323236a-52f0-45c3-b46c-eaf20cc5c934	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-26 13:00:00+00	2026-01-26 13:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
c32f3bbe-4344-4160-92af-1b17295e21fa	4f4d34d2-c89d-4154-a0a3-95540f523ba3	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-28 11:00:00+00	2026-01-28 11:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
2a3bbca9-93f6-42d6-be27-37d0a75e6c14	4f4d34d2-c89d-4154-a0a3-95540f523ba3	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-28 14:00:00+00	2026-01-28 14:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
24600b5f-2d0f-4ce1-8e77-4b2f4b8491d6	dc167392-26aa-4006-91cc-7a517e6ee903	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-25 14:00:00+00	2026-01-25 14:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
8ec66b87-7d54-4683-a093-cdc8d950764b	b1e95f01-49b4-423c-b530-b4dc265e9082	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-25 17:00:00+00	2026-01-25 17:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
81b04e1a-ebc9-4bf9-b829-6012d566e730	b1e95f01-49b4-423c-b530-b4dc265e9082	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-25 08:00:00+00	2026-01-25 08:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
519869d0-7f28-49ae-a2a7-b1fbf3fcb6bc	b1e95f01-49b4-423c-b530-b4dc265e9082	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-01-21 08:00:00+00	2026-01-21 08:45:00+00	confirmed	\N	COMPLEX_NAME_TEST	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
e6a86dd7-5146-4347-ba07-723aea2fd513	b9f03843-eee6-4607-ac5a-496c6faa9ea1	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	a7a019cb-3442-4f57-8877-1b04a1749c01	2026-04-01 10:00:00+00	2026-04-01 10:30:00+00	confirmed	\N	\N	2026-01-21 20:45:38.3443+00	2026-01-21 20:45:38.3443+00	\N	\N	\N
940c5dbc-fb55-41f8-a02c-2180c89b1c6e	a1b2c3d4-e5f6-7890-abcd-000000000001	b1b2b3b4-c5d6-7890-abcd-000000000001	c255adb2-1657-434e-804f-0a68d185c6eb	2026-02-21 09:56:32.493754+00	2026-02-21 10:26:32.493754+00	confirmed	\N	Reserva de prueba - futura confirmada	2026-02-18 23:56:32.493754+00	2026-02-18 23:56:32.493754+00	\N	\N	\N
7894478c-c7f3-4f61-8e01-dbef8173f5fb	a1b2c3d4-e5f6-7890-abcd-000000000002	b1b2b3b4-c5d6-7890-abcd-000000000001	96ee9119-f407-41cc-b816-244d8c1f1ab4	2026-02-22 13:56:32.493754+00	2026-02-22 14:41:32.493754+00	confirmed	\N	Consulta especializada - futura	2026-02-18 23:56:32.493754+00	2026-02-18 23:56:32.493754+00	\N	\N	\N
b8dff0f5-72e4-463d-9e29-191484d56ccd	a1b2c3d4-e5f6-7890-abcd-000000000003	b1b2b3b4-c5d6-7890-abcd-000000000002	fb5b259a-33ee-413a-aac2-e48bc0cba754	2026-02-24 10:56:32.493754+00	2026-02-24 11:41:32.493754+00	pending	\N	Reserva pendiente de confirmación	2026-02-18 23:56:32.493754+00	2026-02-18 23:56:32.493754+00	\N	\N	\N
ff56e5fe-b3ac-44ed-8054-dc8b8733236e	a1b2c3d4-e5f6-7890-abcd-000000000004	b1b2b3b4-c5d6-7890-abcd-000000000001	c255adb2-1657-434e-804f-0a68d185c6eb	2026-02-20 08:56:32.493754+00	2026-02-20 09:26:32.493754+00	cancelled	\N	CANCELADA - Usuario solicitó cancelación	2026-02-16 23:56:32.493754+00	2026-02-18 23:56:32.493754+00	\N	\N	\N
006dab46-0e13-48e7-b5ca-db98fc82040d	a1b2c3d4-e5f6-7890-abcd-000000000005	b1b2b3b4-c5d6-7890-abcd-000000000001	5eb7ac08-ce05-45ea-8753-ef367eb8742f	2026-02-12 14:56:32.493754+00	2026-02-12 15:16:20.493754+00	completed	\N	Atención completada exitosamente	2026-02-08 23:56:32.493754+00	2026-02-11 23:56:32.493754+00	\N	\N	\N
84ad2cac-894b-47cd-86e7-6a6998356324	a1b2c3d4-e5f6-7890-abcd-000000000006	b1b2b3b4-c5d6-7890-abcd-000000000002	fb5b259a-33ee-413a-aac2-e48bc0cba754	2026-02-16 09:56:32.493754+00	2026-02-16 10:41:32.493754+00	no_show	\N	NO_SHOW - Cliente no asistió	2026-02-13 23:56:32.493754+00	2026-02-15 23:56:32.493754+00	\N	\N	\N
9d81c829-d2af-4b3d-a2d2-9e015ce27d67	a1b2c3d4-e5f6-7890-abcd-000000000001	b1b2b3b4-c5d6-7890-abcd-000000000003	91973286-7da0-4b98-b8f8-c56ab225e4e8	2026-03-01 15:56:32.493754+00	2026-03-01 16:56:32.493754+00	rescheduled	\N	REPROGRAMADA	2026-02-17 23:56:32.493754+00	2026-02-18 23:56:32.493754+00	\N	\N	\N
\.


--
-- Data for Name: circuit_breaker_state; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.circuit_breaker_state (id, workflow_name, state, failure_count, last_failure_at, opened_at, next_attempt_at, created_at, updated_at) FROM stdin;
19c413b5-2a71-44fe-a313-3ed7f2f933f3	BB_01_Telegram_Bot	CLOSED	0	\N	\N	\N	2026-02-18 23:57:25.067695+00	2026-02-18 23:57:25.067695+00
55ba682b-8b03-42dc-8d07-2462dbc40a5a	BB_02_Booking_Flow	CLOSED	2	2026-02-18 22:57:25.067695+00	\N	\N	2026-02-18 23:57:25.067695+00	2026-02-18 23:57:25.067695+00
af4eb4c2-f932-4c8b-bf2a-5af7318114bb	BB_03_Availability_Engine	CLOSED	0	\N	\N	\N	2026-02-18 23:57:25.067695+00	2026-02-18 23:57:25.067695+00
6107166e-df11-4c4d-9c85-b31457c3e677	BB_04_GCal_Sync	HALF_OPEN	4	2026-02-18 23:52:25.067695+00	2026-02-18 23:47:25.067695+00	2026-02-19 00:02:25.067695+00	2026-02-18 23:57:25.067695+00	2026-02-18 23:57:25.067695+00
6fe913d3-33fa-4367-a682-d4106abbc1be	BB_05_Reminder_Worker	OPEN	6	2026-02-18 23:55:25.067695+00	2026-02-18 23:55:25.067695+00	2026-02-19 00:55:25.067695+00	2026-02-18 23:57:25.067695+00	2026-02-18 23:57:25.067695+00
ad090840-e6da-4a91-800e-64351e58790a	BB_06_Notification_Retry	CLOSED	1	2026-02-18 23:27:25.067695+00	\N	\N	2026-02-18 23:57:25.067695+00	2026-02-18 23:57:25.067695+00
\.


--
-- Data for Name: error_metrics; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.error_metrics (id, metric_date, workflow_name, severity, error_count, first_occurrence, last_occurrence, created_at, updated_at) FROM stdin;
aefb25a2-caac-490a-ab82-bcb26dbc60d7	2026-02-17	BB_03_Availability_Engine	LOW	5	2026-02-17 22:57:42.291225+00	2026-02-17 23:57:42.291225+00	2026-02-17 23:57:42.291225+00	2026-02-18 23:57:42.291225+00
c3fdcc3c-f300-4c8d-b502-223052be25e8	2026-02-17	BB_04_GCal_Sync	MEDIUM	3	2026-02-17 21:57:42.291225+00	2026-02-17 23:57:42.291225+00	2026-02-17 23:57:42.291225+00	2026-02-18 23:57:42.291225+00
eb469e20-6db2-42c2-9769-1dec38689c67	2026-02-18	BB_03_Availability_Engine	LOW	2	2026-02-18 21:57:42.291225+00	2026-02-18 22:57:42.291225+00	2026-02-18 23:57:42.291225+00	2026-02-18 23:57:42.291225+00
\.


--
-- Data for Name: notification_configs; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.notification_configs (id, reminder_1_hours, reminder_2_hours, is_active, created_at, updated_at, default_duration_min, min_duration_min, max_duration_min) FROM stdin;
9fe93101-96e8-4048-854d-08d2f0555cc1	24	2	t	2026-01-17 19:10:29.698019+00	2026-01-17 19:10:29.698019+00	30	15	120
\.


--
-- Data for Name: notification_queue; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.notification_queue (id, booking_id, user_id, message, priority, status, retry_count, error_message, created_at, updated_at, sent_at, next_retry_at, channel, recipient, payload, max_retries, expires_at) FROM stdin;
d839db99-1d87-4edc-8bae-cffbf2fb0c41	900f63ae-e0a1-47af-b8f7-f154452c2f02	b9f03843-eee6-4607-ac5a-496c6faa9ea1	Recordatorio: Tu reserva es mañana a las 10:00	1	pending	0	\N	2026-02-18 23:57:09.846368+00	2026-02-18 23:57:09.846368+00	\N	\N	telegram	5391760292	{"booking_id": "900f63ae-e0a1-47af-b8f7-f154452c2f02", "start_time": "2026-02-20T10:00:00+00:00"}	3	2026-02-20 09:00:00+00
ef8c665f-5f10-4ece-a1a2-53bd39208d44	940c5dbc-fb55-41f8-a02c-2180c89b1c6e	a1b2c3d4-e5f6-7890-abcd-000000000001	Recordatorio: Tu reserva es mañana a las 09:56	1	pending	0	\N	2026-02-18 23:57:09.846368+00	2026-02-18 23:57:09.846368+00	\N	\N	telegram	3000001	{"booking_id": "940c5dbc-fb55-41f8-a02c-2180c89b1c6e", "start_time": "2026-02-21T09:56:32.493754+00:00"}	3	2026-02-21 08:56:32.493754+00
650867ac-0d9e-4dba-b8e7-4570467bd72e	\N	a1b2c3d4-e5f6-7890-abcd-000000000001	Test notification failed	0	failed	3	Max retries exceeded	2026-02-18 22:57:10.021631+00	2026-02-18 23:57:10.021631+00	\N	\N	telegram	3000001	{}	3	2026-02-19 00:57:10.021631+00
155ed6c9-e191-43d8-b7fa-98d3ed5dac0b	\N	a1b2c3d4-e5f6-7890-abcd-000000000002	Test notification retry	0	pending	2	Network timeout	2026-02-18 23:27:10.216654+00	2026-02-18 23:57:10.216654+00	\N	\N	telegram	3000002	{}	3	2026-02-19 01:57:10.216654+00
\.


--
-- Data for Name: provider_cache; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.provider_cache (id, provider_id, provider_slug, data, cached_at, expires_at, created_at) FROM stdin;
0e06df34-6d0d-492a-8454-287a52c24293	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	dr-roger-auto	{"name": "Dr. Roger Auto", "email": "dev.n8n.stax@gmail.com", "services": [{"id": "a7a019cb-3442-4f57-8877-1b04a1749c01", "name": "Consulta General", "duration": 30}], "schedules": [{"day": "Monday", "end": "18:00:00", "start": "09:00:00"}, {"day": "Tuesday", "end": "18:00:00", "start": "09:00:00"}, {"day": "Wednesday", "end": "18:00:00", "start": "09:00:00"}, {"day": "Thursday", "end": "18:00:00", "start": "09:00:00"}, {"day": "Friday", "end": "18:00:00", "start": "09:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
87b7c77a-6565-42a4-954f-51527db3475a	98d6e8db-0e93-4c62-a762-0ee0dd2aff29	dr-smith	{"name": "Dr. John Smith", "email": "john.smith@example.com", "services": [], "schedules": [], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
5a9c53cb-f50d-4af7-8e84-4547d03226cb	c5d0025d-b97c-4879-9692-73a92632bb79	dr-garcia	{"name": "Dra. María García", "email": "maria.garcia@example.com", "services": [{"id": "a17fef8e-7819-4bdb-8290-bf8d03a33001", "name": "Consulta General", "duration": 30}, {"id": "ec7907b3-5ece-470d-a82f-0a2744edf60a", "name": "Consulta Especializada", "duration": 45}, {"id": "9169ad3e-a9f2-4d0a-90f0-a4add5c8d4a6", "name": "Urgencia", "duration": 20}, {"id": "17f8e9ae-9ed1-4aae-96b9-446eed2c2637", "name": "Consulta General", "duration": 30}, {"id": "74080a7e-225d-4069-99ef-92bc23b12c14", "name": "Consulta Especializada", "duration": 45}, {"id": "8232916f-2e90-49b2-a26c-de59f3c5ead2", "name": "Urgencia", "duration": 20}], "schedules": [{"day": "Monday", "end": "18:00:00", "start": "10:00:00"}, {"day": "Wednesday", "end": "18:00:00", "start": "10:00:00"}, {"day": "Friday", "end": "18:00:00", "start": "10:00:00"}, {"day": "Monday", "end": "18:00:00", "start": "10:00:00"}, {"day": "Wednesday", "end": "18:00:00", "start": "10:00:00"}, {"day": "Friday", "end": "18:00:00", "start": "10:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
485a1f85-ae53-4546-8614-1147dce21c0e	73f97ddc-306c-42d4-bd08-46dc3ee96217	dr-juan-perez	{"name": "Dr. Juan Pérez", "email": "juan.perez@test.com", "services": [{"id": "6bbce11c-797e-4012-aa50-b888c014be68", "name": "Consulta General", "duration": 30}, {"id": "0fa1bc5e-c85f-43d7-a9bb-7291c26baced", "name": "Consulta Especializada", "duration": 45}, {"id": "ff7bb38b-8be2-47e6-89f8-7c518cc97caf", "name": "Urgencia", "duration": 20}, {"id": "85098b2f-4df4-496e-b8dd-8af745a757d6", "name": "Consulta General", "duration": 30}, {"id": "861c4baf-280e-4e4e-b2e6-20648e81da04", "name": "Consulta Especializada", "duration": 45}, {"id": "ce18af9c-fff7-4043-b8fd-dbb7ad66a4cf", "name": "Urgencia", "duration": 20}], "schedules": [{"day": "Monday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Tuesday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Wednesday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Thursday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Friday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Monday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Tuesday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Wednesday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Thursday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Friday", "end": "17:00:00", "start": "09:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
9285e576-f001-40b3-9e42-0ea136c31111	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	test-provider	{"name": "Test Provider", "email": "test@test.com", "services": [{"id": "3f8495a8-8701-4e69-a5da-ed4c1e24ae30", "name": "Consulta General", "duration": 30}, {"id": "9e4b71a3-9e3e-4b17-86d9-1145b15c07bf", "name": "Consulta Especializada", "duration": 45}, {"id": "0ed3faaa-1941-4941-beb5-ca8f4af456e2", "name": "Urgencia", "duration": 20}, {"id": "6a3a4039-6e44-4994-b331-c03a52f2992d", "name": "Consulta General", "duration": 30}, {"id": "755872aa-b646-4941-a9e7-54f48eefee82", "name": "Consulta Especializada", "duration": 45}, {"id": "9ad28913-7e98-404f-ace3-707ac532b846", "name": "Urgencia", "duration": 20}], "schedules": [{"day": "Monday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Tuesday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Wednesday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Thursday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Friday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Saturday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Sunday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Monday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Tuesday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Wednesday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Thursday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Friday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Saturday", "end": "23:59:59", "start": "00:00:00"}, {"day": "Sunday", "end": "23:59:59", "start": "00:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
ef577003-ee53-43a9-9cd3-a65290bacfe3	a1b2c3d4-e5f6-7890-abcd-ef1234567890	dr-test-provider	{"name": "Dr. Test Provider", "email": null, "services": [], "schedules": [{"day": "Monday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Tuesday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Wednesday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Thursday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Friday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Saturday", "end": "13:00:00", "start": "09:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
bb2949b5-a7f0-41ac-aaea-ac057093938a	b2c3d4e5-f6a7-8901-bcde-f12345678901	dra-test-long	{"name": "Dra. Test Long Slots", "email": null, "services": [], "schedules": [{"day": "Monday", "end": "18:00:00", "start": "10:00:00"}, {"day": "Wednesday", "end": "18:00:00", "start": "10:00:00"}, {"day": "Friday", "end": "18:00:00", "start": "10:00:00"}], "slot_duration": 60}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
576471f8-dea7-443a-82ff-b972dc61911f	c3d4e5f6-a7b8-9012-cdef-123456789012	dr-no-schedule	{"name": "Dr. No Schedule", "email": null, "services": [], "schedules": [], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
9a01f3d0-caa6-498c-b3f1-952922d47654	e5f6a7b8-c9d0-1234-efab-345678901234	dr-quick	{"name": "Dr. Quick Appointments", "email": null, "services": [], "schedules": [{"day": "Tuesday", "end": "12:00:00", "start": "08:00:00"}, {"day": "Thursday", "end": "12:00:00", "start": "08:00:00"}], "slot_duration": 15}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
55f8f5ad-f04a-4905-87a0-bef822664f4f	b1b2b3b4-c5d6-7890-abcd-000000000001	dr-alejandro-vera	{"name": "Dr. Alejandro Vera", "email": "alejandro.vera@clinic.com", "services": [{"id": "c255adb2-1657-434e-804f-0a68d185c6eb", "name": "Consulta General", "duration": 30}, {"id": "96ee9119-f407-41cc-b816-244d8c1f1ab4", "name": "Consulta Especializada", "duration": 45}, {"id": "5eb7ac08-ce05-45ea-8753-ef367eb8742f", "name": "Urgencia", "duration": 20}], "schedules": [{"day": "Monday", "end": "18:00:00", "start": "09:00:00"}, {"day": "Tuesday", "end": "18:00:00", "start": "09:00:00"}, {"day": "Wednesday", "end": "18:00:00", "start": "09:00:00"}, {"day": "Thursday", "end": "18:00:00", "start": "09:00:00"}, {"day": "Friday", "end": "18:00:00", "start": "09:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
f9ace4ec-6f20-4d33-967b-2439b964e76e	b1b2b3b4-c5d6-7890-abcd-000000000002	dra-carmen-luz	{"name": "Dra. Carmen Luz", "email": "carmen.luz@clinic.com", "services": [{"id": "fb5b259a-33ee-413a-aac2-e48bc0cba754", "name": "Consulta General", "duration": 30}, {"id": "bc686116-64a8-4c11-8a02-d5915e62d11c", "name": "Consulta Especializada", "duration": 45}, {"id": "2c68d3b9-63b9-45aa-a0c9-fbfa9b08877e", "name": "Urgencia", "duration": 20}], "schedules": [{"day": "Monday", "end": "19:00:00", "start": "10:00:00"}, {"day": "Wednesday", "end": "19:00:00", "start": "10:00:00"}, {"day": "Friday", "end": "19:00:00", "start": "10:00:00"}], "slot_duration": 45}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
6806ebc4-b858-426f-8af4-9e251f95de04	b1b2b3b4-c5d6-7890-abcd-000000000003	dr-roberto-fuentes	{"name": "Dr. Roberto Fuentes", "email": "roberto.fuentes@therapy.com", "services": [{"id": "91973286-7da0-4b98-b8f8-c56ab225e4e8", "name": "Consulta General", "duration": 30}, {"id": "6ea99e31-ef0c-441a-8e87-2378fc0ba50f", "name": "Consulta Especializada", "duration": 45}], "schedules": [{"day": "Tuesday", "end": "20:00:00", "start": "08:00:00"}, {"day": "Thursday", "end": "20:00:00", "start": "08:00:00"}], "slot_duration": 60}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
3e80fb2d-a2c9-4281-b065-e06db988b14d	b1b2b3b4-c5d6-7890-abcd-000000000004	dra-lucia-mendez	{"name": "Dra. Lucia Mendez", "email": "lucia.mendez@quick.com", "services": [{"id": "bb4b13bf-92f6-4afe-94a6-0820bd9bf5ec", "name": "Consulta General", "duration": 30}, {"id": "ee0e1aa7-5e57-4484-b246-8636e8972d72", "name": "Urgencia", "duration": 20}], "schedules": [{"day": "Monday", "end": "21:00:00", "start": "07:00:00"}, {"day": "Wednesday", "end": "21:00:00", "start": "07:00:00"}, {"day": "Saturday", "end": "21:00:00", "start": "07:00:00"}, {"day": "Tuesday", "end": "21:00:00", "start": "07:00:00"}, {"day": "Thursday", "end": "21:00:00", "start": "07:00:00"}, {"day": "Friday", "end": "21:00:00", "start": "07:00:00"}], "slot_duration": 15}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
4cd1fc5e-a9f1-4f15-8e98-44cee5b1bb28	b1b2b3b4-c5d6-7890-abcd-000000000008	dr-schedule-test	{"name": "Dr. Schedule Test", "email": "schedule@test.com", "services": [{"id": "ecfd0478-cc41-476f-981c-aa5bf0d7ad73", "name": "Consulta General", "duration": 30}, {"id": "fccaa772-9008-4e57-a44e-dc60f3015798", "name": "Consulta Especializada", "duration": 45}, {"id": "d95dca5b-4b77-4c7d-8fab-9ed769d4b2ad", "name": "Urgencia", "duration": 20}], "schedules": [{"day": "Monday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Tuesday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Wednesday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Thursday", "end": "17:00:00", "start": "09:00:00"}, {"day": "Friday", "end": "17:00:00", "start": "09:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
bf846748-e84e-4086-b3ec-341cbfff8513	b1b2b3b4-c5d6-7890-abcd-000000000009	dr-weekend-only	{"name": "Dr. Weekend Only", "email": "weekend@test.com", "services": [{"id": "5660e49e-dff4-41ae-94f5-415b0ee4b56a", "name": "Consulta General", "duration": 30}], "schedules": [{"day": "Saturday", "end": "15:00:00", "start": "09:00:00"}, {"day": "Sunday", "end": "15:00:00", "start": "09:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
b20be4e5-f8ff-4f74-9f9a-f86bbc0f1b36	b1b2b3b4-c5d6-7890-abcd-000000000010	dr-night-shift	{"name": "Dr. Night Shift", "email": "night@test.com", "services": [{"id": "54f9e5bb-2503-4135-b6ad-8db5158ac61c", "name": "Consulta General", "duration": 30}], "schedules": [{"day": "Monday", "end": "23:00:00", "start": "18:00:00"}, {"day": "Wednesday", "end": "23:00:00", "start": "18:00:00"}, {"day": "Friday", "end": "23:00:00", "start": "18:00:00"}], "slot_duration": 30}	2026-02-18 23:59:55.821697+00	2026-02-19 00:59:55.821697+00	2026-02-18 23:59:55.821697+00
\.


--
-- Data for Name: providers; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.providers (id, user_id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug, slot_duration_mins) FROM stdin;
2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	\N	Dr. Roger Auto	dev.n8n.stax@gmail.com	dev.n8n.stax@gmail.com	30	2	t	2026-01-15 14:52:06.081827+00	\N	dr-roger-auto	30
98d6e8db-0e93-4c62-a762-0ee0dd2aff29	\N	Dr. John Smith	john.smith@example.com	\N	30	2	t	2026-01-26 00:14:22.426419+00	\N	dr-smith	30
c5d0025d-b97c-4879-9692-73a92632bb79	\N	Dra. María García	maria.garcia@example.com	\N	30	2	t	2026-01-26 00:14:22.426419+00	\N	dr-garcia	30
73f97ddc-306c-42d4-bd08-46dc3ee96217	6daa9018-1df4-4dc3-a761-100e1ae11a09	Dr. Juan Pérez	juan.perez@test.com	juan.perez@gmail.com	30	2	t	2026-01-26 21:27:45.344063+00	\N	dr-juan-perez	30
11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	6daa9018-1df4-4dc3-a761-100e1ae11a09	Test Provider	test@test.com	test@gmail.com	30	1	t	2026-01-26 21:27:45.344063+00	\N	test-provider	30
ae1d057b-ec08-45ee-9303-606a712cd9bd	6daa9018-1df4-4dc3-a761-100e1ae11a09	Deleted Provider	deleted@test.com	deleted@gmail.com	30	2	f	2026-01-26 21:27:45.344063+00	2026-01-26 21:27:45.344063+00	deleted-provider	30
a1b2c3d4-e5f6-7890-abcd-ef1234567890	\N	Dr. Test Provider	\N	\N	30	2	t	2026-02-10 13:17:44.098341+00	\N	dr-test-provider	30
b2c3d4e5-f6a7-8901-bcde-f12345678901	\N	Dra. Test Long Slots	\N	\N	30	2	t	2026-02-10 13:17:44.488328+00	\N	dra-test-long	60
c3d4e5f6-a7b8-9012-cdef-123456789012	\N	Dr. No Schedule	\N	\N	30	2	t	2026-02-10 13:17:44.637806+00	\N	dr-no-schedule	30
d4e5f6a7-b8c9-0123-defa-234567890123	\N	Dr. Deleted	\N	\N	30	2	t	2026-02-10 13:17:44.783511+00	2026-02-10 13:17:44.783511+00	dr-deleted	30
e5f6a7b8-c9d0-1234-efab-345678901234	\N	Dr. Quick Appointments	\N	\N	30	2	t	2026-02-10 13:17:44.933549+00	\N	dr-quick	15
b1b2b3b4-c5d6-7890-abcd-000000000001	\N	Dr. Alejandro Vera	alejandro.vera@clinic.com	alejandro.vera@gmail.com	30	4	t	2025-12-20 23:40:44.180659+00	\N	dr-alejandro-vera	30
b1b2b3b4-c5d6-7890-abcd-000000000002	\N	Dra. Carmen Luz	carmen.luz@clinic.com	\N	45	2	t	2026-01-04 23:40:44.349277+00	\N	dra-carmen-luz	45
b1b2b3b4-c5d6-7890-abcd-000000000003	\N	Dr. Roberto Fuentes	roberto.fuentes@therapy.com	roberto.f@gmail.com	60	24	t	2026-01-19 23:40:44.509135+00	\N	dr-roberto-fuentes	60
b1b2b3b4-c5d6-7890-abcd-000000000004	\N	Dra. Lucia Mendez	lucia.mendez@quick.com	\N	15	1	t	2026-01-29 23:40:44.727938+00	\N	dra-lucia-mendez	15
b1b2b3b4-c5d6-7890-abcd-000000000005	\N	Dr. Disabled Test	disabled@test.com	\N	30	2	f	2026-02-03 23:40:44.8891+00	\N	dr-disabled-seed	30
b1b2b3b4-c5d6-7890-abcd-000000000006	\N	Dr. Old Provider	old@provider.com	\N	30	2	t	2025-11-20 23:40:45.069158+00	2026-01-19 23:40:45.069158+00	dr-old-provider-seed	30
b1b2b3b4-c5d6-7890-abcd-000000000008	\N	Dr. Schedule Test	schedule@test.com	\N	30	2	t	2026-02-18 23:40:45.228056+00	\N	dr-schedule-test	30
b1b2b3b4-c5d6-7890-abcd-000000000009	\N	Dr. Weekend Only	weekend@test.com	\N	30	2	t	2026-02-18 23:40:45.437533+00	\N	dr-weekend-only	30
b1b2b3b4-c5d6-7890-abcd-000000000010	\N	Dr. Night Shift	night@test.com	\N	30	2	t	2026-02-18 23:40:45.601384+00	\N	dr-night-shift	30
\.


--
-- Data for Name: schedules; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.schedules (id, provider_id, day_of_week, start_time, end_time, is_active) FROM stdin;
11ec1378-e56a-4158-aeec-61b4117b3b6d	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	Monday	09:00:00	18:00:00	t
64d464c9-9de3-42ac-9303-172aaab0ec1c	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	Tuesday	09:00:00	18:00:00	t
a2de1155-cd48-49d3-b182-805ac83d1c74	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	Wednesday	09:00:00	18:00:00	t
a23bfcb3-9296-4b54-b273-b67855a7004a	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	Thursday	09:00:00	18:00:00	t
9011f0de-5887-4544-b11e-1b5dc028bd85	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	Friday	09:00:00	18:00:00	t
4d5dc2e6-11a1-4a72-9f6d-36f7ab0bde9d	73f97ddc-306c-42d4-bd08-46dc3ee96217	Monday	09:00:00	17:00:00	t
691639fd-b7fe-4abe-b117-6240bf3dc564	73f97ddc-306c-42d4-bd08-46dc3ee96217	Tuesday	09:00:00	17:00:00	t
c432e0be-b987-4dbe-a386-160d2cbda9bb	73f97ddc-306c-42d4-bd08-46dc3ee96217	Wednesday	09:00:00	17:00:00	t
d2c4aa9d-ff0c-4ecc-9177-bcdaf2c4aeda	73f97ddc-306c-42d4-bd08-46dc3ee96217	Thursday	09:00:00	17:00:00	t
36d6c2bd-5d04-46a4-9ca0-432a74447152	73f97ddc-306c-42d4-bd08-46dc3ee96217	Friday	09:00:00	17:00:00	t
2553a60f-bbfc-4522-b450-3c8df46de49b	c5d0025d-b97c-4879-9692-73a92632bb79	Monday	10:00:00	18:00:00	t
9b3ae089-11ef-4efd-ae26-c99221250f04	c5d0025d-b97c-4879-9692-73a92632bb79	Wednesday	10:00:00	18:00:00	t
45a538bf-59cb-445b-9e3a-99583c82a4e4	c5d0025d-b97c-4879-9692-73a92632bb79	Friday	10:00:00	18:00:00	t
5b0e0532-2fd0-4b1e-9106-4f1a874279f3	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Monday	00:00:00	23:59:59	t
13ece2d7-d4d9-451f-94f5-a018f27f8f20	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Tuesday	00:00:00	23:59:59	t
a144dbac-c376-4c18-81ec-e528101d321d	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Wednesday	00:00:00	23:59:59	t
a8a4494a-f8fb-4fa6-be79-92f1ffad8e48	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Thursday	00:00:00	23:59:59	t
34a7079a-e4d9-49c6-b4b0-ee185f5e0b27	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Friday	00:00:00	23:59:59	t
5fbe0e60-9e8c-479d-bd2d-b649ce8de054	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Saturday	00:00:00	23:59:59	t
d181861c-e6cd-4a7d-9333-760b3c103ebd	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Sunday	00:00:00	23:59:59	t
9cb553bf-51a4-41e8-8aeb-f8fb722a53b3	73f97ddc-306c-42d4-bd08-46dc3ee96217	Monday	09:00:00	17:00:00	t
12fa973f-65b8-4ad2-a04d-ca1b92402f20	73f97ddc-306c-42d4-bd08-46dc3ee96217	Tuesday	09:00:00	17:00:00	t
294aeac0-0ed7-4c50-9375-90ad85d61533	73f97ddc-306c-42d4-bd08-46dc3ee96217	Wednesday	09:00:00	17:00:00	t
c6748203-25c3-4ba5-ae13-bd0c2e46a59b	73f97ddc-306c-42d4-bd08-46dc3ee96217	Thursday	09:00:00	17:00:00	t
2a4db3c6-37eb-4dd8-bc92-4d59db863550	73f97ddc-306c-42d4-bd08-46dc3ee96217	Friday	09:00:00	17:00:00	t
b9e2f797-275f-4073-8f62-c322512db5c5	c5d0025d-b97c-4879-9692-73a92632bb79	Monday	10:00:00	18:00:00	t
17ffc260-9390-4169-a5ad-8d1719f525b6	c5d0025d-b97c-4879-9692-73a92632bb79	Wednesday	10:00:00	18:00:00	t
db0c3de9-aec7-431b-83e2-a283ea3482f2	c5d0025d-b97c-4879-9692-73a92632bb79	Friday	10:00:00	18:00:00	t
d4245111-6177-42ef-8961-c255b02c41a1	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Monday	00:00:00	23:59:59	t
620f3df8-1f55-4fb9-9cfa-a0335ddbba89	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Tuesday	00:00:00	23:59:59	t
8f7a581a-ea83-48d5-a848-9ef7360a34ff	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Wednesday	00:00:00	23:59:59	t
6f678c4b-8ef0-49ab-8370-c24c84397510	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Thursday	00:00:00	23:59:59	t
bbf5e47e-18cd-4d45-a53a-7c79ec69d312	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Friday	00:00:00	23:59:59	t
545657b3-ffcd-435a-9a8c-9e8f3a2776c8	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Saturday	00:00:00	23:59:59	t
60c70352-1ca7-42a9-94a9-72ac88d0bcc2	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Sunday	00:00:00	23:59:59	t
74b3309d-9e42-4407-9fee-5161f65f2e7c	a1b2c3d4-e5f6-7890-abcd-ef1234567890	Monday	09:00:00	17:00:00	t
1e5ac391-3ed1-42cd-a737-db63308358c1	a1b2c3d4-e5f6-7890-abcd-ef1234567890	Tuesday	09:00:00	17:00:00	t
ccb35933-3fd3-4701-b76e-78b6b96d7b5f	a1b2c3d4-e5f6-7890-abcd-ef1234567890	Wednesday	09:00:00	17:00:00	t
57dbb0e3-bf03-4e2f-99cd-fe734f6276f3	a1b2c3d4-e5f6-7890-abcd-ef1234567890	Thursday	09:00:00	17:00:00	t
a0639546-af41-45d2-902e-700ab7ced5ff	a1b2c3d4-e5f6-7890-abcd-ef1234567890	Friday	09:00:00	17:00:00	t
22ae17cc-41e8-41c1-93f5-087e3a7b87a3	a1b2c3d4-e5f6-7890-abcd-ef1234567890	Saturday	09:00:00	13:00:00	f
b14dde8f-a9fb-4e07-995a-ef8f4a4ce751	b2c3d4e5-f6a7-8901-bcde-f12345678901	Monday	10:00:00	18:00:00	t
ae410f0d-dd5a-4892-9d73-9d42bc04fcb9	b2c3d4e5-f6a7-8901-bcde-f12345678901	Wednesday	10:00:00	18:00:00	t
8743a8ea-be8c-43c9-8f96-fa0bbeef9eab	b2c3d4e5-f6a7-8901-bcde-f12345678901	Friday	10:00:00	18:00:00	t
e27329be-f1f4-43c5-afd1-d103c9884103	e5f6a7b8-c9d0-1234-efab-345678901234	Tuesday	08:00:00	12:00:00	t
22b95497-d804-4f9a-a845-020cf70ec471	e5f6a7b8-c9d0-1234-efab-345678901234	Thursday	08:00:00	12:00:00	t
56245c48-d87e-4128-a3c6-5d0873d6981a	b1b2b3b4-c5d6-7890-abcd-000000000001	Monday	09:00:00	18:00:00	t
248b5cbe-3930-4795-b1d0-c0bcc514f27d	b1b2b3b4-c5d6-7890-abcd-000000000001	Tuesday	09:00:00	18:00:00	t
0b09fd72-067d-4bd7-901d-878859e4e5c3	b1b2b3b4-c5d6-7890-abcd-000000000001	Wednesday	09:00:00	18:00:00	t
e45b6d39-d22e-4079-8f83-26cd4a41fd31	b1b2b3b4-c5d6-7890-abcd-000000000001	Thursday	09:00:00	18:00:00	t
bc125258-ba96-4ec0-8e7e-1a4dc07b4925	b1b2b3b4-c5d6-7890-abcd-000000000001	Friday	09:00:00	18:00:00	t
7df10605-a755-4412-ad1f-855024daa828	b1b2b3b4-c5d6-7890-abcd-000000000002	Monday	10:00:00	19:00:00	t
937b9431-6a95-46e4-8123-b3a616465167	b1b2b3b4-c5d6-7890-abcd-000000000002	Wednesday	10:00:00	19:00:00	t
09481566-35b5-40d4-9906-48ff6ac0c540	b1b2b3b4-c5d6-7890-abcd-000000000002	Friday	10:00:00	19:00:00	t
75b48c9b-710f-4947-a078-09615155f558	b1b2b3b4-c5d6-7890-abcd-000000000003	Tuesday	08:00:00	20:00:00	t
46cc7383-1458-4178-b899-94015a7023e7	b1b2b3b4-c5d6-7890-abcd-000000000003	Thursday	08:00:00	20:00:00	t
bbe13396-4250-4b1f-8f5d-4356dc1639f2	b1b2b3b4-c5d6-7890-abcd-000000000004	Monday	07:00:00	21:00:00	t
6d63ee85-785f-4bc9-bc81-c75685779678	b1b2b3b4-c5d6-7890-abcd-000000000004	Wednesday	07:00:00	21:00:00	t
a89a7735-1203-4a93-a423-ca26ed521942	b1b2b3b4-c5d6-7890-abcd-000000000004	Saturday	07:00:00	21:00:00	t
103320c7-3b03-446d-97e7-c47f6dc610e8	b1b2b3b4-c5d6-7890-abcd-000000000004	Tuesday	07:00:00	21:00:00	t
cddb319c-643a-4f5b-9a57-f0a5b718b0ba	b1b2b3b4-c5d6-7890-abcd-000000000004	Thursday	07:00:00	21:00:00	t
1d7fc00e-0c2d-418c-aebe-83e5cdc25f77	b1b2b3b4-c5d6-7890-abcd-000000000004	Friday	07:00:00	21:00:00	t
60e30d17-5824-4df9-974d-33520ea46347	b1b2b3b4-c5d6-7890-abcd-000000000008	Monday	09:00:00	17:00:00	t
daa83ced-d5a7-4a3e-93f8-86ec232817c2	b1b2b3b4-c5d6-7890-abcd-000000000008	Tuesday	09:00:00	17:00:00	t
584bca54-694d-45cf-ac95-5ac36aa84980	b1b2b3b4-c5d6-7890-abcd-000000000008	Wednesday	09:00:00	17:00:00	t
31e72eff-3869-4fc4-b90a-c400d6dde2db	b1b2b3b4-c5d6-7890-abcd-000000000008	Thursday	09:00:00	17:00:00	t
47fcb019-a697-4bb5-9fd0-5f07bd382f03	b1b2b3b4-c5d6-7890-abcd-000000000008	Friday	09:00:00	17:00:00	t
c69f2d0c-c81a-4c0c-8ad2-7eab25741e80	b1b2b3b4-c5d6-7890-abcd-000000000009	Saturday	09:00:00	15:00:00	t
0fc0f11f-a5be-40e5-9c98-8b5e8e3dc5bc	b1b2b3b4-c5d6-7890-abcd-000000000009	Sunday	09:00:00	15:00:00	t
36e5ef2c-0bf4-4519-b510-ad931a04c576	b1b2b3b4-c5d6-7890-abcd-000000000010	Monday	18:00:00	23:00:00	t
520c690d-8782-4065-af73-fdbd0dce1d7b	b1b2b3b4-c5d6-7890-abcd-000000000010	Wednesday	18:00:00	23:00:00	t
adbdcf04-6368-42ef-966f-a114b8d01c90	b1b2b3b4-c5d6-7890-abcd-000000000010	Friday	18:00:00	23:00:00	t
\.


--
-- Data for Name: security_firewall; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.security_firewall (id, entity_id, strike_count, is_blocked, blocked_until, last_strike_at, created_at, updated_at) FROM stdin;
068efb91-b4bb-473a-b08c-fa69aa01686d	telegram:CERT_TEST_USER	1	f	\N	2026-01-16 21:20:19.857775+00	2026-01-16 21:20:19.857775+00	2026-01-16 21:20:19.857775+00
bd5475e3-0806-4b8b-9fed-c9b31f062fd4	entity_123	1	f	\N	2026-01-16 22:00:17.802872+00	2026-01-16 22:00:17.802872+00	2026-01-16 22:00:17.802872+00
dc6429f9-b971-4e67-b89a-7caa052b506c	telegram:5391760292	1	f	\N	2026-01-16 22:06:44.832169+00	2026-01-16 22:06:44.832169+00	2026-01-16 22:06:44.832169+00
a7ab82c3-a1d8-4db3-8248-cc858f236be1	telegram:3000014	1	f	\N	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00
1a325040-ffc7-4f41-9b2d-9fefb95b51ab	telegram:3000015	3	f	\N	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00
4eaad77f-d484-4cdb-8857-9392e79c9647	telegram:3000016	5	t	2026-02-19 01:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00
01019061-362a-4f38-8d16-f394cd8b478e	telegram:999999001	0	f	\N	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00
9812623d-7058-43eb-8690-c4eff15f51a7	telegram:999999002	10	t	\N	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00
c97d96a4-9a02-45a1-ae57-d00f8e22ef3c	ip:192.168.1.100	2	f	\N	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00
52dc06b7-f2de-4882-924e-2e15c3286565	ip:10.0.0.50	7	t	2026-02-19 23:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00	2026-02-18 23:56:56.677985+00
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.services (id, provider_id, name, description, duration_minutes, price, tier, active) FROM stdin;
a7a019cb-3442-4f57-8877-1b04a1749c01	2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	Consulta General	\N	30	0.00	standard	t
a17fef8e-7819-4bdb-8290-bf8d03a33001	c5d0025d-b97c-4879-9692-73a92632bb79	Consulta General	Consulta médica general	30	50.00	standard	t
ec7907b3-5ece-470d-a82f-0a2744edf60a	c5d0025d-b97c-4879-9692-73a92632bb79	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
9169ad3e-a9f2-4d0a-90f0-a4add5c8d4a6	c5d0025d-b97c-4879-9692-73a92632bb79	Urgencia	Atención de urgencia	20	120.00	emergency	t
6bbce11c-797e-4012-aa50-b888c014be68	73f97ddc-306c-42d4-bd08-46dc3ee96217	Consulta General	Consulta médica general	30	50.00	standard	t
0fa1bc5e-c85f-43d7-a9bb-7291c26baced	73f97ddc-306c-42d4-bd08-46dc3ee96217	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
ff7bb38b-8be2-47e6-89f8-7c518cc97caf	73f97ddc-306c-42d4-bd08-46dc3ee96217	Urgencia	Atención de urgencia	20	120.00	emergency	t
3f8495a8-8701-4e69-a5da-ed4c1e24ae30	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Consulta General	Consulta médica general	30	50.00	standard	t
9e4b71a3-9e3e-4b17-86d9-1145b15c07bf	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
0ed3faaa-1941-4941-beb5-ca8f4af456e2	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Urgencia	Atención de urgencia	20	120.00	emergency	t
17f8e9ae-9ed1-4aae-96b9-446eed2c2637	c5d0025d-b97c-4879-9692-73a92632bb79	Consulta General	Consulta médica general	30	50.00	standard	t
74080a7e-225d-4069-99ef-92bc23b12c14	c5d0025d-b97c-4879-9692-73a92632bb79	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
8232916f-2e90-49b2-a26c-de59f3c5ead2	c5d0025d-b97c-4879-9692-73a92632bb79	Urgencia	Atención de urgencia	20	120.00	emergency	t
85098b2f-4df4-496e-b8dd-8af745a757d6	73f97ddc-306c-42d4-bd08-46dc3ee96217	Consulta General	Consulta médica general	30	50.00	standard	t
861c4baf-280e-4e4e-b2e6-20648e81da04	73f97ddc-306c-42d4-bd08-46dc3ee96217	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
ce18af9c-fff7-4043-b8fd-dbb7ad66a4cf	73f97ddc-306c-42d4-bd08-46dc3ee96217	Urgencia	Atención de urgencia	20	120.00	emergency	t
6a3a4039-6e44-4994-b331-c03a52f2992d	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Consulta General	Consulta médica general	30	50.00	standard	t
755872aa-b646-4941-a9e7-54f48eefee82	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
9ad28913-7e98-404f-ace3-707ac532b846	11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	Urgencia	Atención de urgencia	20	120.00	emergency	t
c255adb2-1657-434e-804f-0a68d185c6eb	b1b2b3b4-c5d6-7890-abcd-000000000001	Consulta General	Consulta médica general	30	50.00	standard	t
fb5b259a-33ee-413a-aac2-e48bc0cba754	b1b2b3b4-c5d6-7890-abcd-000000000002	Consulta General	Consulta médica general	30	50.00	standard	t
91973286-7da0-4b98-b8f8-c56ab225e4e8	b1b2b3b4-c5d6-7890-abcd-000000000003	Consulta General	Consulta médica general	30	50.00	standard	t
bb4b13bf-92f6-4afe-94a6-0820bd9bf5ec	b1b2b3b4-c5d6-7890-abcd-000000000004	Consulta General	Consulta médica general	30	50.00	standard	t
ecfd0478-cc41-476f-981c-aa5bf0d7ad73	b1b2b3b4-c5d6-7890-abcd-000000000008	Consulta General	Consulta médica general	30	50.00	standard	t
5660e49e-dff4-41ae-94f5-415b0ee4b56a	b1b2b3b4-c5d6-7890-abcd-000000000009	Consulta General	Consulta médica general	30	50.00	standard	t
54f9e5bb-2503-4135-b6ad-8db5158ac61c	b1b2b3b4-c5d6-7890-abcd-000000000010	Consulta General	Consulta médica general	30	50.00	standard	t
96ee9119-f407-41cc-b816-244d8c1f1ab4	b1b2b3b4-c5d6-7890-abcd-000000000001	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
bc686116-64a8-4c11-8a02-d5915e62d11c	b1b2b3b4-c5d6-7890-abcd-000000000002	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
6ea99e31-ef0c-441a-8e87-2378fc0ba50f	b1b2b3b4-c5d6-7890-abcd-000000000003	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
fccaa772-9008-4e57-a44e-dc60f3015798	b1b2b3b4-c5d6-7890-abcd-000000000008	Consulta Especializada	Consulta con especialista	45	80.00	premium	t
5eb7ac08-ce05-45ea-8753-ef367eb8742f	b1b2b3b4-c5d6-7890-abcd-000000000001	Urgencia	Atención de urgencia	20	120.00	emergency	t
2c68d3b9-63b9-45aa-a0c9-fbfa9b08877e	b1b2b3b4-c5d6-7890-abcd-000000000002	Urgencia	Atención de urgencia	20	120.00	emergency	t
ee0e1aa7-5e57-4484-b246-8636e8972d72	b1b2b3b4-c5d6-7890-abcd-000000000004	Urgencia	Atención de urgencia	20	120.00	emergency	t
d95dca5b-4b77-4c7d-8fab-9ed769d4b2ad	b1b2b3b4-c5d6-7890-abcd-000000000008	Urgencia	Atención de urgencia	20	120.00	emergency	t
\.


--
-- Data for Name: system_errors; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.system_errors (error_id, workflow_name, workflow_execution_id, error_type, severity, error_message, error_stack, error_context, user_id, created_at, resolved_at, is_resolved, resolution_notes) FROM stdin;
3b4f6cb6-7b00-4b81-85f1-39e48b3f9b31	Manual_Test	\N	\N	\N	Checking Insert	\N	\N	\N	2026-01-15 19:44:04.618267+00	\N	f	\N
465569c5-656b-46aa-b90a-87e8dc160513	ROGER_ALERTS	314	INFO	LOW	Watchtower Online	\N	{}	\N	2026-01-15 21:46:56.152295+00	\N	f	\N
1c670e1d-a2e7-465f-8ab4-7aa261cd0122	ROGER_ALERTS	315	INFO	LOW	Watchtower Online	\N	{}	\N	2026-01-15 22:00:24.335139+00	\N	f	\N
c6a4130b-1183-4a7a-bc81-393000f4da34	HTML_FIX_TEST	317	INFO	LOW	Testing HTML Parse Mode	\N	{}	\N	2026-01-15 22:05:46.433014+00	\N	f	\N
072982a9-f8c2-460a-bf91-903157ade284	StressTest	322	UNKNOWN	ERROR	aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	\N	{}	\N	2026-01-15 22:08:25.493265+00	\N	f	\N
59f1d1a5-1d1e-4ac2-bc3a-e3622dae7d99	DeepTest	323	UNKNOWN	ERROR	Nested	\N	{"level1": {"level2": {"level3": "value"}}}	\N	2026-01-15 22:08:32.562809+00	\N	f	\N
65ca488f-e29f-4f69-9018-134ec54e000f	EnumTest	325	UNKNOWN	LOW	foo	\N	{}	\N	2026-01-15 22:08:46.662653+00	\N	f	\N
7f17dd4c-7215-49c5-85d8-023073c90960	BoundaryTest	326	UNKNOWN	ERROR	test	\N	{}	\N	2026-01-15 22:10:37.464039+00	\N	f	\N
5925c92d-5191-4eb3-8dca-5e040586958e	BoundaryTest	327	UNKNOWN	ERROR	test	\N	{}	\N	2026-01-15 22:10:45.038655+00	\N	f	\N
cc63bdd3-a373-4ef8-b30c-64c2b0e59439	BoundaryTest	328	UNKNOWN	NUCLEAR	test	\N	{}	\N	2026-01-15 22:10:52.619162+00	\N	f	\N
7e873fcb-b7cb-4192-93db-4baf940cc119	BoundaryTest	329	UNKNOWN	ERROR	test	\N	{}	\N	2026-01-15 22:11:00.11801+00	\N	f	\N
2f59da40-8fd4-4573-b9dc-5466697daf69	STRIKE_TEST	333	VALIDATION	ERROR	Invalid RUT detected	\N	{}	\N	2026-01-15 22:29:37.067407+00	\N	f	\N
4011060c-bc79-4241-bc8a-a13f700ce5c3	FIREWALL_TEST	339	VALIDATION	MEDIUM	Simulated RUT Failure #1	\N	{}	\N	2026-01-16 13:59:49.547928+00	\N	f	\N
a1e81f0e-dff6-4b39-8404-6f58f711e811	FIREWALL_TEST	340	VALIDATION	MEDIUM	Simulated RUT Failure #2	\N	{}	\N	2026-01-16 13:59:58.612759+00	\N	f	\N
09c61a4e-7996-4326-8d52-3959e695557d	FIREWALL_TEST	341	VALIDATION	MEDIUM	Simulated RUT Failure #3	\N	{}	\N	2026-01-16 14:00:07.002452+00	\N	f	\N
669526e6-e092-49f9-9e59-cf80410a18df	DEBUG_STRIKE	343	VALIDATION	ERROR	Manual Test	\N	{}	\N	2026-01-16 14:00:57.33626+00	\N	f	\N
d0d3a942-54a5-4f7a-9a22-a8e27fdb5a38	FIREWALL_TEST	344	VALIDATION	MEDIUM	Simulated RUT Failure #1	\N	{}	\N	2026-01-16 14:11:47.742607+00	\N	f	\N
1a301a0a-0254-48e8-9dc7-4dc32ea30ace	FIREWALL_TEST	345	VALIDATION	MEDIUM	Simulated RUT Failure #2	\N	{}	\N	2026-01-16 14:11:56.282393+00	\N	f	\N
99138bac-a186-47d0-b889-7b83f3b92c84	FIREWALL_TEST	346	VALIDATION	MEDIUM	Simulated RUT Failure #3	\N	{}	\N	2026-01-16 14:12:04.477978+00	\N	f	\N
eb90d3e4-3fa9-48c0-bcd9-8be7ab96bdfd	DIAGNOSTIC_STRIKE	347	VALIDATION	ERROR	Checking strike_applied field	\N	{}	\N	2026-01-16 14:13:53.082593+00	\N	f	\N
c311a867-be60-464a-a88d-9a1b05e103fa	FIREWALL_TEST	348	VALIDATION	MEDIUM	Simulated RUT Failure #1	\N	{}	\N	2026-01-16 14:17:47.888894+00	\N	f	\N
a004ef4d-e4c8-4a34-89eb-9ee29e94d774	FIREWALL_TEST	349	VALIDATION	MEDIUM	Simulated RUT Failure #2	\N	{}	\N	2026-01-16 14:17:56.003222+00	\N	f	\N
d814e01c-fa8d-49ba-82f4-08e0055638de	FIREWALL_TEST	350	VALIDATION	MEDIUM	Simulated RUT Failure #3	\N	{}	\N	2026-01-16 14:18:03.874123+00	\N	f	\N
e8f85b75-32b0-4dbc-8fa9-e4a3d476c323	CERT_FLOW	352	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 14:32:33.272062+00	\N	f	\N
7273f3ed-727e-4fa9-995a-c2686554ae6b	CERT_FLOW	353	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 14:32:48.918813+00	\N	f	\N
ac36992f-a3f3-48c2-96bc-19edabc2fa84	DEBUG_CERT	354	UNKNOWN	ERROR	Check Strike	\N	{}	\N	2026-01-16 14:33:59.203798+00	\N	f	\N
b332fd2e-8931-42fa-a6e1-15843ab2eff3	CERT_FLOW	356	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 14:39:03.099662+00	\N	f	\N
d472ce76-c790-4972-847a-304c28368244	CERT_FLOW	357	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 14:39:12.156821+00	\N	f	\N
5f8d6905-fa98-40f0-83cc-e1708d0534fc	CERT_FLOW	358	UNKNOWN	ERROR	Strike Manual	\N	{}	\N	2026-01-16 14:41:19.109614+00	\N	f	\N
299ec4f9-f8c1-4d05-83ca-48fdfe6651e9	CERT_FLOW	360	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 14:58:59.052864+00	\N	f	\N
e2e36459-9e40-4be7-9e41-32354cfcd4e9	CERT_FLOW	361	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 14:59:14.111527+00	\N	f	\N
c46b7066-0149-4e10-8834-fa0163a3eaa8	CERT_FLOW	364	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 15:16:13.976621+00	\N	f	\N
73aab834-21de-47fe-b5d3-eb2efc66dc24	CERT_FLOW	365	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 15:16:28.777831+00	\N	f	\N
92ca1690-dfb7-437c-9eac-27c72a4fa85c	CERT_FLOW	367	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 15:32:34.290094+00	\N	f	\N
efee3415-e81e-4e95-a90b-d27960f0a997	CERT_FLOW	368	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 15:32:49.034662+00	\N	f	\N
bccf2f9e-5286-4a93-8c96-de79262219d8	CERT_FLOW	370	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 15:35:50.190031+00	\N	f	\N
f15d8a18-66d1-4deb-abe8-c69c678b5309	CERT_FLOW	371	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 15:36:05.116877+00	\N	f	\N
d990ef5c-2ecc-41ab-8beb-0e11d059916d	DEBUG_V8	372	UNKNOWN	ERROR	Check Response	\N	{}	\N	2026-01-16 15:37:56.688346+00	\N	f	\N
de2dbfde-a950-4b09-8885-176e8c4d8c1a	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 17:02:52.340504+00	\N	f	\N
dc3438f6-28af-4b00-b2a0-b496f445b656	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 17:03:00.058446+00	\N	f	\N
e61b1f5d-8798-4082-929f-61f46c7f8b65	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 17:23:04.248383+00	\N	f	\N
a4121f39-e857-4e94-bfa9-034c5f68a858	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 17:23:12.363028+00	\N	f	\N
6bd9375a-bf58-4f38-afd1-f1c3f4355291	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 17:33:55.692907+00	\N	f	\N
08d0ff84-2026-4cb1-9dd6-11a7665cbeb0	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 17:34:09.241114+00	\N	f	\N
52722f5e-a4f2-41c6-a9a6-eaa08f0c047c	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 17:59:17.891899+00	\N	f	\N
4131d866-edcb-46a8-b103-df342d9866cf	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 17:59:26.14224+00	\N	f	\N
640febc1-a933-453f-b884-b4d0e222bf13	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:26:14.942147+00	\N	f	\N
a0303b94-a02d-4e09-9241-9f247f61154e	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:26:29.972011+00	\N	f	\N
255b930c-ca9d-45e7-acd3-54c82fbb0d83	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:28:42.092963+00	\N	f	\N
7390a5b2-a50d-4ebb-9d4a-1c03a9f035cf	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:28:55.986015+00	\N	f	\N
f367a541-b540-46b9-919c-60410e6c3544	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:30:04.106966+00	\N	f	\N
25d1a622-1443-4485-966f-ff7569f81d7c	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:30:18.146243+00	\N	f	\N
f198e421-7e86-43a0-ad6b-7254ca21f7da	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:31:20.782513+00	\N	f	\N
63789bf0-a783-4306-b313-0cf0194a5cf0	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:31:35.003225+00	\N	f	\N
8080e1ad-672b-47e9-96d5-55eac93e22d5	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:40:44.002505+00	\N	f	\N
2f7dbb1b-9a5d-4edd-b89f-a65a74ddc9c2	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:40:57.517798+00	\N	f	\N
4caed030-5ed3-45e5-9e7a-c32f439cf987	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 19:13:54.028451+00	\N	f	\N
5a6427ce-e8a7-4407-9a53-6166acb418b7	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 19:14:01.93815+00	\N	f	\N
7da2d390-1686-41ee-8372-d5c0077043e9	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 19:18:57.067741+00	\N	f	\N
d49e5d86-528a-4d6b-947a-5617859bfa4c	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 19:19:06.130382+00	\N	f	\N
ffcff5e6-2b5b-4296-a2f2-9f778e07f371	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 19:44:16.166083+00	\N	f	\N
09fb7b0d-9ac2-4d4d-8b0c-c8b5d0f68afa	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 19:44:30.092257+00	\N	f	\N
523f4315-fca0-48dc-997f-1145b80b457c	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 20:12:58.803682+00	\N	f	\N
4efd09ef-7261-4f60-98d6-d277abbc9e88	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 20:13:12.412227+00	\N	f	\N
5ec33a5a-a8f7-4c9b-95b0-00cccb97b4e6	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 20:17:38.301461+00	\N	f	\N
fd382c0d-1b3e-4658-9fae-642422577287	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 20:17:46.4877+00	\N	f	\N
37365c15-839e-4f8c-b37a-99b5a9441367	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 20:42:30.231697+00	\N	f	\N
e8a9cea1-42ef-423d-afc6-5e388dc5ea40	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 20:42:44.513742+00	\N	f	\N
a393be9d-9f8c-4b9b-a03a-bf76522b6c62	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 21:20:04.641039+00	\N	f	\N
a67b95f5-c411-46ac-9960-89008d1a1dc8	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 21:20:18.634771+00	\N	f	\N
e7611576-1ca8-44db-9e44-95299ad56210	Test Workflow	\N	UNKNOWN	ERROR	Test Error Message	\N	{}	\N	2026-01-16 22:00:15.374054+00	\N	f	\N
8916766d-8d1a-433f-9848-59d61dad9536	Test Workflow	\N	INFO	WARNING	Test Error Message	\N	{}	\N	2026-01-16 22:00:16.69291+00	\N	f	\N
b501fc07-33f0-49b1-9747-254554c06242	TEST_WORKFLOW	\N	INFO	WARNING	Prueba de notificación de Telegram	\N	{}	\N	2026-01-16 22:06:43.752284+00	\N	f	\N
718be978-d50c-42a1-8490-740a8dba6b50	AVAILABILITY_V4_DEBUG	\N	\N	CRITICAL	Workflow crashed at DB level	\N	\N	\N	2026-01-16 22:26:07.284784+00	\N	f	\N
8f24add1-add2-436c-bcc4-6e78c274f6fa	AVAILABILITY_V5_DEBUG	\N	\N	CRITICAL	Still crashing after reference fix	\N	\N	\N	2026-01-16 22:29:27.457134+00	\N	f	\N
f477a18e-855f-4c1d-b777-3aeadec60344	BB***ct	1687	\N	\N	\N	\N	{"node": "Log: Success", "workflowId": "77HAhYO_vFqeo6iFLWJx5"}	\N	2026-01-26 23:29:10.437242+00	\N	f	\N
4de47907-6fea-4fb4-850e-3fce0abc48c8	BB***ct	1689	\N	\N	\N	\N	{"node": "Log: Success", "workflowId": "77HAhYO_vFqeo6iFLWJx5"}	\N	2026-01-26 23:54:38.2941+00	\N	f	\N
afa29a1a-0271-4f4f-bc88-a0df397204fc	BB***ct	1691	\N	\N	\N	\N	{"node": "Log: Success", "workflowId": "77HAhYO_vFqeo6iFLWJx5"}	\N	2026-01-27 00:11:56.984268+00	\N	f	\N
7b2bd72a-9280-4470-82b0-1bb23f17a91c	Ex***ow	231	\N	\N	UNKNOWN ERROR	[]	{"node": "Node With Error", "workflowId": "1"}	\N	2026-01-30 17:32:06.555288+00	\N	f	\N
c26c65a5-0ee7-4a36-9593-5375b47ba5dd	Ex***ow	231	\N	\N	Example Error Message	"Stacktrace"	{"node": "Node With Error", "workflowId": "1"}	\N	2026-01-30 18:11:04.948155+00	\N	f	\N
f0e2110c-4ebf-443a-b2a4-38e973b43b79	Ex***ow	231	\N	\N	Example Error Message	"Stacktrace"	{"node": "Node With Error", "workflowId": "1"}	\N	2026-01-30 19:55:42.003929+00	\N	f	\N
076d4596-b7b8-4f88-ab56-ddce7422b6af	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-10 23:02:18.457124+00	\N	f	\N
4993b023-f97d-49a5-b535-9a344cd76226	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-10 23:04:09.386203+00	\N	f	\N
524aa586-5b84-4a6a-b15c-6acc1f2ab1d7	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-10 23:13:02.476749+00	\N	f	\N
3539d54c-182b-40ff-a6ac-d5228ebc9f10	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 00:34:53.920024+00	\N	f	\N
f9687972-7df5-4bdb-b8fe-e46b358bc435	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 03:44:17.552058+00	\N	f	\N
6e4b555f-fe6f-4897-91fc-57acd351c31c	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 13:25:05.078139+00	\N	f	\N
b74ada8f-7f39-4713-b064-0627d5ac59e2	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 13:28:42.023313+00	\N	f	\N
fc659999-9d35-414d-b03a-314c1db88b0c	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 13:29:22.988611+00	\N	f	\N
46c236ca-750d-44fc-bb7f-0b1f2e6b93b1	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 13:29:52.15849+00	\N	f	\N
28271567-289d-49ed-98e9-95f79fd717c0	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 13:31:24.286587+00	\N	f	\N
71393b0e-93f1-4121-9587-cd1548dad77e	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 13:34:09.553142+00	\N	f	\N
640cc931-40ac-4da8-b91a-4bb50920b422	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 13:40:26.64416+00	\N	f	\N
22d1b259-783b-48a0-920f-1e0d93a4c16b	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 15:10:58.148643+00	\N	f	\N
43a61091-2b74-4bea-8021-3ee8ffef8010	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 15:12:17.503198+00	\N	f	\N
30086ca9-0efe-4339-bf52-5156299f2cee	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 15:12:50.062406+00	\N	f	\N
bc72d504-56de-4ee4-ae1f-3feca30d10cf	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 15:13:23.507942+00	\N	f	\N
3d3aea8b-536b-4ad6-b67e-5589d29e9cc8	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 15:13:48.942061+00	\N	f	\N
3a3d1579-91a3-4248-b835-98a3af29d5f0	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:52:35.163193+00	\N	f	\N
f90faf95-904e-428c-97d7-e619fbc1c38d	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:52:35.203357+00	\N	f	\N
7114924f-560e-473a-a734-d675e9752fee	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:52:35.263289+00	\N	f	\N
7686f718-1d94-477e-8243-59ace52d4a9a	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:52:35.940478+00	\N	f	\N
d14d7052-bfa6-4a77-bf27-a6c63a5e564c	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:52:38.245378+00	\N	f	\N
234fbab1-d43d-4a65-989b-37ade23d19d6	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:53:02.888129+00	\N	f	\N
fcce4887-c2db-40a8-85a5-efebd69dc320	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:53:03.001479+00	\N	f	\N
39a3601f-9362-4833-8411-dc9a4e1eaef8	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:53:03.441716+00	\N	f	\N
6a73f0a9-4ae6-427d-b862-8f4f95b9f522	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:53:04.106799+00	\N	f	\N
00198a17-602d-4dec-a7a9-2a68d473907a	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:53:05.286573+00	\N	f	\N
542ac337-3e7a-4165-a2db-bdf4f803d894	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 22:59:53.017229+00	\N	f	\N
2bab8fd3-f222-498f-a64b-f45869f1c455	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 23:08:36.775167+00	\N	f	\N
c49a3660-4d6f-4429-9dd5-d8868f67a793	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 23:12:02.914508+00	\N	f	\N
fd9b3b72-86e5-4af1-8348-b5e627c44046	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 23:14:58.043939+00	\N	f	\N
6d27cd1e-5f21-4589-98c5-97e51f68b820	UNKNOWN	UNKNOWN	UNKNOWN	MEDIUM	UNKNOWN	[]	{"system_warning": null, "severity_reason": "DEFAULT", "rate_limit_exceeded": false, "circuit_breaker_state": "CLOSED"}	\N	2026-02-11 23:15:25.59013+00	\N	f	\N
c954c5a9-7a7e-46f7-8112-44d81e75d270	BB_03_Availability_Engine	exec_001	DATABASE	LOW	Query timeout on availability check	Error at line 45	{"query": "SELECT slots..."}	\N	2026-02-18 21:57:42.072078+00	\N	f	\N
aee24adf-b282-48b3-8c04-140c3190d1a8	BB_04_GCal_Sync	exec_002	API	MEDIUM	Google Calendar API rate limit	\N	{"api": "gcal", "status": 429}	\N	2026-02-18 22:57:42.072078+00	2026-02-18 23:27:42.072078+00	t	Rate limit reset
6031629e-cbb8-48c0-9559-374fab72a1cc	BB_05_Reminder_Worker	exec_003	NETWORK	HIGH	Failed to send Telegram notification	Connection refused	{"chat_id": "3000001"}	a1b2c3d4-e5f6-7890-abcd-000000000001	2026-02-18 23:12:42.072078+00	\N	f	\N
43743043-c212-4ee9-8a16-88f55a9946a0	BB_01_Telegram_Bot	exec_004	VALIDATION	LOW	Invalid message format received	\N	{"message_id": 12345}	a1b2c3d4-e5f6-7890-abcd-000000000002	2026-02-18 23:27:42.072078+00	\N	f	\N
9e0f412d-223c-46a9-922e-cde99f969936	BB_02_Booking_Flow	exec_005	LOGIC	MEDIUM	Concurrent booking attempt detected	\N	{"provider_id": "b1b2b3b4-c5d6-7890-abcd-000000000001"}	\N	2026-02-18 23:42:42.072078+00	\N	f	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.users (id, telegram_id, first_name, last_name, username, phone_number, rut, role, language_code, metadata, created_at, updated_at, deleted_at, password_hash, last_selected_provider_id) FROM stdin;
b9f03843-eee6-4607-ac5a-496c6faa9ea1	5391760292	Roger	Gallegos	\N	\N	11111111-1	admin	en	{"email": "dev.n8n.stax@gmail.com"}	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000001	3000001	Juan	Pérez	juan_perez	+56912345678	12345678-9	user	es	{"source": "seed_test"}	2026-01-19 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
41ded616-b5c7-44ea-bed2-b9f9135c7320	888888888	Banned User	\N	banned_tester	\N	\N	user	es	{}	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	\N	\N
c28d963b-4ea0-4861-ac80-9c79cb55370f	777777777	Incomplete User	\N	incomplete_tester	\N	\N	user	es	{}	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	\N	\N	\N
d5d85414-4c5e-40ca-890d-cb91c93e4095	888777666	System Admin	\N	admin	\N	\N	admin	es	{}	2026-01-24 20:42:41.773789+00	2026-01-24 20:43:20.420308+00	\N	$2a$06$mHxcDiBy1pvl.RUnko.u.uNpsSP29MqlUqyEbPYXgJRWSdNUvfnLm	\N
a1b2c3d4-e5f6-7890-abcd-000000000002	3000002	María	González	maria_g	+56923456789	98765432-1	user	es	{"source": "seed_test"}	2026-01-24 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000003	3000003	Carlos	López	carlos_loy	+56934567890	11222333-4	user	es	{"source": "seed_test"}	2026-01-29 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
7b76edda-dd8a-41a1-8391-99bbe2f5fcf1	1000001	Ana	Perez	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
ca49f72a-6c1a-47d4-9780-6f0408c11211	1000002	Carlos	Gonzalez	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
5f9f9676-93db-4df1-8131-0c4a69bd0c95	1000003	Beatriz	Silva	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
663bfa7a-7341-49c9-b495-9f912b170230	1000004	David	Lopez	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
7bf2f8a4-051d-4956-913a-7adc652f0618	1000005	Elena	Diaz	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
4becd89e-11f4-4c4f-ba3a-1eabd7394c39	1000006	Fernando	Martinez	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
cbb0be91-868b-4fd0-9786-1d52adc4e1dc	1000007	Gloria	Rodriguez	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
0bf4f0c1-aac3-4bfd-80a8-fa9cf150b99a	1000008	Hugo	Sanchez	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
e2d55df3-6398-4957-8024-ef7200df3119	1000009	Ines	Fernandez	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
0a621361-57a2-4826-aabc-1c5a914f22a7	1000010	Javier	Gomez	\N	\N	\N	user	es	{}	2026-01-19 12:39:42.802392+00	2026-01-19 12:39:42.802392+00	\N	\N	\N
988c553b-7051-47cf-bf06-29abcfcf34b3	2000001	María José	Fernández de la Reguera	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
db5f3969-2684-494e-abd8-5e452660cdd6	2000002	José Ángel	O'Connor	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
af1172c7-508b-44bc-a82a-5d368d7fd631	2000003	Jean-Pierre	Núñez y Castillo	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
64e6cb11-989f-44bc-a5e8-07dfb536c1b2	2000004	D'Angelo	Sánchez-Villalobos	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
2cb9bc11-2006-4d43-94b2-ce5e06614f0e	2000005	Xóchitl	García-Márquez	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
3cf62705-6d46-44b0-91b0-42163da9dee2	2000006	Estefanía del Carmen	De la Fuente	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
0323236a-52f0-45c3-b46c-eaf20cc5c934	2000007	Maximilianus	Van der Sar	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
4f4d34d2-c89d-4154-a0a3-95540f523ba3	2000008	Ana-Sofía	Muñoz	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
dc167392-26aa-4006-91cc-7a517e6ee903	2000009	Lúcia	Ibañez	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
b1e95f01-49b4-423c-b530-b4dc265e9082	2000010	Zoë	Almohávar	\N	\N	\N	user	es	{}	2026-01-19 13:06:46.878268+00	2026-01-19 13:06:46.878268+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000004	3000004	Ana	Martínez	ana_m	+56945678901	44555666-7	user	es	{"source": "seed_test"}	2026-02-03 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000005	3000005	Pedro	Sánchez	pedro_s	+56956789012	77888999-0	user	es	{"source": "seed_test"}	2026-02-08 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000006	3000006	Laura	Fernández	lauraf	+56967890123	11122333-4	user	es	{"source": "seed_test"}	2026-02-10 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
6daa9018-1df4-4dc3-a761-100e1ae11a09	123456789	Test	User	test_user	\N	\N	user	es	{}	2026-01-26 21:27:45.344063+00	2026-01-26 21:27:45.344063+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000007	3000007	Diego	Rodríguez	diego_r	+56978901234	44555666-7	user	es	{"source": "seed_test"}	2026-02-13 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000008	3000008	Sofia	Díaz	sofia_d	+56989012345	\N	user	en	{"source": "seed_test", "international": true}	2026-02-15 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000009	3000009	Miguel	Hernández	miguel_h	+56990123456	99887766-5	user	es	{"source": "seed_test"}	2026-02-16 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000010	3000010	Carmen	Ruiz	carmen_r	+56901234567	55443322-1	user	es	{"source": "seed_test"}	2026-02-17 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000011	3000011	José María	De la Cruz	jose_maria	\N	\N	user	es	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000012	3000012	François	Müller	francois_ms	\N	\N	user	en	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000014	3000014	User Strike 1	Test	strike_1	\N	\N	user	es	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000015	3000015	User Strike 3	Test	strike_3	\N	\N	user	es	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000016	3000016	User Strike 5	Test	strike_5	\N	\N	user	es	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000017	3000017	Deleted User	Test	deleted_user	\N	\N	user	es	{"source": "seed_test"}	2026-02-08 23:36:24.78958+00	2026-02-13 23:36:24.78958+00	2026-02-13 23:36:24.78958+00	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000018	3000018	Load Test	User 1	load_1	\N	\N	user	es	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000019	3000019	Load Test	User 2	load_2	\N	\N	user	es	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000020	3000020	Load Test	User 3	load_3	\N	\N	user	es	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
a1b2c3d4-e5f6-7890-abcd-000000000021	3000021	Admin	Test	admin_test	\N	\N	admin	es	{"source": "seed_test"}	2026-02-18 23:36:24.78958+00	2026-02-18 23:36:24.78958+00	\N	\N	\N
f6a7b8c9-d0e1-2345-fabc-456789012345	999000999	Test Booker	\N	\N	\N	\N	user	es	{}	2026-02-10 13:17:46.32768+00	2026-02-10 13:17:46.32768+00	\N	\N	\N
\.


--
-- Name: error_aggregations_id_seq; Type: SEQUENCE SET; Schema: error_handling; Owner: neondb_owner
--

SELECT pg_catalog.setval('error_handling.error_aggregations_id_seq', 1, false);


--
-- Name: error_logs_id_seq; Type: SEQUENCE SET; Schema: error_handling; Owner: neondb_owner
--

SELECT pg_catalog.setval('error_handling.error_logs_id_seq', 4, true);


--
-- Name: recurrence_config_id_seq; Type: SEQUENCE SET; Schema: error_handling; Owner: neondb_owner
--

SELECT pg_catalog.setval('error_handling.recurrence_config_id_seq', 1, true);


--
-- Name: error_aggregations error_aggregations_pkey; Type: CONSTRAINT; Schema: error_handling; Owner: neondb_owner
--

ALTER TABLE ONLY error_handling.error_aggregations
    ADD CONSTRAINT error_aggregations_pkey PRIMARY KEY (id);


--
-- Name: error_logs error_logs_pkey; Type: CONSTRAINT; Schema: error_handling; Owner: neondb_owner
--

ALTER TABLE ONLY error_handling.error_logs
    ADD CONSTRAINT error_logs_pkey PRIMARY KEY (id);


--
-- Name: recurrence_config recurrence_config_pkey; Type: CONSTRAINT; Schema: error_handling; Owner: neondb_owner
--

ALTER TABLE ONLY error_handling.recurrence_config
    ADD CONSTRAINT recurrence_config_pkey PRIMARY KEY (id);


--
-- Name: error_aggregations uk_error_aggregation; Type: CONSTRAINT; Schema: error_handling; Owner: neondb_owner
--

ALTER TABLE ONLY error_handling.error_aggregations
    ADD CONSTRAINT uk_error_aggregation UNIQUE (workflow_name, error_type, error_fingerprint, time_window_start);


--
-- Name: recurrence_config uk_recurrence_config; Type: CONSTRAINT; Schema: error_handling; Owner: neondb_owner
--

ALTER TABLE ONLY error_handling.recurrence_config
    ADD CONSTRAINT uk_recurrence_config UNIQUE (workflow_name, error_type);


--
-- Name: account account_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.account
    ADD CONSTRAINT account_pkey PRIMARY KEY (id);


--
-- Name: invitation invitation_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.invitation
    ADD CONSTRAINT invitation_pkey PRIMARY KEY (id);


--
-- Name: jwks jwks_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.jwks
    ADD CONSTRAINT jwks_pkey PRIMARY KEY (id);


--
-- Name: member member_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.member
    ADD CONSTRAINT member_pkey PRIMARY KEY (id);


--
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- Name: organization organization_slug_key; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.organization
    ADD CONSTRAINT organization_slug_key UNIQUE (slug);


--
-- Name: project_config project_config_endpoint_id_key; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.project_config
    ADD CONSTRAINT project_config_endpoint_id_key UNIQUE (endpoint_id);


--
-- Name: project_config project_config_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.project_config
    ADD CONSTRAINT project_config_pkey PRIMARY KEY (id);


--
-- Name: session session_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.session
    ADD CONSTRAINT session_pkey PRIMARY KEY (id);


--
-- Name: session session_token_key; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.session
    ADD CONSTRAINT session_token_key UNIQUE (token);


--
-- Name: user user_email_key; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth."user"
    ADD CONSTRAINT user_email_key UNIQUE (email);


--
-- Name: user user_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: verification verification_pkey; Type: CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.verification
    ADD CONSTRAINT verification_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_username_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_username_key UNIQUE (username);


--
-- Name: app_config app_config_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.app_config
    ADD CONSTRAINT app_config_pkey PRIMARY KEY (id);


--
-- Name: app_messages app_messages_code_lang_unique; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.app_messages
    ADD CONSTRAINT app_messages_code_lang_unique UNIQUE (code, lang);


--
-- Name: app_messages app_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.app_messages
    ADD CONSTRAINT app_messages_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: circuit_breaker_state circuit_breaker_state_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.circuit_breaker_state
    ADD CONSTRAINT circuit_breaker_state_pkey PRIMARY KEY (id);


--
-- Name: error_metrics error_metrics_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.error_metrics
    ADD CONSTRAINT error_metrics_pkey PRIMARY KEY (id);


--
-- Name: notification_configs notification_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.notification_configs
    ADD CONSTRAINT notification_configs_pkey PRIMARY KEY (id);


--
-- Name: notification_queue notification_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.notification_queue
    ADD CONSTRAINT notification_queue_pkey PRIMARY KEY (id);


--
-- Name: provider_cache provider_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.provider_cache
    ADD CONSTRAINT provider_cache_pkey PRIMARY KEY (id);


--
-- Name: provider_cache provider_cache_provider_slug_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.provider_cache
    ADD CONSTRAINT provider_cache_provider_slug_key UNIQUE (provider_slug);


--
-- Name: providers providers_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.providers
    ADD CONSTRAINT providers_pkey PRIMARY KEY (id);


--
-- Name: schedules schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);


--
-- Name: security_firewall security_firewall_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.security_firewall
    ADD CONSTRAINT security_firewall_entity_id_key UNIQUE (entity_id);


--
-- Name: security_firewall security_firewall_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.security_firewall
    ADD CONSTRAINT security_firewall_pkey PRIMARY KEY (id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: system_errors system_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.system_errors
    ADD CONSTRAINT system_errors_pkey PRIMARY KEY (error_id);


--
-- Name: circuit_breaker_state unique_circuit_workflow; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.circuit_breaker_state
    ADD CONSTRAINT unique_circuit_workflow UNIQUE (workflow_name);


--
-- Name: error_metrics unique_daily_metric; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.error_metrics
    ADD CONSTRAINT unique_daily_metric UNIQUE (metric_date, workflow_name, severity);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_telegram_id_key; Type: CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_telegram_id_key UNIQUE (telegram_id);


--
-- Name: idx_error_aggregations_lookup; Type: INDEX; Schema: error_handling; Owner: neondb_owner
--

CREATE INDEX idx_error_aggregations_lookup ON error_handling.error_aggregations USING btree (workflow_name, error_type, error_fingerprint, time_window_end DESC);


--
-- Name: idx_error_logs_created_at; Type: INDEX; Schema: error_handling; Owner: neondb_owner
--

CREATE INDEX idx_error_logs_created_at ON error_handling.error_logs USING btree (created_at DESC);


--
-- Name: idx_error_logs_environment; Type: INDEX; Schema: error_handling; Owner: neondb_owner
--

CREATE INDEX idx_error_logs_environment ON error_handling.error_logs USING btree (environment, created_at DESC);


--
-- Name: idx_error_logs_fingerprint; Type: INDEX; Schema: error_handling; Owner: neondb_owner
--

CREATE INDEX idx_error_logs_fingerprint ON error_handling.error_logs USING btree (error_fingerprint, created_at DESC) WHERE (error_fingerprint IS NOT NULL);


--
-- Name: idx_error_logs_high_severity; Type: INDEX; Schema: error_handling; Owner: neondb_owner
--

CREATE INDEX idx_error_logs_high_severity ON error_handling.error_logs USING btree (created_at DESC) WHERE (((severity)::text = ANY ((ARRAY['HIGH'::character varying, 'CRITICAL'::character varying])::text[])) AND (resolved = false));


--
-- Name: idx_error_logs_recurrence; Type: INDEX; Schema: error_handling; Owner: neondb_owner
--

CREATE INDEX idx_error_logs_recurrence ON error_handling.error_logs USING btree (workflow_name, error_type, created_at DESC);


--
-- Name: idx_error_logs_unresolved; Type: INDEX; Schema: error_handling; Owner: neondb_owner
--

CREATE INDEX idx_error_logs_unresolved ON error_handling.error_logs USING btree (workflow_name, created_at DESC) WHERE (resolved = false);


--
-- Name: account_userId_idx; Type: INDEX; Schema: neon_auth; Owner: neon_auth
--

CREATE INDEX "account_userId_idx" ON neon_auth.account USING btree ("userId");


--
-- Name: invitation_email_idx; Type: INDEX; Schema: neon_auth; Owner: neon_auth
--

CREATE INDEX invitation_email_idx ON neon_auth.invitation USING btree (email);


--
-- Name: invitation_organizationId_idx; Type: INDEX; Schema: neon_auth; Owner: neon_auth
--

CREATE INDEX "invitation_organizationId_idx" ON neon_auth.invitation USING btree ("organizationId");


--
-- Name: member_organizationId_idx; Type: INDEX; Schema: neon_auth; Owner: neon_auth
--

CREATE INDEX "member_organizationId_idx" ON neon_auth.member USING btree ("organizationId");


--
-- Name: member_userId_idx; Type: INDEX; Schema: neon_auth; Owner: neon_auth
--

CREATE INDEX "member_userId_idx" ON neon_auth.member USING btree ("userId");


--
-- Name: organization_slug_uidx; Type: INDEX; Schema: neon_auth; Owner: neon_auth
--

CREATE UNIQUE INDEX organization_slug_uidx ON neon_auth.organization USING btree (slug);


--
-- Name: session_userId_idx; Type: INDEX; Schema: neon_auth; Owner: neon_auth
--

CREATE INDEX "session_userId_idx" ON neon_auth.session USING btree ("userId");


--
-- Name: verification_identifier_idx; Type: INDEX; Schema: neon_auth; Owner: neon_auth
--

CREATE INDEX verification_identifier_idx ON neon_auth.verification USING btree (identifier);


--
-- Name: idx_admin_sessions_expires_at; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_admin_sessions_expires_at ON public.admin_sessions USING btree (expires_at) WHERE (NOT is_revoked);


--
-- Name: idx_admin_sessions_last_used; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_admin_sessions_last_used ON public.admin_sessions USING btree (last_used_at) WHERE (NOT is_revoked);


--
-- Name: idx_admin_sessions_token_hash; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_admin_sessions_token_hash ON public.admin_sessions USING btree (token_hash) WHERE (NOT is_revoked);


--
-- Name: idx_admin_sessions_user_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_admin_sessions_user_id ON public.admin_sessions USING btree (user_id) WHERE (NOT is_revoked);


--
-- Name: idx_admin_users_username; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_admin_users_username ON public.admin_users USING btree (username) WHERE (is_active = true);


--
-- Name: idx_app_config_category; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_app_config_category ON public.app_config USING btree (category);


--
-- Name: idx_app_config_key; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE UNIQUE INDEX idx_app_config_key ON public.app_config USING btree (key);


--
-- Name: idx_app_config_key_category; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_app_config_key_category ON public.app_config USING btree (key, category);


--
-- Name: idx_app_messages_lookup; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_app_messages_lookup ON public.app_messages USING btree (code, lang);


--
-- Name: idx_audit_logs_timestamp; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_audit_logs_timestamp ON public.audit_logs USING btree (created_at DESC);


--
-- Name: idx_bookings_provider; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bookings_provider ON public.bookings USING btree (provider_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_bookings_provider_time; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bookings_provider_time ON public.bookings USING btree (provider_id, start_time, end_time) WHERE (status <> 'cancelled'::public.booking_status);


--
-- Name: idx_bookings_range; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bookings_range ON public.bookings USING btree (start_time, end_time) WHERE (status <> 'cancelled'::public.booking_status);


--
-- Name: idx_bookings_reminder_1; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bookings_reminder_1 ON public.bookings USING btree (reminder_1_sent_at) WHERE (reminder_1_sent_at IS NULL);


--
-- Name: idx_bookings_reminder_2; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bookings_reminder_2 ON public.bookings USING btree (reminder_2_sent_at) WHERE (reminder_2_sent_at IS NULL);


--
-- Name: idx_bookings_reminders; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bookings_reminders ON public.bookings USING btree (start_time, reminder_1_sent_at, reminder_2_sent_at) WHERE (status = 'confirmed'::public.booking_status);


--
-- Name: idx_bookings_start_time; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bookings_start_time ON public.bookings USING btree (start_time);


--
-- Name: idx_bookings_user; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_bookings_user ON public.bookings USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_circuit_breaker_workflow; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_circuit_breaker_workflow ON public.circuit_breaker_state USING btree (workflow_name);


--
-- Name: idx_error_metrics_date; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_error_metrics_date ON public.error_metrics USING btree (metric_date DESC);


--
-- Name: idx_firewall_entity; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_firewall_entity ON public.security_firewall USING btree (entity_id);


--
-- Name: idx_notification_queue_booking_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notification_queue_booking_id ON public.notification_queue USING btree (booking_id);


--
-- Name: idx_notification_queue_created_at; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notification_queue_created_at ON public.notification_queue USING btree (created_at DESC);


--
-- Name: idx_notification_queue_pending; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notification_queue_pending ON public.notification_queue USING btree (status, next_retry_at) WHERE (status = 'pending'::public.notification_status);


--
-- Name: idx_notification_queue_priority; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notification_queue_priority ON public.notification_queue USING btree (priority DESC, created_at);


--
-- Name: idx_notification_queue_retry; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notification_queue_retry ON public.notification_queue USING btree (status, retry_count) WHERE ((status = 'pending'::public.notification_status) AND (retry_count < 3));


--
-- Name: idx_notification_queue_status; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notification_queue_status ON public.notification_queue USING btree (status) WHERE (status = 'pending'::public.notification_status);


--
-- Name: idx_notification_queue_user_id; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_notification_queue_user_id ON public.notification_queue USING btree (user_id);


--
-- Name: idx_provider_cache_expires; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_provider_cache_expires ON public.provider_cache USING btree (expires_at);


--
-- Name: idx_provider_cache_slug; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_provider_cache_slug ON public.provider_cache USING btree (provider_slug);


--
-- Name: idx_providers_slug; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE UNIQUE INDEX idx_providers_slug ON public.providers USING btree (slug) WHERE (deleted_at IS NULL);


--
-- Name: idx_schedules_pro; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_schedules_pro ON public.schedules USING btree (provider_id, day_of_week);


--
-- Name: idx_se_created; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_se_created ON public.system_errors USING btree (created_at DESC);


--
-- Name: idx_se_severity; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_se_severity ON public.system_errors USING btree (severity);


--
-- Name: idx_se_workflow; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_se_workflow ON public.system_errors USING btree (workflow_name);


--
-- Name: idx_security_firewall_entity; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_security_firewall_entity ON public.security_firewall USING btree (entity_id);


--
-- Name: idx_system_errors_created; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_system_errors_created ON public.system_errors USING btree (created_at);


--
-- Name: idx_system_errors_created_at; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_system_errors_created_at ON public.system_errors USING btree (created_at);


--
-- Name: idx_system_errors_severity; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_system_errors_severity ON public.system_errors USING btree (severity);


--
-- Name: idx_system_errors_unresolved; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_system_errors_unresolved ON public.system_errors USING btree (is_resolved) WHERE (is_resolved = false);


--
-- Name: idx_system_errors_workflow; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_system_errors_workflow ON public.system_errors USING btree (workflow_name);


--
-- Name: idx_system_errors_workflow_created; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_system_errors_workflow_created ON public.system_errors USING btree (workflow_name, created_at DESC);


--
-- Name: idx_users_role; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_users_role ON public.users USING btree (role) WHERE (deleted_at IS NULL);


--
-- Name: idx_users_telegram; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE INDEX idx_users_telegram ON public.users USING btree (telegram_id) WHERE (deleted_at IS NULL);


--
-- Name: unique_booking_slot; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE UNIQUE INDEX unique_booking_slot ON public.bookings USING btree (provider_id, start_time) WHERE (status <> 'cancelled'::public.booking_status);


--
-- Name: error_logs trg_error_logs_updated_at; Type: TRIGGER; Schema: error_handling; Owner: neondb_owner
--

CREATE TRIGGER trg_error_logs_updated_at BEFORE UPDATE ON error_handling.error_logs FOR EACH ROW EXECUTE FUNCTION error_handling.update_updated_at();


--
-- Name: admin_users trg_admin_users_timestamp; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_admin_users_timestamp BEFORE UPDATE ON public.admin_users FOR EACH ROW EXECUTE FUNCTION public.update_notification_queue_timestamp();


--
-- Name: app_config trg_app_config_timestamp; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_app_config_timestamp BEFORE UPDATE ON public.app_config FOR EACH ROW EXECUTE FUNCTION public.update_notification_queue_timestamp();


--
-- Name: bookings trg_bookings_modtime; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_bookings_modtime BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.update_modtime();


--
-- Name: bookings trg_check_overlap_with_lock; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_check_overlap_with_lock BEFORE INSERT OR UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.check_booking_overlap_with_lock();


--
-- Name: security_firewall trg_firewall_modtime; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_firewall_modtime BEFORE UPDATE ON public.security_firewall FOR EACH ROW EXECUTE FUNCTION public.update_modtime();


--
-- Name: notification_queue trg_notification_queue_update_timestamp; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_notification_queue_update_timestamp BEFORE UPDATE ON public.notification_queue FOR EACH ROW EXECUTE FUNCTION public.update_notification_queue_timestamp();


--
-- Name: users trg_users_modtime; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_users_modtime BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_modtime();


--
-- Name: app_config trg_validate_app_config_availability; Type: TRIGGER; Schema: public; Owner: neondb_owner
--

CREATE TRIGGER trg_validate_app_config_availability BEFORE INSERT OR UPDATE ON public.app_config FOR EACH ROW EXECUTE FUNCTION public.validate_app_config_availability();


--
-- Name: account account_userId_fkey; Type: FK CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.account
    ADD CONSTRAINT "account_userId_fkey" FOREIGN KEY ("userId") REFERENCES neon_auth."user"(id) ON DELETE CASCADE;


--
-- Name: invitation invitation_inviterId_fkey; Type: FK CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.invitation
    ADD CONSTRAINT "invitation_inviterId_fkey" FOREIGN KEY ("inviterId") REFERENCES neon_auth."user"(id) ON DELETE CASCADE;


--
-- Name: invitation invitation_organizationId_fkey; Type: FK CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.invitation
    ADD CONSTRAINT "invitation_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES neon_auth.organization(id) ON DELETE CASCADE;


--
-- Name: member member_organizationId_fkey; Type: FK CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.member
    ADD CONSTRAINT "member_organizationId_fkey" FOREIGN KEY ("organizationId") REFERENCES neon_auth.organization(id) ON DELETE CASCADE;


--
-- Name: member member_userId_fkey; Type: FK CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.member
    ADD CONSTRAINT "member_userId_fkey" FOREIGN KEY ("userId") REFERENCES neon_auth."user"(id) ON DELETE CASCADE;


--
-- Name: session session_userId_fkey; Type: FK CONSTRAINT; Schema: neon_auth; Owner: neon_auth
--

ALTER TABLE ONLY neon_auth.session
    ADD CONSTRAINT "session_userId_fkey" FOREIGN KEY ("userId") REFERENCES neon_auth."user"(id) ON DELETE CASCADE;


--
-- Name: bookings bookings_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id) ON DELETE RESTRICT;


--
-- Name: bookings bookings_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: bookings bookings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: provider_cache provider_cache_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.provider_cache
    ADD CONSTRAINT provider_cache_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id) ON DELETE CASCADE;


--
-- Name: providers providers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.providers
    ADD CONSTRAINT providers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: schedules schedules_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.schedules
    ADD CONSTRAINT schedules_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id) ON DELETE CASCADE;


--
-- Name: services services_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_provider_id_fkey FOREIGN KEY (provider_id) REFERENCES public.providers(id) ON DELETE CASCADE;


--
-- Name: users users_last_selected_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: neondb_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_last_selected_provider_id_fkey FOREIGN KEY (last_selected_provider_id) REFERENCES public.providers(id);


--
-- Name: bookings Service Access Bookings; Type: POLICY; Schema: public; Owner: neondb_owner
--

CREATE POLICY "Service Access Bookings" ON public.bookings USING (true) WITH CHECK (true);


--
-- Name: users Service Access Users; Type: POLICY; Schema: public; Owner: neondb_owner
--

CREATE POLICY "Service Access Users" ON public.users USING (true) WITH CHECK (true);


--
-- Name: bookings; Type: ROW SECURITY; Schema: public; Owner: neondb_owner
--

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: neondb_owner
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA error_handling; Type: ACL; Schema: -; Owner: neondb_owner
--

GRANT USAGE ON SCHEMA error_handling TO n8n_user;


--
-- Name: FUNCTION check_error_recurrence(p_workflow_name character varying, p_error_type character varying, p_error_message text, p_time_window_minutes integer, p_use_fingerprint boolean); Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT ALL ON FUNCTION error_handling.check_error_recurrence(p_workflow_name character varying, p_error_type character varying, p_error_message text, p_time_window_minutes integer, p_use_fingerprint boolean) TO n8n_user;


--
-- Name: FUNCTION cleanup_old_errors(p_days_to_keep integer); Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT ALL ON FUNCTION error_handling.cleanup_old_errors(p_days_to_keep integer) TO n8n_user;


--
-- Name: FUNCTION count_error_recurrences(p_workflow_name character varying, p_error_type character varying, p_time_window_minutes integer); Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT ALL ON FUNCTION error_handling.count_error_recurrences(p_workflow_name character varying, p_error_type character varying, p_time_window_minutes integer) TO n8n_user;


--
-- Name: FUNCTION generate_error_fingerprint(p_workflow_name text, p_error_type text, p_error_message text); Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT ALL ON FUNCTION error_handling.generate_error_fingerprint(p_workflow_name text, p_error_type text, p_error_message text) TO n8n_user;


--
-- Name: FUNCTION update_updated_at(); Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT ALL ON FUNCTION error_handling.update_updated_at() TO n8n_user;


--
-- Name: TABLE error_aggregations; Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE error_handling.error_aggregations TO n8n_user;


--
-- Name: SEQUENCE error_aggregations_id_seq; Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT SELECT,USAGE ON SEQUENCE error_handling.error_aggregations_id_seq TO n8n_user;


--
-- Name: TABLE error_logs; Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE error_handling.error_logs TO n8n_user;


--
-- Name: SEQUENCE error_logs_id_seq; Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT SELECT,USAGE ON SEQUENCE error_handling.error_logs_id_seq TO n8n_user;


--
-- Name: TABLE recurrence_config; Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE error_handling.recurrence_config TO n8n_user;


--
-- Name: SEQUENCE recurrence_config_id_seq; Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT SELECT,USAGE ON SEQUENCE error_handling.recurrence_config_id_seq TO n8n_user;


--
-- Name: TABLE v_recurring_errors; Type: ACL; Schema: error_handling; Owner: neondb_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE error_handling.v_recurring_errors TO n8n_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: error_handling; Owner: neondb_owner
--

ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA error_handling GRANT SELECT,USAGE ON SEQUENCES TO n8n_user;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: error_handling; Owner: neondb_owner
--

ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA error_handling GRANT ALL ON FUNCTIONS TO n8n_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: error_handling; Owner: neondb_owner
--

ALTER DEFAULT PRIVILEGES FOR ROLE neondb_owner IN SCHEMA error_handling GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO n8n_user;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO neon_superuser WITH GRANT OPTION;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: cloud_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE cloud_admin IN SCHEMA public GRANT ALL ON TABLES TO neon_superuser WITH GRANT OPTION;


--
-- PostgreSQL database dump complete
--

\unrestrict 4L2uxobDP2tc8skXkDbO2x5ohsFYKM4SNH9aHPrln5OpK0ZMcWS7Lnyt5RfEF1G

