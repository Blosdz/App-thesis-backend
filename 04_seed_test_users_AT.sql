-- Solo desarrollo local. Ambas cuentas usan la clave app_theseis.
-- Reejecutar conserva los IDs y restablece la clave de estas dos cuentas.
BEGIN;

INSERT INTO "AT".auth_usuarios (email, contrasena_hash, activo, email_verificado)
VALUES
  ('estudiante@app-thesis.test', crypt('app_theseis', gen_salt('bf', 12)), true, true),
  ('asesor@app-thesis.test', crypt('app_theseis', gen_salt('bf', 12)), true, true)
ON CONFLICT (email) DO UPDATE SET
  contrasena_hash = EXCLUDED.contrasena_hash,
  activo = true,
  email_verificado = true,
  actualizado_en = now();

UPDATE "AT".usuarios u
SET rol = CASE au.email
    WHEN 'estudiante@app-thesis.test' THEN 'estudiante'
    ELSE 'asesor'
  END,
  verificado = true,
  actualizado_en = now()
FROM "AT".auth_usuarios au
WHERE u.auth_usuario_id = au.id
  AND au.email IN ('estudiante@app-thesis.test', 'asesor@app-thesis.test');

INSERT INTO "AT".usuarios (auth_usuario_id, rol, verificado)
SELECT au.id,
  CASE au.email
    WHEN 'estudiante@app-thesis.test' THEN 'estudiante'
    ELSE 'asesor'
  END,
  true
FROM "AT".auth_usuarios au
WHERE au.email IN ('estudiante@app-thesis.test', 'asesor@app-thesis.test')
  AND NOT EXISTS (
    SELECT 1 FROM "AT".usuarios u WHERE u.auth_usuario_id = au.id
  );

COMMIT;
