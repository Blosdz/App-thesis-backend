CREATE OR REPLACE FUNCTION "AT".fn_pago_listar_por_usuario(
  p_usuario_id uuid,
  p_rol varchar DEFAULT NULL
)
RETURNS TABLE (
  pago_id uuid,
  pagador_id uuid,
  concepto varchar,
  monto numeric,
  estado varchar,
  codigo_operacion varchar,
  documento_drive_id text,
  url_archivo_drive text,
  nombre_archivo_voucher text,
  tipo_mime_voucher varchar,
  tamano_bytes_voucher bigint,
  subido_en timestamptz,
  tesis_id uuid,
  creado_en timestamptz,
  actualizado_en timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT
    p.id,
    p.pagador_id,
    p.concepto,
    p.monto,
    p.estado,
    p.codigo_operacion,
    p.documento_drive_id,
    p.url_archivo_drive,
    p.nombre_archivo_voucher,
    p.tipo_mime_voucher,
    p.tamano_bytes_voucher,
    p.subido_en,
    p.tesis_id,
    p.creado_en,
    p.actualizado_en
  FROM "AT".pagos p
  WHERE p.pagador_id = p_usuario_id
     OR p_rol = 'admin'
     OR EXISTS (
       SELECT 1
       FROM "AT".pagos_asesor pa
       WHERE pa.pago_id = p.id
         AND pa.asesor_id = p_usuario_id
     )
  ORDER BY p.creado_en DESC;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_pago_registrar(
  p_pagador_id uuid,
  p_concepto varchar,
  p_monto numeric,
  p_tesis_id uuid DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  ok boolean,
  pago_id uuid,
  pagador_id uuid,
  concepto varchar,
  monto numeric,
  estado varchar,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
DECLARE
  v_pago_id uuid;
BEGIN
  IF p_monto IS NULL OR p_monto < 0 THEN
    RAISE EXCEPTION 'El monto debe ser mayor o igual a cero';
  END IF;

  INSERT INTO "AT".pagos (pagador_id, concepto, monto, estado, tesis_id, metadata)
  VALUES (p_pagador_id, p_concepto, p_monto, 'pendiente', p_tesis_id, COALESCE(p_metadata, '{}'::jsonb))
  RETURNING id INTO v_pago_id;

  RETURN QUERY
  SELECT true, p.id, p.pagador_id, p.concepto, p.monto, p.estado, 'Pago registrado correctamente'::text
  FROM "AT".pagos p
  WHERE p.id = v_pago_id;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_pago_registrar_voucher(
  p_pago_id uuid,
  p_pagador_id uuid,
  p_codigo_operacion varchar DEFAULT NULL,
  p_documento_drive_id text DEFAULT NULL,
  p_url_archivo_drive text DEFAULT NULL,
  p_nombre_archivo_voucher varchar DEFAULT NULL,
  p_tipo_mime_voucher varchar DEFAULT NULL,
  p_tamano_bytes_voucher bigint DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  pago_id uuid,
  pagador_id uuid,
  tesis_id uuid,
  concepto varchar,
  monto numeric,
  estado_anterior varchar,
  estado_nuevo varchar,
  codigo_operacion varchar,
  documento_drive_id text,
  url_archivo_drive text,
  nombre_archivo_voucher varchar,
  tipo_mime_voucher varchar,
  tamano_bytes_voucher bigint,
  subido_en timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT *
  FROM "AT".registrar_voucher_pago(
    p_pago_id,
    p_pagador_id,
    p_codigo_operacion,
    p_documento_drive_id,
    p_url_archivo_drive,
    p_nombre_archivo_voucher,
    p_tipo_mime_voucher,
    p_tamano_bytes_voucher,
    p_metadata
  );
$$;

CREATE OR REPLACE FUNCTION "AT".fn_pago_verificar(
  p_pago_id uuid,
  p_aprobado boolean,
  p_nota_verificacion text DEFAULT NULL
)
RETURNS TABLE (
  ok boolean,
  pago_id uuid,
  estado_pago varchar,
  reunion_id uuid,
  estado_reunion varchar,
  message text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public', 'auth'
AS $$
  SELECT
    v.ok,
    v.pago_id,
    v.estado_pago,
    v.reunion_id,
    v.estado_reunion,
    v.mensaje
  FROM "AT".validar_pago_admin(p_pago_id, p_aprobado, p_nota_verificacion) v;
$$;
