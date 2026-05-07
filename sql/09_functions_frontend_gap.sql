CREATE OR REPLACE FUNCTION "AT".fn_catalogo_universidades()
RETURNS TABLE (
  id uuid,
  nombre varchar,
  ubicacion varchar,
  pais varchar
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT u.id, u.nombre, u.ubicacion, u.pais
  FROM "AT".universidades u
  ORDER BY u.nombre ASC;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_plan_comprar(
  p_usuario_id uuid,
  p_plan_id uuid
)
RETURNS TABLE (
  pago_id uuid,
  monto numeric,
  estado text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public', 'auth'
AS $$
  SELECT *
  FROM "AT".fn_iniciar_pago_plan(p_usuario_id, p_plan_id);
$$;

CREATE OR REPLACE FUNCTION "AT".fn_suscripcion_obtener_actual(
  p_usuario_id uuid
)
RETURNS TABLE (
  id uuid,
  estudiante_id uuid,
  plan_id uuid,
  estado varchar,
  asesorias_incluidas integer,
  asesorias_usadas integer,
  asesorias_disponibles integer,
  iniciado_en timestamptz,
  expira_en timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public', 'auth'
AS $$
  SELECT *
  FROM "AT".obtener_suscripcion_estudiante(p_usuario_id);
$$;

CREATE OR REPLACE FUNCTION "AT".fn_asesor_cambiar_estado_relacion(
  p_relacion_id uuid,
  p_estado text
)
RETURNS TABLE (
  ok boolean,
  relacion_id uuid,
  estado text,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  PERFORM "AT".cambiar_estado_relacion(p_relacion_id, p_estado);
  RETURN QUERY SELECT true, p_relacion_id, p_estado, 'Relación actualizada correctamente'::text;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_reunion_guardar_meet(
  p_reunion_id uuid,
  p_google_event_id text,
  p_enlace_reunion text,
  p_meet_codigo text DEFAULT NULL,
  p_error text DEFAULT NULL
)
RETURNS TABLE (
  ok boolean,
  reunion_id uuid,
  enlace_reunion text,
  google_event_id text,
  meet_codigo text,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  UPDATE "AT".reuniones_asesor r
  SET enlace_reunion = COALESCE(p_enlace_reunion, r.enlace_reunion),
      google_event_id = p_google_event_id,
      meet_codigo = p_meet_codigo,
      meet_error = p_error,
      meet_creado_en = CASE WHEN p_error IS NULL THEN now() ELSE r.meet_creado_en END,
      actualizado_en = now()
  WHERE r.id = p_reunion_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, p_reunion_id, NULL::text, NULL::text, NULL::text, 'Reunión no encontrada'::text;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT true, r.id, r.enlace_reunion, r.google_event_id, r.meet_codigo, 'Meet actualizado correctamente'::text
  FROM "AT".reuniones_asesor r
  WHERE r.id = p_reunion_id;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_reunion_obtener_para_meet(
  p_usuario_id uuid,
  p_reunion_id uuid
)
RETURNS TABLE (
  reunion_id uuid,
  asesor_id uuid,
  estudiante_id uuid,
  tesis_id uuid,
  inicio timestamptz,
  fin timestamptz,
  motivo text,
  notas text,
  asesor_email varchar,
  estudiante_email varchar
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT
    r.id,
    r.asesor_id,
    r.estudiante_id,
    r.tesis_id,
    r.inicio,
    r.fin,
    r.motivo,
    r.notas,
    au_asesor.email,
    au_estudiante.email
  FROM "AT".reuniones_asesor r
  JOIN "AT".usuarios u_asesor ON u_asesor.id = r.asesor_id
  JOIN "AT".auth_usuarios au_asesor ON au_asesor.id = u_asesor.auth_usuario_id
  JOIN "AT".usuarios u_estudiante ON u_estudiante.id = r.estudiante_id
  JOIN "AT".auth_usuarios au_estudiante ON au_estudiante.id = u_estudiante.auth_usuario_id
  WHERE r.id = p_reunion_id
    AND (r.asesor_id = p_usuario_id OR r.estudiante_id = p_usuario_id);
$$;

CREATE OR REPLACE FUNCTION "AT".fn_tesis_guardar_carpeta_drive(
  p_usuario_id uuid,
  p_tesis_id uuid,
  p_carpeta_drive_id text
)
RETURNS TABLE (
  ok boolean,
  tesis_id uuid,
  carpeta_drive_id text,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  UPDATE "AT".tesis t
  SET carpeta_drive_id = p_carpeta_drive_id,
      actualizado_en = now()
  WHERE t.id = p_tesis_id
    AND (
      t.estudiante_id = p_usuario_id
      OR EXISTS (
        SELECT 1 FROM "AT".asesores_tesis atx
        WHERE atx.tesis_id = t.id
          AND atx.asesor_id = p_usuario_id
          AND COALESCE(atx.activo, true) = true
      )
    );

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, p_tesis_id, NULL::text, 'Tesis no encontrada o sin permiso'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, p_tesis_id, p_carpeta_drive_id, 'Carpeta Drive actualizada correctamente'::text;
END;
$$;
