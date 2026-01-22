-- FIX: Internationalization System (Migration V9)
-- Creates a centralized message registry for multi-language support

-- 1. Create app_messages table
CREATE TABLE IF NOT EXISTS public.app_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    tenant_id uuid NOT NULL,
    code varchar(50) NOT NULL,
    lang varchar(10) NOT NULL DEFAULT 'es',
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    UNIQUE(tenant_id, code, lang)
);

CREATE INDEX IF NOT EXISTS idx_app_messages_lookup ON public.app_messages(tenant_id, code, lang);

-- 2. Seed Default Messages
DO $$
DECLARE
    v_tenant_id uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
BEGIN
    -- AUTH MESSAGES
    INSERT INTO public.app_messages (tenant_id, code, lang, message) VALUES
    (v_tenant_id, 'AUTH_MISSING_TOKEN', 'es', 'NO AUTORIZADO: Falta token'),
    (v_tenant_id, 'AUTH_INVALID_TOKEN', 'es', 'NO AUTORIZADO: Token inválido'),
    (v_tenant_id, 'AUTH_EXPIRED_TOKEN', 'es', 'Token expirado'),
    (v_tenant_id, 'AUTH_FORBIDDEN', 'es', 'PROHIBIDO: Se requiere rol de admin'),
    
    -- VALIDATION ERRORS
    (v_tenant_id, 'ERR_INVALID_PRO', 'es', 'ID de profesional inválido'),
    (v_tenant_id, 'ERR_INVALID_SRV', 'es', 'ID de servicio inválido'),
    (v_tenant_id, 'ERR_INVALID_DATE', 'es', 'Fecha inválida'),
    (v_tenant_id, 'ERR_DURATION_RANGE', 'es', 'Duración fuera de rango permitido'),
    
    -- BUSINESS LOGIC
    (v_tenant_id, 'ERR_SRV_NOT_FOUND', 'es', 'Servicio no encontrado'),
    (v_tenant_id, 'ERR_NO_SCHEDULE', 'es', 'No hay horario disponible'),
    (v_tenant_id, 'ERR_SLOT_TAKEN', 'es', 'CONFLICTO: El horario ya está ocupado'),
    (v_tenant_id, 'MSG_BOOKING_SUCCESS', 'es', 'Reserva procesada exitosamente')
    ON CONFLICT (tenant_id, code, lang) DO UPDATE SET message = EXCLUDED.message;

END $$;

-- 3. Helper Function to Get Message
CREATE OR REPLACE FUNCTION public.get_message(
    p_tenant_id uuid,
    p_code text,
    p_lang text DEFAULT 'es'
) RETURNS text AS $$
DECLARE
    v_msg text;
BEGIN
    SELECT message INTO v_msg
    FROM app_messages
    WHERE tenant_id = p_tenant_id AND code = p_code AND lang = p_lang;
    
    -- Fallback to default lang (es) if specific lang not found
    IF v_msg IS NULL AND p_lang != 'es' THEN
        SELECT message INTO v_msg
        FROM app_messages
        WHERE tenant_id = p_tenant_id AND code = p_code AND lang = 'es';
    END IF;
    
    -- Final Fallback: Return code itself
    RETURN COALESCE(v_msg, p_code);
END;
$$ LANGUAGE plpgsql STABLE;

-- Verify
SELECT public.get_message('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'AUTH_MISSING_TOKEN', 'es');
