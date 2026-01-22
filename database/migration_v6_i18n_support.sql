-- FIX-12: Internationalization (i18n) Support
-- This migration adds message translations for multi-language support

-- Create message_translations table
CREATE TABLE IF NOT EXISTS public.message_translations (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code text NOT NULL,
    tenant_id uuid, -- NULL means default/tenant-independent
    language public.supported_lang NOT NULL,
    template text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT message_translations_check_code CHECK (code IS NOT NULL AND length(trim(code)) > 0),
    CONSTRAINT message_translations_check_template CHECK (length(trim(template)) > 0)
);

-- Unique constraint: code + tenant_id + language (tenant-independent duplicates allowed)
CREATE UNIQUE INDEX IF NOT EXISTS idx_message_translations_unique ON public.message_translations(code, coalesce(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid), language) WHERE is_active = true;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_message_translations_code ON public.message_translations(code) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_message_translations_language ON public.message_translations(language) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_message_translations_tenant ON public.message_translations(tenant_id) WHERE is_active = true AND tenant_id IS NOT NULL;

-- Function: Get message translation
CREATE OR REPLACE FUNCTION public.get_message_translation(
    p_code text,
    p_language public.supported_lang DEFAULT 'es',
    p_tenant_id uuid DEFAULT NULL
) RETURNS text AS $$
DECLARE
    v_message text;
BEGIN
    -- Try to get tenant-specific translation first
    IF p_tenant_id IS NOT NULL THEN
        SELECT template INTO v_message
        FROM message_translations
        WHERE code = p_code
          AND language = p_language
          AND tenant_id = p_tenant_id
          AND is_active = true
        LIMIT 1;
    END IF;
    
    -- Fall back to default (tenant-independent) translation
    IF v_message IS NULL THEN
        SELECT template INTO v_message
        FROM message_translations
        WHERE code = p_code
          AND language = p_language
          AND tenant_id IS NULL
          AND is_active = true
        LIMIT 1;
    END IF;
    
    -- Fall back to Spanish (default language) if not found
    IF v_message IS NULL AND p_language != 'es' THEN
        SELECT template INTO v_message
        FROM message_translations
        WHERE code = p_code
          AND language = 'es'
          AND tenant_id IS NULL
          AND is_active = true
        LIMIT 1;
    END IF;
    
    -- If still not found, return the code itself
    IF v_message IS NULL THEN
        v_message := 'Missing translation: ' || p_code;
    END IF;
    
    RETURN v_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Get message with variable substitution
CREATE OR REPLACE FUNCTION public.get_message_with_vars(
    p_code text,
    p_variables jsonb DEFAULT '{}'::jsonb,
    p_language public.supported_lang DEFAULT 'es',
    p_tenant_id uuid DEFAULT NULL
) RETURNS text AS $$
DECLARE
    v_template text;
    v_message text;
    v_key text;
BEGIN
    -- Get template
    v_template := get_message_translation(p_code, p_language, p_tenant_id);
    
    -- Substitute variables
    v_message := v_template;
    FOR v_key IN SELECT key FROM jsonb_object_keys(p_variables) LOOP
        v_message := replace(
            v_message,
            '{' || v_key || '}',
            p_variables->>v_key::text
        );
    END LOOP;
    
    RETURN v_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function: Upsert message translation
CREATE OR REPLACE FUNCTION public.upsert_message_translation(
    p_code text,
    p_language public.supported_lang,
    p_template text,
    p_tenant_id uuid DEFAULT NULL
) RETURNS uuid AS $$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO message_translations (code, language, template, tenant_id)
    VALUES (p_code, p_language, p_template, p_tenant_id)
    ON CONFLICT (code, coalesce(tenant_id, '00000000-0000-0000-0000-000000000000'::uuid), language)
    DO UPDATE SET 
        template = EXCLUDED.template,
        is_active = true,
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Default message translations
INSERT INTO public.message_translations (code, tenant_id, language, template) VALUES
    -- Booking messages (Spanish - default)
    ('BOOKING_CONFIRMED', NULL, 'es', 'Tu reserva está confirmada: {booking_id}'),
    ('BOOKING_CONFIRMED', NULL, 'en', 'Your booking is confirmed: {booking_id}'),
    ('BOOKING_CONFIRMED', NULL, 'pt', 'Sua reserva está confirmada: {booking_id}'),
    ('BOOKING_CANCELLED', NULL, 'es', 'Tu reserva ha sido cancelada: {booking_id}'),
    ('BOOKING_CANCELLED', NULL, 'en', 'Your booking has been cancelled: {booking_id}'),
    ('BOOKING_CANCELLED', NULL, 'pt', 'Sua reserva foi cancelada: {booking_id}'),
    ('REMINDER_24H', NULL, 'es', 'Hola {first_name}, tu cita con {pro_name} es mañana a las {time}'),
    ('REMINDER_24H', NULL, 'en', 'Hello {first_name}, your appointment with {pro_name} is tomorrow at {time}'),
    ('REMINDER_24H', NULL, 'pt', 'Olá {first_name}, seu compromisso com {pro_name} é amanhã às {time}'),
    ('REMINDER_2H', NULL, 'es', 'Tu cita con {pro_name} es pronto, a las {time}'),
    ('REMINDER_2H', NULL, 'en', 'Your appointment with {pro_name} is coming up at {time}'),
    ('REMINDER_2H', NULL, 'pt', 'Seu compromisso com {pro_name} é em breve, às {time}'),
    ('NO_AVAILABILITY', NULL, 'es', 'No hay disponibilidad para la fecha seleccionada'),
    ('NO_AVAILABILITY', NULL, 'en', 'No availability for selected date'),
    ('NO_AVAILABILITY', NULL, 'pt', 'Sem disponibilidade para a data selecionada'),
    ('INVALID_DATE', NULL, 'es', 'La fecha seleccionada no es válida'),
    ('INVALID_DATE', NULL, 'en', 'The selected date is invalid'),
    ('INVALID_DATE', NULL, 'pt', 'A data selecionada não é válida'),
    ('PROFESSIONAL_NOT_FOUND', NULL, 'es', 'Profesional no encontrado'),
    ('PROFESSIONAL_NOT_FOUND', NULL, 'en', 'Professional not found'),
    ('PROFESSIONAL_NOT_FOUND', NULL, 'pt', 'Profissional não encontrado'),
    ('PAYMENT_FAILED', NULL, 'es', 'El pago falló. Por favor intenta nuevamente'),
    ('PAYMENT_FAILED', NULL, 'en', 'Payment failed. Please try again'),
    ('PAYMENT_FAILED', NULL, 'pt', 'O pagamento falhou. Tente novamente'),
    ('RATE_LIMIT_EXCEEDED', NULL, 'es', 'Has excedido el límite de solicitudes. Por favor espera un momento'),
    ('RATE_LIMIT_EXCEEDED', NULL, 'en', 'You have exceeded the rate limit. Please wait a moment'),
    ('RATE_LIMIT_EXCEEDED', NULL, 'pt', 'Você excedeu o limite de solicitações. Aguarde um momento')
ON CONFLICT DO NOTHING;

-- Grant permissions
GRANT ALL ON TABLE public.message_translations TO neondb_owner;
GRANT USAGE ON SCHEMA public TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.get_message_translation TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.get_message_with_vars TO neondb_owner;
GRANT EXECUTE ON FUNCTION public.upsert_message_translation TO neondb_owner;

-- Comments for documentation
COMMENT ON TABLE public.message_translations IS 'Stores message templates for multi-language support. Variables use {var_name} syntax.';
COMMENT ON FUNCTION public.get_message_translation IS 'Retrieves a message template for the given code and language. Falls back to Spanish (default) if not found.';
COMMENT ON FUNCTION public.get_message_with_vars IS 'Retrieves and formats a message with variable substitution. Use {var_name} syntax in templates.';
COMMENT ON FUNCTION public.upsert_message_translation IS 'Upserts (inserts or updates) a message translation.';

-- Verify migration
SELECT 'Migration v6: i18n support installed successfully' as status;
