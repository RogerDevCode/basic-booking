-- FIX-08: JWT Authentication Support
-- This migration creates tables and functions for JWT-based admin authentication

-- Create admin_sessions table
CREATE TABLE IF NOT EXISTS public.admin_sessions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    last_used_at timestamp with time zone DEFAULT now(),
    is_revoked boolean DEFAULT false
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_admin_sessions_token_hash ON public.admin_sessions(token_hash) WHERE NOT is_revoked;
CREATE INDEX IF NOT EXISTS idx_admin_sessions_user_id ON public.admin_sessions(user_id) WHERE NOT is_revoked;
CREATE INDEX IF NOT EXISTS idx_admin_sessions_expires_at ON public.admin_sessions(expires_at) WHERE NOT is_revoked;
CREATE INDEX IF NOT EXISTS idx_admin_sessions_last_used ON public.admin_sessions(last_used_at) WHERE NOT is_revoked;

-- Function: Create admin JWT token
CREATE OR REPLACE FUNCTION public.create_admin_jwt(
    p_user_id uuid,
    p_tenant_id uuid DEFAULT NULL,
    p_expires_hours integer DEFAULT 24
) RETURNS text AS $$
DECLARE
    v_payload json;
    v_header json;
    v_signature text;
    v_secret text := 'your-secret-key-change-in-production'; -- Should be in env vars
    v_token text;
BEGIN
    -- Header
    v_header := json_build_object(
        'alg', 'HS256',
        'typ', 'JWT'
    );
    
    -- Payload
    v_payload := json_build_object(
        'user_id', p_user_id,
        'role', 'admin',
        'tenant_id', p_tenant_id,
        'iat', floor(extract(epoch from now())),
        'exp', floor(extract(epoch from now() + (p_expires_hours || 24) * interval '1 hour'))
    );
    
    -- Base64URL encode header and payload
    v_token := replace(replace(encode(v_header::text, 'base64'), E'\n', ''), '+', '-') || '.' || 
               replace(replace(encode(v_payload::text, 'base64'), E'\n', ''), '+', '-');
    
    -- Sign token (HMAC-SHA256)
    v_signature := encode(digest(v_token || v_secret, 'sha256'), 'base64');
    v_signature := replace(v_signature, '+', '-');
    v_signature := replace(v_signature, '/', '_');
    v_signature := replace(v_signature, '=', '');
    
    v_token := v_token || '.' || v_signature;
    
    -- Store session
    INSERT INTO admin_sessions (user_id, token_hash, expires_at)
    VALUES (p_user_id, digest(v_token, 'sha256'), (p_expires_hours || 24) * interval '1 hour' from now());
    
    RETURN v_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Verify admin JWT token
CREATE OR REPLACE FUNCTION public.verify_admin_jwt(
    p_token text
) RETURNS TABLE (
    valid boolean,
    user_id uuid,
    role text,
    tenant_id uuid,
    error_message text
) AS $$
DECLARE
    v_parts text[];
    v_header json;
    v_payload json;
    v_secret text := 'your-secret-key-change-in-production';
    v_signature text;
    v_expected_signature text;
    v_current_time bigint;
BEGIN
    -- Split token
    v_parts := string_to_array(p_token, '.');
    IF array_length(v_parts, 1) != 3 THEN
        RETURN QUERY SELECT false, NULL::uuid, NULL, NULL::uuid, 'Invalid token format';
        RETURN;
    END IF;
    
    -- Decode header and payload
    BEGIN
        v_header := json(replace(replace(v_parts[1], '-', '+'), '_', '/') || '=');
        v_payload := json(replace(replace(v_parts[2], '-', '+'), '_', '/') || '=');
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT false, NULL::uuid, NULL, NULL::uuid, 'Invalid base64 encoding';
        RETURN;
    END;
    
    -- Verify expiry
    v_current_time := floor(extract(epoch from now()));
    IF (v_payload->>'exp')::bigint < v_current_time THEN
        RETURN QUERY SELECT false, NULL::uuid, NULL, NULL::uuid, 'Token expired';
        RETURN;
    END IF;
    
    -- Verify signature
    v_signature := v_parts[3];
    v_expected_signature := encode(digest(v_parts[1] || '.' || v_parts[2] || v_secret, 'sha256'), 'base64');
    v_expected_signature := replace(v_expected_signature, '+', '-');
    v_expected_signature := replace(v_expected_signature, '/', '_');
    v_expected_signature := replace(v_expected_signature, '=', '');
    
    IF v_signature != v_expected_signature THEN
        RETURN QUERY SELECT false, NULL::uuid, NULL, NULL::uuid, 'Invalid signature';
        RETURN;
    END IF;
    
    -- Verify admin role
    IF (v_payload->>'role') != 'admin' THEN
        RETURN QUERY SELECT false, NULL::uuid, NULL, NULL::uuid, 'Not an admin token';
        RETURN;
    END IF;
    
    -- Check if session is revoked
    IF EXISTS (SELECT 1 FROM admin_sessions WHERE token_hash = digest(p_token, 'sha256') AND is_revoked = true) THEN
        RETURN QUERY SELECT false, NULL::uuid, NULL, NULL::uuid, 'Token revoked';
        RETURN;
    END IF;
    
    -- Update last used
    UPDATE admin_sessions SET last_used_at = NOW() WHERE token_hash = digest(p_token, 'sha256');
    
    -- Return valid
    RETURN QUERY SELECT 
        true,
        (v_payload->>'user_id')::uuid,
        v_payload->>'role',
        (v_payload->>'tenant_id')::uuid,
        NULL::text
    ;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Revoke admin JWT token
CREATE OR REPLACE FUNCTION public.revoke_admin_jwt(
    p_token_hash text
) RETURNS void AS $$
BEGIN
    UPDATE admin_sessions 
    SET is_revoked = true 
    WHERE token_hash = p_token_hash;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Cleanup expired admin sessions
CREATE OR REPLACE FUNCTION public.cleanup_expired_sessions() RETURNS integer AS $$
DECLARE
    v_deleted_count integer;
BEGIN
    DELETE FROM admin_sessions 
    WHERE (expires_at < NOW() OR is_revoked = true);
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT ALL ON TABLE public.admin_sessions TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.create_admin_jwt TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.verify_admin_jwt TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.revoke_admin_jwt TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_sessions TO neondb_owner;

-- Comments for documentation
COMMENT ON TABLE public.admin_sessions IS 'Stores admin JWT session tokens for authentication.';
COMMENT ON FUNCTION public.create_admin_jwt IS 'Creates a new admin JWT token and stores session.';
COMMENT ON FUNCTION public.verify_admin_jwt IS 'Verifies an admin JWT token and returns user info if valid.';
COMMENT ON FUNCTION public.revoke_admin_jwt IS 'Revokes an admin JWT token.';
COMMENT ON FUNCTION public.cleanup_expired_sessions IS 'Removes expired or revoked admin sessions.';

-- Verify migration
SELECT 'Migration v4: JWT authentication installed successfully' as status;
