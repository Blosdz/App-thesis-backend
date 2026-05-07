CREATE OR REPLACE FUNCTION "AT".fn_auth_crear_usuario(
  p_email varchar,
  p_rol varchar,
  p_contrasena text DEFAULT 'app_theseis'
)
RETURNS TABLE (
  auth_usuario_id uuid,
  usuario_id uuid,
  email varchar,
  rol varchar,
  verificado boolean,
  email_verificado boolean,
  activo boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
DECLARE
  v_auth_usuario_id uuid;
  v_usuario_id uuid;
  v_email varchar;
BEGIN
  v_email := lower(trim(p_email));

  IF v_email IS NULL OR v_email = '' THEN
    RAISE EXCEPTION 'El email es obligatorio';
  END IF;

  IF p_contrasena IS NULL OR length(p_contrasena) < 8 THEN
    RAISE EXCEPTION 'La contraseña debe tener al menos 8 caracteres';
  END IF;

  IF p_rol NOT IN ('admin', 'asesor', 'estudiante') THEN
    RAISE EXCEPTION 'Rol inválido';
  END IF;

  INSERT INTO "AT".auth_usuarios (email, contrasena_hash)
  VALUES (v_email, crypt(p_contrasena, gen_salt('bf', 12)))
  RETURNING id INTO v_auth_usuario_id;

  INSERT INTO "AT".usuarios (auth_usuario_id, rol, verificado)
  VALUES (v_auth_usuario_id, p_rol, false)
  RETURNING id INTO v_usuario_id;

  RETURN QUERY
  SELECT
    au.id,
    u.id,
    au.email,
    u.rol,
    u.verificado,
    au.email_verificado,
    au.activo
  FROM "AT".auth_usuarios au
  JOIN "AT".usuarios u ON u.auth_usuario_id = au.id
  WHERE au.id = v_auth_usuario_id;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El email ya está registrado';
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_auth_login_usuario(
  p_email varchar,
  p_contrasena text
)
RETURNS TABLE (
  auth_usuario_id uuid,
  usuario_id uuid,
  email varchar,
  rol varchar,
  verificado boolean,
  email_verificado boolean,
  activo boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
DECLARE
  v_email varchar;
  v_auth_usuario_id uuid;
BEGIN
  v_email := lower(trim(p_email));

  SELECT au.id
  INTO v_auth_usuario_id
  FROM "AT".auth_usuarios au
  WHERE au.email = v_email
    AND au.activo = true
    AND au.contrasena_hash = crypt(p_contrasena, au.contrasena_hash)
  LIMIT 1;

  IF v_auth_usuario_id IS NULL THEN
    RETURN;
  END IF;

  UPDATE "AT".auth_usuarios au
  SET ultimo_login_en = now(),
      actualizado_en = now()
  WHERE au.id = v_auth_usuario_id;

  RETURN QUERY
  SELECT
    au.id,
    u.id,
    au.email,
    u.rol,
    u.verificado,
    au.email_verificado,
    au.activo
  FROM "AT".auth_usuarios au
  JOIN "AT".usuarios u ON u.auth_usuario_id = au.id
  WHERE au.id = v_auth_usuario_id;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_auth_cambiar_contrasena(
  p_auth_usuario_id uuid,
  p_contrasena_actual text,
  p_contrasena_nueva text
)
RETURNS TABLE (
  ok boolean,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  IF p_contrasena_nueva IS NULL OR length(p_contrasena_nueva) < 8 THEN
    RAISE EXCEPTION 'La contraseña nueva debe tener al menos 8 caracteres';
  END IF;

  UPDATE "AT".auth_usuarios au
  SET contrasena_hash = crypt(p_contrasena_nueva, gen_salt('bf', 12)),
      actualizado_en = now()
  WHERE au.id = p_auth_usuario_id
    AND au.activo = true
    AND au.contrasena_hash = crypt(p_contrasena_actual, au.contrasena_hash);

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Contraseña actual incorrecta'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, 'Contraseña actualizada correctamente'::text;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_auth_desactivar_usuario(
  p_auth_usuario_id uuid
)
RETURNS TABLE (
  ok boolean,
  auth_usuario_id uuid,
  activo boolean,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  UPDATE "AT".auth_usuarios au
  SET activo = false,
      actualizado_en = now()
  WHERE au.id = p_auth_usuario_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, p_auth_usuario_id, NULL::boolean, 'Usuario no encontrado'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, p_auth_usuario_id, false, 'Usuario desactivado correctamente'::text;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_usuario_obtener_actual(
  p_auth_usuario_id uuid
)
RETURNS TABLE (
  usuario_id uuid,
  auth_usuario_id uuid,
  email varchar,
  rol varchar,
  verificado boolean,
  email_verificado boolean,
  activo boolean,
  perfil jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT
    u.id AS usuario_id,
    au.id AS auth_usuario_id,
    au.email,
    u.rol,
    u.verificado,
    au.email_verificado,
    au.activo,
    CASE
      WHEN u.rol = 'estudiante' THEN (
        SELECT to_jsonb(pe) - 'id' - 'estudiante_id'
        FROM "AT".perfil_estudiante pe
        WHERE pe.estudiante_id = u.id
        LIMIT 1
      )
      WHEN u.rol = 'asesor' THEN (
        SELECT to_jsonb(pa) - 'id' - 'asesor_id'
        FROM "AT".perfil_publico_asesor pa
        WHERE pa.asesor_id = u.id
        LIMIT 1
      )
      ELSE NULL::jsonb
    END AS perfil
  FROM "AT".auth_usuarios au
  JOIN "AT".usuarios u ON u.auth_usuario_id = au.id
  WHERE au.id = p_auth_usuario_id
    AND au.activo = true;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_auth_reset_contrasena(
  p_auth_usuario_id uuid,
  p_contrasena_nueva text
)
RETURNS TABLE (
  ok boolean,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  IF p_contrasena_nueva IS NULL OR length(p_contrasena_nueva) < 8 THEN
    RAISE EXCEPTION 'La contraseña nueva debe tener al menos 8 caracteres';
  END IF;

  UPDATE "AT".auth_usuarios au
  SET contrasena_hash = crypt(p_contrasena_nueva, gen_salt('bf', 12)),
      actualizado_en = now()
  WHERE au.id = p_auth_usuario_id
    AND au.activo = true;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Usuario no encontrado o inactivo'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, 'Contraseña actualizada correctamente'::text;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_auth_crear_invitacion(
  p_email text,
  p_nombre text DEFAULT NULL,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  ok boolean,
  invitacion_id uuid,
  email text,
  estado varchar,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
DECLARE
  v_invitacion_id uuid;
BEGIN
  INSERT INTO "AT".invitaciones_pendientes (email, nombre, payload, estado)
  VALUES (lower(trim(p_email)), p_nombre, COALESCE(p_payload, '{}'::jsonb), 'pendiente')
  RETURNING id INTO v_invitacion_id;

  RETURN QUERY
  SELECT true, i.id, i.email, i.estado, 'Invitación encolada correctamente'::text
  FROM "AT".invitaciones_pendientes i
  WHERE i.id = v_invitacion_id;
END;
$$;
