CREATE OR REPLACE FUNCTION "AT".fn_reunion_listar_por_usuario(
  p_usuario_id uuid,
  p_fecha_inicio timestamptz DEFAULT NULL,
  p_fecha_fin timestamptz DEFAULT NULL
)
RETURNS TABLE (
  reunion_id uuid,
  asesor_id uuid,
  estudiante_id uuid,
  tesis_id uuid,
  estado varchar,
  inicio timestamptz,
  fin timestamptz,
  modalidad varchar,
  lugar text,
  enlace_reunion text,
  pago_id uuid,
  costo_reunion numeric,
  tipo_reunion varchar
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
    r.estado,
    r.inicio,
    r.fin,
    r.modalidad,
    r.lugar,
    r.enlace_reunion,
    r.pago_id,
    r.costo_reunion,
    r.tipo_reunion
  FROM "AT".reuniones_asesor r
  WHERE (r.asesor_id = p_usuario_id OR r.estudiante_id = p_usuario_id)
    AND (p_fecha_inicio IS NULL OR r.inicio >= p_fecha_inicio)
    AND (p_fecha_fin IS NULL OR r.fin <= p_fecha_fin)
  ORDER BY r.inicio DESC;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_reunion_crear(
  p_estudiante_id uuid,
  p_disponibilidad_id uuid,
  p_inicio timestamptz,
  p_fin timestamptz,
  p_tesis_id uuid DEFAULT NULL,
  p_motivo text DEFAULT NULL,
  p_modalidad varchar DEFAULT 'virtual',
  p_lugar text DEFAULT NULL,
  p_enlace_reunion text DEFAULT NULL,
  p_notas text DEFAULT NULL
)
RETURNS TABLE (
  ok boolean,
  reunion_id uuid,
  asesor_id uuid,
  estudiante_id uuid,
  inicio timestamptz,
  fin timestamptz,
  estado varchar,
  pago_id uuid,
  costo_reunion numeric,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public', 'auth'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.r_ok,
    c.r_reunion_id,
    c.r_asesor_id,
    c.r_estudiante_id,
    c.r_inicio,
    c.r_fin,
    c.r_estado,
    c.r_pago_id,
    c.r_costo_reunion,
    c.r_mensaje
  FROM "AT".crear_cita_asesor_estudiante(
    p_estudiante_id,
    p_disponibilidad_id,
    p_inicio,
    p_fin,
    p_tesis_id,
    p_motivo,
    p_notas,
    p_modalidad,
    p_lugar,
    p_enlace_reunion
  ) c;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_reunion_cancelar(
  p_reunion_id uuid,
  p_motivo text DEFAULT NULL
)
RETURNS TABLE (
  ok boolean,
  reunion_id uuid,
  estado_reunion varchar,
  pago_id uuid,
  estado_pago varchar,
  message text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public', 'auth'
AS $$
  SELECT
    c.ok,
    c.reunion_id,
    c.estado_reunion,
    c.pago_id,
    c.estado_pago,
    c.mensaje
  FROM "AT".cancelar_cita_estudiante(p_reunion_id, p_motivo) c;
$$;
