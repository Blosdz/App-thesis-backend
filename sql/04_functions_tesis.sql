CREATE OR REPLACE FUNCTION "AT".fn_tesis_listar_por_usuario(
  p_usuario_id uuid
)
RETURNS TABLE (
  tesis_id uuid,
  estudiante_id uuid,
  universidad_id uuid,
  titulo text,
  descripcion text,
  estado varchar,
  creado_en timestamptz,
  actualizado_en timestamptz,
  asesores jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT
    t.id,
    t.estudiante_id,
    t.universidad_id,
    t.titulo,
    t.descripcion,
    t.estado,
    t.creado_en,
    t.actualizado_en,
    COALESCE(
      jsonb_agg(
        DISTINCT jsonb_build_object(
          'asesor_id', atx.asesor_id,
          'rol', atx.rol,
          'activo', atx.activo,
          'nombre_mostrar', ppa.nombre_mostrar
        )
      ) FILTER (WHERE atx.id IS NOT NULL),
      '[]'::jsonb
    ) AS asesores
  FROM "AT".tesis t
  LEFT JOIN "AT".asesores_tesis atx ON atx.tesis_id = t.id
  LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = atx.asesor_id
  WHERE t.eliminado_en IS NULL
    AND (
      t.estudiante_id = p_usuario_id
      OR EXISTS (
        SELECT 1
        FROM "AT".asesores_tesis atp
        WHERE atp.tesis_id = t.id
          AND atp.asesor_id = p_usuario_id
          AND COALESCE(atp.activo, true) = true
      )
    )
  GROUP BY t.id;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_tesis_obtener_detalle(
  p_usuario_id uuid,
  p_tesis_id uuid
)
RETURNS TABLE (
  tesis jsonb,
  asesores jsonb,
  documentos jsonb,
  modulos jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT
    to_jsonb(t) AS tesis,
    COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'asesor_id', atx.asesor_id,
        'rol', atx.rol,
        'activo', atx.activo,
        'nombre_mostrar', ppa.nombre_mostrar
      ))
      FROM "AT".asesores_tesis atx
      LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = atx.asesor_id
      WHERE atx.tesis_id = t.id
    ), '[]'::jsonb) AS asesores,
    COALESCE((
      SELECT jsonb_agg(to_jsonb(d) - 'ruta_storage')
      FROM "AT".documentos_tesis d
      WHERE d.tesis_id = t.id
    ), '[]'::jsonb) AS documentos,
    COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', mt.id,
        'modulo_lista_id', mt.modulo_lista_id,
        'titulo', ml.titulo,
        'detalle', ml.detalle,
        'estado', mt.estado,
        'progreso', mt.progreso,
        'observacion', mt.observacion
      ))
      FROM "AT".modulos_tesis mt
      JOIN "AT".modulos_lista ml ON ml.id = mt.modulo_lista_id
      WHERE mt.tesis_id = t.id
    ), '[]'::jsonb) AS modulos
  FROM "AT".tesis t
  WHERE t.id = p_tesis_id
    AND t.eliminado_en IS NULL
    AND (
      t.estudiante_id = p_usuario_id
      OR EXISTS (
        SELECT 1
        FROM "AT".asesores_tesis atx
        WHERE atx.tesis_id = t.id
          AND atx.asesor_id = p_usuario_id
          AND COALESCE(atx.activo, true) = true
      )
    );
$$;

CREATE OR REPLACE FUNCTION "AT".fn_tesis_crear(
  p_estudiante_id uuid,
  p_universidad_id uuid,
  p_titulo text,
  p_descripcion text DEFAULT NULL
)
RETURNS TABLE (
  ok boolean,
  tesis_id uuid,
  estudiante_id uuid,
  universidad_id uuid,
  titulo text,
  descripcion text,
  estado varchar,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
DECLARE
  v_tesis_id uuid;
BEGIN
  IF p_titulo IS NULL OR trim(p_titulo) = '' THEN
    RAISE EXCEPTION 'El título es obligatorio';
  END IF;

  INSERT INTO "AT".tesis (estudiante_id, universidad_id, titulo, descripcion, estado)
  VALUES (p_estudiante_id, p_universidad_id, trim(p_titulo), p_descripcion, 'borrador')
  RETURNING id INTO v_tesis_id;

  RETURN QUERY
  SELECT true, t.id, t.estudiante_id, t.universidad_id, t.titulo, t.descripcion, t.estado, 'Tesis creada correctamente'::text
  FROM "AT".tesis t
  WHERE t.id = v_tesis_id;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_tesis_actualizar_estado(
  p_usuario_id uuid,
  p_tesis_id uuid,
  p_estado varchar
)
RETURNS TABLE (
  ok boolean,
  tesis_id uuid,
  estado varchar,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  UPDATE "AT".tesis t
  SET estado = p_estado,
      actualizado_en = now()
  WHERE t.id = p_tesis_id
    AND t.estudiante_id = p_usuario_id
    AND t.eliminado_en IS NULL;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, p_tesis_id, NULL::varchar, 'Tesis no encontrada o sin permiso'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT true, p_tesis_id, p_estado, 'Estado actualizado correctamente'::text;
END;
$$;
