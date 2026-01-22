-- FIX-10: Request ID Correlation
-- This migration adds request_id tracking for distributed tracing

-- Add request_id column to audit_logs
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS request_id text;
CREATE INDEX IF NOT EXISTS idx_audit_logs_request_id ON public.audit_logs(request_id);

-- Add request_id column to system_errors
ALTER TABLE public.system_errors ADD COLUMN IF NOT EXISTS request_id text;
CREATE INDEX IF NOT EXISTS idx_system_errors_request_id ON public.system_errors(request_id);

-- Function: Generate UUID for request tracing
CREATE OR REPLACE FUNCTION public.generate_request_id() RETURNS text AS $$
BEGIN
    RETURN 'req_' || encode(gen_random_bytes(16), 'hex');
END;
$$ LANGUAGE sql SECURITY DEFINER;

-- Function: Create audit log with request_id
CREATE OR REPLACE FUNCTION public.log_audit_with_request(
    p_table_name text,
    p_record_id uuid,
    p_action public.audit_action,
    p_performed_by text,
    p_old_values jsonb DEFAULT NULL,
    p_new_values jsonb DEFAULT NULL,
    p_request_id text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
    v_audit_id uuid;
BEGIN
    INSERT INTO audit_logs (
        table_name, record_id, action, performed_by, 
        old_values, new_values, request_id, timestamp
    ) VALUES (
        p_table_name, p_record_id, p_action, p_performed_by,
        p_old_values, p_new_values, p_request_id, now()
    ) RETURNING id INTO v_audit_id;
    
    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Create system error with request_id
CREATE OR REPLACE FUNCTION public.log_system_error_with_request(
    p_workflow_name text,
    p_error_type text,
    p_severity text,
    p_error_message text,
    p_error_context jsonb DEFAULT NULL,
    p_request_id text DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
    v_error_id uuid;
BEGIN
    INSERT INTO system_errors (
        workflow_name, error_type, severity, error_message,
        error_context, request_id, created_at
    ) VALUES (
        p_workflow_name, p_error_type, p_severity, p_error_message,
        p_error_context, p_request_id, now()
    ) RETURNING error_id INTO v_error_id;
    
    RETURN v_error_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get audit logs by request_id
CREATE OR REPLACE FUNCTION public.get_audit_logs_by_request(
    p_request_id text
) RETURNS TABLE (
    audit_id uuid,
    table_name text,
    action public.audit_action,
    performed_by text,
    created_at timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT id, table_name, action, performed_by, timestamp
    FROM audit_logs
    WHERE request_id = p_request_id
    ORDER BY timestamp ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get system errors by request_id
CREATE OR REPLACE FUNCTION public.get_system_errors_by_request(
    p_request_id text
) RETURNS TABLE (
    error_id uuid,
    workflow_name text,
    error_type text,
    severity text,
    error_message text,
    created_at timestamp with time zone
) AS $$
BEGIN
    RETURN QUERY
    SELECT error_id, workflow_name, error_type, severity, error_message, created_at
    FROM system_errors
    WHERE request_id = p_request_id
    ORDER BY created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.generate_request_id TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.log_audit_with_request TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.log_system_error_with_request TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.get_audit_logs_by_request TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.get_system_errors_by_request TO neondb_owner;

-- Comments for documentation
COMMENT ON FUNCTION public.generate_request_id IS 'Generates a unique request ID for distributed tracing.';
COMMENT ON FUNCTION public.log_audit_with_request IS 'Creates an audit log entry with request_id correlation.';
COMMENT ON FUNCTION public.log_system_error_with_request IS 'Creates a system error entry with request_id correlation.';
COMMENT ON FUNCTION public.get_audit_logs_by_request IS 'Retrieves all audit logs for a given request_id.';
COMMENT ON FUNCTION public.get_system_errors_by_request IS 'Retrieves all system errors for a given request_id.';

-- Verify migration
SELECT 'Migration v5: Request ID correlation installed successfully' as status;
