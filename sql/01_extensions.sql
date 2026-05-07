CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS "AT";

CREATE OR REPLACE FUNCTION "AT".current_auth_usuario_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT NULLIF(current_setting('app.current_auth_usuario_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION "AT".current_usuario_id()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT u.id
  FROM "AT".usuarios u
  WHERE u.auth_usuario_id = "AT".current_auth_usuario_id()
  LIMIT 1;
$$;

CREATE SCHEMA IF NOT EXISTS auth;

CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid
LANGUAGE sql
STABLE
AS $$
  SELECT "AT".current_auth_usuario_id();
$$;
