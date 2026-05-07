CREATE OR REPLACE FUNCTION "AT".fn_documento_listar_por_tesis(
  p_usuario_id uuid,
  p_tesis_id uuid
)
RETURNS TABLE (
  documento_id uuid,
  tesis_id uuid,
  subido_por uuid,
  nombre_archivo varchar,
  url_archivo_drive text,
  documento_drive_id text,
  version integer,
  estado_revision varchar,
  comentario_revision text,
  tipo_mime varchar,
  tamano_bytes bigint,
  creado_en timestamptz,
  actualizado_en timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT
    d.id,
    d.tesis_id,
    d.subido_por,
    d.nombre_archivo,
    d.url_archivo_drive,
    d.documento_drive_id,
    d.version,
    d.estado_revision,
    d.comentario_revision,
    d.tipo_mime,
    d.tamano_bytes,
    d.creado_en,
    d.actualizado_en
  FROM "AT".documentos_tesis d
  JOIN "AT".tesis t ON t.id = d.tesis_id
  WHERE d.tesis_id = p_tesis_id
    AND (
      t.estudiante_id = p_usuario_id
      OR EXISTS (
        SELECT 1
        FROM "AT".asesores_tesis atx
        WHERE atx.tesis_id = t.id
          AND atx.asesor_id = p_usuario_id
          AND COALESCE(atx.activo, true) = true
      )
    )
  ORDER BY d.creado_en DESC;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_documento_registrar(
  p_tesis_id uuid,
  p_subido_por uuid,
  p_nombre_archivo varchar,
  p_url_archivo_drive text,
  p_carpeta_drive_id text DEFAULT NULL,
  p_documento_drive_id text DEFAULT NULL,
  p_version integer DEFAULT 1,
  p_tipo_mime varchar DEFAULT NULL,
  p_tamano_bytes bigint DEFAULT NULL
)
RETURNS TABLE (
  ok boolean,
  documento_id uuid,
  tesis_id uuid,
  version integer,
  documento_drive_id text,
  url_archivo_drive text,
  message text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT
    r.r_ok,
    r.r_documento_id,
    r.r_tesis_id,
    r.r_version,
    r.r_documento_drive_id,
    r.r_url_archivo_drive,
    r.r_mensaje
  FROM "AT".registrar_documento_tesis(
    p_tesis_id,
    p_subido_por,
    p_nombre_archivo,
    p_url_archivo_drive,
    p_carpeta_drive_id,
    p_documento_drive_id,
    p_version,
    p_tipo_mime,
    p_tamano_bytes
  ) r;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_documento_actualizar_revision(
  p_usuario_id uuid,
  p_documento_id uuid,
  p_estado_revision varchar,
  p_comentario_revision text DEFAULT NULL
)
RETURNS TABLE (
  ok boolean,
  documento_id uuid,
  estado_revision varchar,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  UPDATE "AT".documentos_tesis d
  SET estado_revision = p_estado_revision,
      comentario_revision = p_comentario_revision,
      actualizado_en = now()
  WHERE d.id = p_documento_id
    AND EXISTS (
      SELECT 1
      FROM "AT".asesores_tesis atx
      WHERE atx.tesis_id = d.tesis_id
        AND atx.asesor_id = p_usuario_id
        AND COALESCE(atx.activo, true) = true
    );

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, p_documento_id, NULL::varchar, 'Documento no encontrado o sin permiso'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, p_documento_id, p_estado_revision, 'Revisión actualizada correctamente'::text;
END;
$$;
