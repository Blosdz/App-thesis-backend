-- Limpia triggers heredados de Supabase que no deben ejecutarse en PostgreSQL local.
-- El error tipico es: schema "net" does not exist al insertar en "AT".tesis.

BEGIN;

DO $$
DECLARE
  trigger_name text;
BEGIN
  IF to_regclass('"AT".tesis') IS NULL THEN
    RETURN;
  END IF;

  FOR trigger_name IN
    SELECT tg.tgname
    FROM pg_trigger tg
    JOIN pg_class cls ON cls.oid = tg.tgrelid
    JOIN pg_proc proc ON proc.oid = tg.tgfoid
    JOIN pg_namespace proc_ns ON proc_ns.oid = proc.pronamespace
    WHERE NOT tg.tgisinternal
      AND cls.oid = '"AT".tesis'::regclass
      AND proc_ns.nspname = 'AT'
      AND proc.proname = 'trigger_create_drive_folder'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON "AT".tesis', trigger_name);
  END LOOP;
END $$;

DROP FUNCTION IF EXISTS "AT".trigger_create_drive_folder();

COMMIT;
