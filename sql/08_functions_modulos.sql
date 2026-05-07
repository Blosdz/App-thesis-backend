CREATE OR REPLACE FUNCTION "AT".fn_modulo_listar_por_tesis(
  p_usuario_id uuid,
  p_tesis_id uuid
)
RETURNS TABLE (
  modulo_tesis_id uuid,
  tesis_id uuid,
  modulo_lista_id uuid,
  titulo text,
  detalle text,
  estructura jsonb,
  estado varchar,
  progreso integer,
  observacion text,
  creado_en timestamptz,
  actualizado_en timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
  SELECT
    mt.id,
    mt.tesis_id,
    mt.modulo_lista_id,
    ml.titulo,
    ml.detalle,
    ml.estructura,
    mt.estado,
    mt.progreso,
    mt.observacion,
    mt.creado_en,
    mt.actualizado_en
  FROM "AT".modulos_tesis mt
  JOIN "AT".modulos_lista ml ON ml.id = mt.modulo_lista_id
  JOIN "AT".tesis t ON t.id = mt.tesis_id
  WHERE mt.tesis_id = p_tesis_id
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
  ORDER BY ml.prioridad ASC, mt.creado_en ASC;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_modulo_crear_para_tesis(
  p_usuario_id uuid,
  p_tesis_id uuid,
  p_modulo_lista_id uuid
)
RETURNS TABLE (
  ok boolean,
  modulo_tesis_id uuid,
  tesis_id uuid,
  modulo_lista_id uuid,
  estado varchar,
  progreso integer,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
DECLARE
  v_modulo_tesis_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM "AT".tesis t
    WHERE t.id = p_tesis_id
      AND t.estudiante_id = p_usuario_id
      AND t.eliminado_en IS NULL
  ) THEN
    RAISE EXCEPTION 'Tesis no encontrada o sin permiso';
  END IF;

  INSERT INTO "AT".modulos_tesis (tesis_id, modulo_lista_id)
  VALUES (p_tesis_id, p_modulo_lista_id)
  RETURNING id INTO v_modulo_tesis_id;

  RETURN QUERY
  SELECT true, mt.id, mt.tesis_id, mt.modulo_lista_id, mt.estado, mt.progreso, 'Módulo creado correctamente'::text
  FROM "AT".modulos_tesis mt
  WHERE mt.id = v_modulo_tesis_id;
END;
$$;

CREATE OR REPLACE FUNCTION "AT".fn_modulo_actualizar_estado(
  p_usuario_id uuid,
  p_modulo_tesis_id uuid,
  p_estado varchar,
  p_progreso integer DEFAULT NULL,
  p_observacion text DEFAULT NULL
)
RETURNS TABLE (
  ok boolean,
  modulo_tesis_id uuid,
  estado varchar,
  progreso integer,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'AT', 'public'
AS $$
BEGIN
  UPDATE "AT".modulos_tesis mt
  SET estado = p_estado,
      progreso = COALESCE(p_progreso, mt.progreso),
      observacion = COALESCE(p_observacion, mt.observacion),
      actualizado_en = now()
  WHERE mt.id = p_modulo_tesis_id
    AND EXISTS (
      SELECT 1
      FROM "AT".tesis t
      WHERE t.id = mt.tesis_id
        AND t.estudiante_id = p_usuario_id
        AND t.eliminado_en IS NULL
    );

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, p_modulo_tesis_id, NULL::varchar, NULL::integer, 'Módulo no encontrado o sin permiso'::text;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT true, mt.id, mt.estado, mt.progreso, 'Módulo actualizado correctamente'::text
  FROM "AT".modulos_tesis mt
  WHERE mt.id = p_modulo_tesis_id;
END;
$$;
