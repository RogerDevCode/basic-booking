--
-- PostgreSQL database dump
--

\restrict Xk3G4UBP9qScT12pfbKamNnvbq3WRzrRahQwNiIVVmpH4EKA8b2WXpwgIAtcCRZ

-- Dumped from database version 17.7 (e429a59)
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
    'DEEP_LINK_FAILURE'
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
    'no_show'
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
-- Name: acquire_booking_lock(uuid, timestamp with time zone, integer); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.acquire_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone, p_timeout_seconds integer DEFAULT 30) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION public.acquire_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone, p_timeout_seconds integer) OWNER TO neondb_owner;

--
-- Name: FUNCTION acquire_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone, p_timeout_seconds integer); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.acquire_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone, p_timeout_seconds integer) IS 'Acquires an advisory lock for a booking slot to prevent concurrent double-bookings. Returns true if lock acquired, false if timeout.';


--
-- Name: check_booking_lock(uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.check_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION public.check_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone) OWNER TO neondb_owner;

--
-- Name: FUNCTION check_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.check_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone) IS 'Checks if an advisory lock is held. For debugging purposes.';


--
-- Name: check_booking_overlap(); Type: FUNCTION; Schema: public; Owner: neondb_owner
--

CREATE FUNCTION public.check_booking_overlap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
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
$$;


ALTER FUNCTION public.check_booking_overlap_with_lock() OWNER TO neondb_owner;

--
-- Name: FUNCTION check_booking_overlap_with_lock(); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.check_booking_overlap_with_lock() IS 'Enhanced overlap check with advisory lock acquisition. Prevents race conditions in concurrent bookings.';


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

CREATE FUNCTION public.release_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION public.release_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone) OWNER TO neondb_owner;

--
-- Name: FUNCTION release_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone); Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON FUNCTION public.release_booking_lock(p_professional_id uuid, p_start_time timestamp with time zone) IS 'Releases advisory lock (automatic on transaction commit). Exists for debugging only.';


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
    CONSTRAINT notification_queue_retry_count_check CHECK (((retry_count >= 0) AND (retry_count <= 10)))
);


ALTER TABLE public.notification_queue OWNER TO neondb_owner;

--
-- Name: TABLE notification_queue; Type: COMMENT; Schema: public; Owner: neondb_owner
--

COMMENT ON TABLE public.notification_queue IS 'Queue for asynchronous notifications with retry support. Processed by BB_07 retry worker.';


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
    CONSTRAINT check_min_notice_positive CHECK ((min_notice_hours >= 0)),
    CONSTRAINT check_provider_name_not_empty CHECK ((length(TRIM(BOTH FROM name)) > 0)),
    CONSTRAINT check_slot_duration_positive CHECK ((slot_duration_minutes > 0)),
    CONSTRAINT check_slug_format CHECK ((slug ~* '^[a-z0-9-]+$'::text))
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
    created_at timestamp with time zone DEFAULT now()
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
ab76a620-58ec-439e-a675-8a07723933b7	TIMEZONE	America/Argentina/Buenos_Aires	string	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-26 22:49:47.644924+00
89d8b452-a433-4b7f-ad5b-3b06072b3e2e	CALENDAR_MIN_TIME	07:00:00	string	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
a1435e9e-e46b-4beb-a0b8-c1a3e47d09a0	CALENDAR_MAX_TIME	21:00:00	string	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
15a2944a-d892-4b3d-ae53-ab31ea179227	COLOR_PRIMARY_HOVER	#1d4ed8	color	branding	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
c707aa82-438e-4afc-9989-3b427dbc0020	COLOR_SUCCESS	#10b981	color	branding	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
99e79f48-b9cf-4c9e-9ea7-5ac35a81cb5d	COLOR_DANGER	#ef4444	color	branding	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
7a9afa97-4743-494e-a611-c8cbe5914c4e	COLOR_EVENT_CONFIRMED	#dcfce7	color	branding	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
b43fea76-743b-481b-8e74-54ba537a4eb0	COLOR_EVENT_PENDING	#fff7ed	color	branding	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
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
003006c0-dc55-4093-8ed4-1af37f619730	BOOKING_MAX_NOTICE_DAYS	60	number	business	\N	t	2026-01-22 16:10:31.763132+00	2026-01-22 19:47:44.609108+00
2a3cf121-3013-4c4a-a718-8b0e3f98ad1b	DEFAULT_DURATION_MIN	30	number	business	\N	t	2026-01-22 18:06:43.27832+00	2026-01-22 19:47:44.609108+00
b18f62d6-36a6-4874-9b51-3f71ff6d2402	ERROR_ALERT_CHAT_ID	5391760292	string	system	\N	f	2026-01-22 18:25:56.253054+00	2026-01-22 19:47:44.609108+00
8e206285-12e8-442e-8fff-4f6297f2f008	NOTIFICATION_CRON_MINUTES	15	number	notifications	\N	f	2026-01-22 19:47:44.609108+00	2026-01-22 19:47:44.609108+00
e4cdc31d-f996-44ef-8e63-6edce55cc563	RETRY_WORKER_CRON_MINUTES	5	number	notifications	\N	f	2026-01-22 19:47:44.609108+00	2026-01-22 19:47:44.609108+00
38a205c6-5b9d-4223-aba2-a702aa930786	NOTIFICATION_BATCH_LIMIT	50	number	notifications	\N	f	2026-01-22 19:47:44.609108+00	2026-01-22 19:47:44.609108+00
14dda265-24f1-4042-b918-6afa94ee3989	WF_ID_AVAILABILITY_ENGINE	BB_03_Availability_Engine	string	general	\N	f	2026-01-22 21:09:13.096467+00	2026-01-22 21:09:13.096467+00
920214b9-d67a-4453-9cf7-b548e0865262	SCHEDULE_START_HOUR	9	number	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
1eead956-a6e6-40e8-be5c-8bb72c1dee3c	SCHEDULE_END_HOUR	18	number	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
17aaca59-e546-4a26-89c4-fa261498109d	SCHEDULE_DAYS	[1,2,3,4,5]	json	calendar	\N	t	2026-01-22 16:10:31.763132+00	2026-01-23 18:47:03.171944+00
abc0a678-30e0-4b26-bf3f-e398cdf9dd3e	MIN_NOTICE_HOURS	2	number	general	Minimum notice hours	t	2026-01-26 21:27:45.344063+00	2026-01-26 22:49:47.644924+00
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

COPY public.notification_queue (id, booking_id, user_id, message, priority, status, retry_count, error_message, created_at, updated_at, sent_at) FROM stdin;
\.


--
-- Data for Name: providers; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.providers (id, user_id, name, email, google_calendar_id, slot_duration_minutes, min_notice_hours, public_booking_enabled, created_at, deleted_at, slug) FROM stdin;
2eebc9bc-c2f8-46f8-9e78-7da0909fcca4	\N	Dr. Roger Auto	dev.n8n.stax@gmail.com	dev.n8n.stax@gmail.com	30	2	t	2026-01-15 14:52:06.081827+00	\N	dr-roger-auto
98d6e8db-0e93-4c62-a762-0ee0dd2aff29	\N	Dr. John Smith	john.smith@example.com	\N	30	2	t	2026-01-26 00:14:22.426419+00	\N	dr-smith
c5d0025d-b97c-4879-9692-73a92632bb79	\N	Dra. María García	maria.garcia@example.com	\N	30	2	t	2026-01-26 00:14:22.426419+00	\N	dr-garcia
73f97ddc-306c-42d4-bd08-46dc3ee96217	6daa9018-1df4-4dc3-a761-100e1ae11a09	Dr. Juan Pérez	juan.perez@test.com	juan.perez@gmail.com	30	2	t	2026-01-26 21:27:45.344063+00	\N	dr-juan-perez
11f3d1c8-aba8-4343-b2b9-3e81c30a1da2	6daa9018-1df4-4dc3-a761-100e1ae11a09	Test Provider	test@test.com	test@gmail.com	30	1	t	2026-01-26 21:27:45.344063+00	\N	test-provider
ae1d057b-ec08-45ee-9303-606a712cd9bd	6daa9018-1df4-4dc3-a761-100e1ae11a09	Deleted Provider	deleted@test.com	deleted@gmail.com	30	2	f	2026-01-26 21:27:45.344063+00	2026-01-26 21:27:45.344063+00	deleted-provider
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
\.


--
-- Data for Name: security_firewall; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.security_firewall (id, entity_id, strike_count, is_blocked, blocked_until, last_strike_at, created_at, updated_at) FROM stdin;
068efb91-b4bb-473a-b08c-fa69aa01686d	telegram:CERT_TEST_USER	1	f	\N	2026-01-16 21:20:19.857775+00	2026-01-16 21:20:19.857775+00	2026-01-16 21:20:19.857775+00
bd5475e3-0806-4b8b-9fed-c9b31f062fd4	entity_123	1	f	\N	2026-01-16 22:00:17.802872+00	2026-01-16 22:00:17.802872+00	2026-01-16 22:00:17.802872+00
dc6429f9-b971-4e67-b89a-7caa052b506c	telegram:5391760292	1	f	\N	2026-01-16 22:06:44.832169+00	2026-01-16 22:06:44.832169+00	2026-01-16 22:06:44.832169+00
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
\.


--
-- Data for Name: system_errors; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.system_errors (error_id, workflow_name, workflow_execution_id, error_type, severity, error_message, error_stack, error_context, user_id, created_at) FROM stdin;
3b4f6cb6-7b00-4b81-85f1-39e48b3f9b31	Manual_Test	\N	\N	\N	Checking Insert	\N	\N	\N	2026-01-15 19:44:04.618267+00
465569c5-656b-46aa-b90a-87e8dc160513	ROGER_ALERTS	314	INFO	LOW	Watchtower Online	\N	{}	\N	2026-01-15 21:46:56.152295+00
1c670e1d-a2e7-465f-8ab4-7aa261cd0122	ROGER_ALERTS	315	INFO	LOW	Watchtower Online	\N	{}	\N	2026-01-15 22:00:24.335139+00
c6a4130b-1183-4a7a-bc81-393000f4da34	HTML_FIX_TEST	317	INFO	LOW	Testing HTML Parse Mode	\N	{}	\N	2026-01-15 22:05:46.433014+00
072982a9-f8c2-460a-bf91-903157ade284	StressTest	322	UNKNOWN	ERROR	aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa	\N	{}	\N	2026-01-15 22:08:25.493265+00
59f1d1a5-1d1e-4ac2-bc3a-e3622dae7d99	DeepTest	323	UNKNOWN	ERROR	Nested	\N	{"level1": {"level2": {"level3": "value"}}}	\N	2026-01-15 22:08:32.562809+00
65ca488f-e29f-4f69-9018-134ec54e000f	EnumTest	325	UNKNOWN	LOW	foo	\N	{}	\N	2026-01-15 22:08:46.662653+00
7f17dd4c-7215-49c5-85d8-023073c90960	BoundaryTest	326	UNKNOWN	ERROR	test	\N	{}	\N	2026-01-15 22:10:37.464039+00
5925c92d-5191-4eb3-8dca-5e040586958e	BoundaryTest	327	UNKNOWN	ERROR	test	\N	{}	\N	2026-01-15 22:10:45.038655+00
cc63bdd3-a373-4ef8-b30c-64c2b0e59439	BoundaryTest	328	UNKNOWN	NUCLEAR	test	\N	{}	\N	2026-01-15 22:10:52.619162+00
7e873fcb-b7cb-4192-93db-4baf940cc119	BoundaryTest	329	UNKNOWN	ERROR	test	\N	{}	\N	2026-01-15 22:11:00.11801+00
2f59da40-8fd4-4573-b9dc-5466697daf69	STRIKE_TEST	333	VALIDATION	ERROR	Invalid RUT detected	\N	{}	\N	2026-01-15 22:29:37.067407+00
4011060c-bc79-4241-bc8a-a13f700ce5c3	FIREWALL_TEST	339	VALIDATION	MEDIUM	Simulated RUT Failure #1	\N	{}	\N	2026-01-16 13:59:49.547928+00
a1e81f0e-dff6-4b39-8404-6f58f711e811	FIREWALL_TEST	340	VALIDATION	MEDIUM	Simulated RUT Failure #2	\N	{}	\N	2026-01-16 13:59:58.612759+00
09c61a4e-7996-4326-8d52-3959e695557d	FIREWALL_TEST	341	VALIDATION	MEDIUM	Simulated RUT Failure #3	\N	{}	\N	2026-01-16 14:00:07.002452+00
669526e6-e092-49f9-9e59-cf80410a18df	DEBUG_STRIKE	343	VALIDATION	ERROR	Manual Test	\N	{}	\N	2026-01-16 14:00:57.33626+00
d0d3a942-54a5-4f7a-9a22-a8e27fdb5a38	FIREWALL_TEST	344	VALIDATION	MEDIUM	Simulated RUT Failure #1	\N	{}	\N	2026-01-16 14:11:47.742607+00
1a301a0a-0254-48e8-9dc7-4dc32ea30ace	FIREWALL_TEST	345	VALIDATION	MEDIUM	Simulated RUT Failure #2	\N	{}	\N	2026-01-16 14:11:56.282393+00
99138bac-a186-47d0-b889-7b83f3b92c84	FIREWALL_TEST	346	VALIDATION	MEDIUM	Simulated RUT Failure #3	\N	{}	\N	2026-01-16 14:12:04.477978+00
eb90d3e4-3fa9-48c0-bcd9-8be7ab96bdfd	DIAGNOSTIC_STRIKE	347	VALIDATION	ERROR	Checking strike_applied field	\N	{}	\N	2026-01-16 14:13:53.082593+00
c311a867-be60-464a-a88d-9a1b05e103fa	FIREWALL_TEST	348	VALIDATION	MEDIUM	Simulated RUT Failure #1	\N	{}	\N	2026-01-16 14:17:47.888894+00
a004ef4d-e4c8-4a34-89eb-9ee29e94d774	FIREWALL_TEST	349	VALIDATION	MEDIUM	Simulated RUT Failure #2	\N	{}	\N	2026-01-16 14:17:56.003222+00
d814e01c-fa8d-49ba-82f4-08e0055638de	FIREWALL_TEST	350	VALIDATION	MEDIUM	Simulated RUT Failure #3	\N	{}	\N	2026-01-16 14:18:03.874123+00
e8f85b75-32b0-4dbc-8fa9-e4a3d476c323	CERT_FLOW	352	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 14:32:33.272062+00
7273f3ed-727e-4fa9-995a-c2686554ae6b	CERT_FLOW	353	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 14:32:48.918813+00
ac36992f-a3f3-48c2-96bc-19edabc2fa84	DEBUG_CERT	354	UNKNOWN	ERROR	Check Strike	\N	{}	\N	2026-01-16 14:33:59.203798+00
b332fd2e-8931-42fa-a6e1-15843ab2eff3	CERT_FLOW	356	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 14:39:03.099662+00
d472ce76-c790-4972-847a-304c28368244	CERT_FLOW	357	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 14:39:12.156821+00
5f8d6905-fa98-40f0-83cc-e1708d0534fc	CERT_FLOW	358	UNKNOWN	ERROR	Strike Manual	\N	{}	\N	2026-01-16 14:41:19.109614+00
299ec4f9-f8c1-4d05-83ca-48fdfe6651e9	CERT_FLOW	360	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 14:58:59.052864+00
e2e36459-9e40-4be7-9e41-32354cfcd4e9	CERT_FLOW	361	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 14:59:14.111527+00
c46b7066-0149-4e10-8834-fa0163a3eaa8	CERT_FLOW	364	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 15:16:13.976621+00
73aab834-21de-47fe-b5d3-eb2efc66dc24	CERT_FLOW	365	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 15:16:28.777831+00
92ca1690-dfb7-437c-9eac-27c72a4fa85c	CERT_FLOW	367	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 15:32:34.290094+00
efee3415-e81e-4e95-a90b-d27960f0a997	CERT_FLOW	368	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 15:32:49.034662+00
bccf2f9e-5286-4a93-8c96-de79262219d8	CERT_FLOW	370	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 15:35:50.190031+00
f15d8a18-66d1-4deb-abe8-c69c678b5309	CERT_FLOW	371	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 15:36:05.116877+00
d990ef5c-2ecc-41ab-8beb-0e11d059916d	DEBUG_V8	372	UNKNOWN	ERROR	Check Response	\N	{}	\N	2026-01-16 15:37:56.688346+00
de2dbfde-a950-4b09-8885-176e8c4d8c1a	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 17:02:52.340504+00
dc3438f6-28af-4b00-b2a0-b496f445b656	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 17:03:00.058446+00
e61b1f5d-8798-4082-929f-61f46c7f8b65	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 17:23:04.248383+00
a4121f39-e857-4e94-bfa9-034c5f68a858	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 17:23:12.363028+00
6bd9375a-bf58-4f38-afd1-f1c3f4355291	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 17:33:55.692907+00
08d0ff84-2026-4cb1-9dd6-11a7665cbeb0	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 17:34:09.241114+00
52722f5e-a4f2-41c6-a9a6-eaa08f0c047c	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 17:59:17.891899+00
4131d866-edcb-46a8-b103-df342d9866cf	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 17:59:26.14224+00
640febc1-a933-453f-b884-b4d0e222bf13	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:26:14.942147+00
a0303b94-a02d-4e09-9241-9f247f61154e	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:26:29.972011+00
255b930c-ca9d-45e7-acd3-54c82fbb0d83	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:28:42.092963+00
7390a5b2-a50d-4ebb-9d4a-1c03a9f035cf	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:28:55.986015+00
f367a541-b540-46b9-919c-60410e6c3544	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:30:04.106966+00
25d1a622-1443-4485-966f-ff7569f81d7c	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:30:18.146243+00
f198e421-7e86-43a0-ad6b-7254ca21f7da	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:31:20.782513+00
63789bf0-a783-4306-b313-0cf0194a5cf0	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:31:35.003225+00
8080e1ad-672b-47e9-96d5-55eac93e22d5	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 18:40:44.002505+00
2f7dbb1b-9a5d-4edd-b89f-a65a74ddc9c2	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 18:40:57.517798+00
4caed030-5ed3-45e5-9e7a-c32f439cf987	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 19:13:54.028451+00
5a6427ce-e8a7-4407-9a53-6166acb418b7	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 19:14:01.93815+00
7da2d390-1686-41ee-8372-d5c0077043e9	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 19:18:57.067741+00
d49e5d86-528a-4d6b-947a-5617859bfa4c	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 19:19:06.130382+00
ffcff5e6-2b5b-4296-a2f2-9f778e07f371	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 19:44:16.166083+00
09fb7b0d-9ac2-4d4d-8b0c-c8b5d0f68afa	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 19:44:30.092257+00
523f4315-fca0-48dc-997f-1145b80b457c	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 20:12:58.803682+00
4efd09ef-7261-4f60-98d6-d277abbc9e88	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 20:13:12.412227+00
5ec33a5a-a8f7-4c9b-95b0-00cccb97b4e6	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 20:17:38.301461+00
fd382c0d-1b3e-4658-9fae-642422577287	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 20:17:46.4877+00
37365c15-839e-4f8c-b37a-99b5a9441367	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 20:42:30.231697+00
e8a9cea1-42ef-423d-afc6-5e388dc5ea40	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 20:42:44.513742+00
a393be9d-9f8c-4b9b-a03a-bf76522b6c62	CERT_FLOW	\N	INFO	ERROR	Testing DB	\N	{}	\N	2026-01-16 21:20:04.641039+00
a67b95f5-c411-46ac-9960-89008d1a1dc8	CERT_FLOW	\N	UNKNOWN	ERROR	Strike 1	\N	{}	\N	2026-01-16 21:20:18.634771+00
e7611576-1ca8-44db-9e44-95299ad56210	Test Workflow	\N	UNKNOWN	ERROR	Test Error Message	\N	{}	\N	2026-01-16 22:00:15.374054+00
8916766d-8d1a-433f-9848-59d61dad9536	Test Workflow	\N	INFO	WARNING	Test Error Message	\N	{}	\N	2026-01-16 22:00:16.69291+00
b501fc07-33f0-49b1-9747-254554c06242	TEST_WORKFLOW	\N	INFO	WARNING	Prueba de notificación de Telegram	\N	{}	\N	2026-01-16 22:06:43.752284+00
718be978-d50c-42a1-8490-740a8dba6b50	AVAILABILITY_V4_DEBUG	\N	\N	CRITICAL	Workflow crashed at DB level	\N	\N	\N	2026-01-16 22:26:07.284784+00
8f24add1-add2-436c-bcc4-6e78c274f6fa	AVAILABILITY_V5_DEBUG	\N	\N	CRITICAL	Still crashing after reference fix	\N	\N	\N	2026-01-16 22:29:27.457134+00
f477a18e-855f-4c1d-b777-3aeadec60344	BB***ct	1687	\N	\N	\N	\N	{"node": "Log: Success", "workflowId": "77HAhYO_vFqeo6iFLWJx5"}	\N	2026-01-26 23:29:10.437242+00
4de47907-6fea-4fb4-850e-3fce0abc48c8	BB***ct	1689	\N	\N	\N	\N	{"node": "Log: Success", "workflowId": "77HAhYO_vFqeo6iFLWJx5"}	\N	2026-01-26 23:54:38.2941+00
afa29a1a-0271-4f4f-bc88-a0df397204fc	BB***ct	1691	\N	\N	\N	\N	{"node": "Log: Success", "workflowId": "77HAhYO_vFqeo6iFLWJx5"}	\N	2026-01-27 00:11:56.984268+00
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: neondb_owner
--

COPY public.users (id, telegram_id, first_name, last_name, username, phone_number, rut, role, language_code, metadata, created_at, updated_at, deleted_at, password_hash, last_selected_provider_id) FROM stdin;
b9f03843-eee6-4607-ac5a-496c6faa9ea1	5391760292	Roger	Gallegos	\N	\N	11111111-1	admin	en	{"email": "dev.n8n.stax@gmail.com"}	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	\N	\N	\N
6b991a66-cbb1-4910-9507-5f43fc07983a	999999999	Test Admin	\N	admin_tester	\N	12345678-5	admin	es	{}	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	\N	\N	\N
41ded616-b5c7-44ea-bed2-b9f9135c7320	888888888	Banned User	\N	banned_tester	\N	\N	user	es	{}	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	\N	\N
c28d963b-4ea0-4861-ac80-9c79cb55370f	777777777	Incomplete User	\N	incomplete_tester	\N	\N	user	es	{}	2026-01-15 14:52:06.081827+00	2026-01-15 14:52:06.081827+00	\N	\N	\N
d5d85414-4c5e-40ca-890d-cb91c93e4095	888777666	System Admin	\N	admin	\N	\N	admin	es	{}	2026-01-24 20:42:41.773789+00	2026-01-24 20:43:20.420308+00	\N	$2a$06$mHxcDiBy1pvl.RUnko.u.uNpsSP29MqlUqyEbPYXgJRWSdNUvfnLm	\N
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
6daa9018-1df4-4dc3-a761-100e1ae11a09	123456789	Test	User	test_user	\N	\N	user	es	{}	2026-01-26 21:27:45.344063+00	2026-01-26 21:27:45.344063+00	\N	\N	\N
\.


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
-- Name: idx_app_config_key; Type: INDEX; Schema: public; Owner: neondb_owner
--

CREATE UNIQUE INDEX idx_app_config_key ON public.app_config USING btree (key);


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

\unrestrict Xk3G4UBP9qScT12pfbKamNnvbq3WRzrRahQwNiIVVmpH4EKA8b2WXpwgIAtcCRZ

