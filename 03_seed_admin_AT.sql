-- Admin local para desarrollo.
-- Email: admin@tesis.local
-- Password: Admin123!

CREATE SCHEMA IF NOT EXISTS "AT";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

WITH upsert_auth AS (
  INSERT INTO "AT".auth_usuarios (
    email,
    contrasena_hash,
    activo,
    email_verificado,
    creado_en,
    actualizado_en
  )
  VALUES (
    'admin@tesis.local',
    crypt('Admin123!', gen_salt('bf', 12)),
    true,
    true,
    now(),
    now()
  )
  ON CONFLICT (email) DO UPDATE SET
    contrasena_hash = EXCLUDED.contrasena_hash,
    activo = true,
    email_verificado = true,
    actualizado_en = now()
  RETURNING id
),
updated_user AS (
  UPDATE "AT".usuarios u
  SET rol = 'admin',
      verificado = true,
      actualizado_en = now()
  FROM upsert_auth au
  WHERE u.auth_usuario_id = au.id
  RETURNING u.id
),
inserted_user AS (
  INSERT INTO "AT".usuarios (
    auth_usuario_id,
    rol,
    verificado,
    creado_en,
    actualizado_en
  )
  SELECT
    au.id,
    'admin',
    true,
    now(),
    now()
  FROM upsert_auth au
  WHERE NOT EXISTS (SELECT 1 FROM updated_user)
  RETURNING id
)
SELECT
  COALESCE(
    (SELECT id FROM updated_user LIMIT 1),
    (SELECT id FROM inserted_user LIMIT 1)
  ) AS admin_usuario_id;
