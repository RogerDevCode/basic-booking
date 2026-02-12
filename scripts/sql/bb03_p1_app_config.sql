INSERT INTO app_config (key, value, type, category, description, is_public)
VALUES
  ('TIMEZONE', 'UTC', 'string', 'availability', 'Timezone base del sistema (Area/Location).', false),
  ('BOOKING_WINDOW_DAYS', '14', 'number', 'availability', 'Cantidad maxima de dias de disponibilidad.', false),
  ('MIN_BOOKING_ADVANCE_HOURS', '2', 'number', 'availability', 'Horas minimas de anticipacion.', false),
  ('MAX_SLOTS_PER_QUERY', '1000', 'number', 'availability', 'Limite de slots por consulta.', false),
  ('DEFAULT_DAYS_RANGE', '14', 'number', 'availability', 'Rango por defecto cuando no se especifica days_range.', false)
ON CONFLICT (key) DO NOTHING;

CREATE OR REPLACE FUNCTION public.validate_app_config_availability()
RETURNS trigger
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

DROP TRIGGER IF EXISTS trg_validate_app_config_availability ON public.app_config;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_validate_app_config_availability'
  ) THEN
    EXECUTE 'CREATE TRIGGER trg_validate_app_config_availability
             BEFORE INSERT OR UPDATE ON public.app_config
             FOR EACH ROW
             EXECUTE FUNCTION public.validate_app_config_availability()';
  END IF;
END;
$$;
