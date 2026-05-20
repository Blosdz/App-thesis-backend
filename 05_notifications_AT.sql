CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS "AT".notifications (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid NOT NULL,
  title character varying(150) NOT NULL,
  message text NOT NULL,
  type character varying(50) NOT NULL,
  related_id uuid,
  status character varying(20) DEFAULT 'unread'::character varying NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  read_at timestamp with time zone,
  path text,
  CONSTRAINT notifications_pkey PRIMARY KEY (id)
);

ALTER TABLE "AT".notifications
  ADD COLUMN IF NOT EXISTS user_id uuid,
  ADD COLUMN IF NOT EXISTS title character varying(150),
  ADD COLUMN IF NOT EXISTS message text,
  ADD COLUMN IF NOT EXISTS type character varying(50),
  ADD COLUMN IF NOT EXISTS related_id uuid,
  ADD COLUMN IF NOT EXISTS status varchar(20) DEFAULT 'unread',
  ADD COLUMN IF NOT EXISTS created_at timestamp with time zone DEFAULT now(),
  ADD COLUMN IF NOT EXISTS read_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS path text;

UPDATE "AT".notifications
SET message = COALESCE(message, title, 'Notificación'),
    type = COALESCE(type, 'general'),
    status = COALESCE(status, CASE WHEN read_at IS NOT NULL THEN 'read' ELSE 'unread' END),
    created_at = COALESCE(created_at, now())
WHERE message IS NULL
   OR type IS NULL
   OR status IS NULL
   OR created_at IS NULL;

ALTER TABLE "AT".notifications
  ALTER COLUMN user_id SET NOT NULL,
  ALTER COLUMN title SET NOT NULL,
  ALTER COLUMN message SET NOT NULL,
  ALTER COLUMN type SET NOT NULL,
  ALTER COLUMN status SET DEFAULT 'unread',
  ALTER COLUMN status SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON "AT".notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON "AT".notifications (user_id, status)
  WHERE status = 'unread';
