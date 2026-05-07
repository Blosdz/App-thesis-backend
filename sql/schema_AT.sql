--
-- PostgreSQL database dump
--

\restrict X8cd7gZ7Qvpp2sdg9v74dGE01BS8H5wPebSj0yormQzXvn59guffjHYjksyTMiz

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9 (Ubuntu 17.9-1.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: AT; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "AT";


--
-- Name: actualizar_estado_sugerencia_asesor(uuid, boolean); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".actualizar_estado_sugerencia_asesor(p_sugerencia_id uuid, p_aplicado boolean) RETURNS TABLE(ok boolean, sugerencia_id uuid, aplicado boolean, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_tesis_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  select h.tesis_id
    into v_tesis_id
  from "AT".historial_sugerencias_asesor h
  where h.id = p_sugerencia_id
    and h.asesor_id = v_asesor_id
  limit 1;

  if v_tesis_id is null then
    raise exception 'No se encontró la sugerencia o no tienes permiso sobre ella';
  end if;

  if not exists (
    select 1
    from "AT".asesores_tesis atx
    where atx.tesis_id = v_tesis_id
      and atx.asesor_id = v_asesor_id
      and coalesce(atx.activo, true) = true
  ) then
    raise exception 'No tienes acceso a esta tesis';
  end if;

  update "AT".historial_sugerencias_asesor
  set
    aplicado = p_aplicado,
    actualizado_en = now()
  where id = p_sugerencia_id
    and asesor_id = v_asesor_id;

  return query
  select
    true,
    p_sugerencia_id,
    p_aplicado,
    case
      when p_aplicado then 'Sugerencia marcada como aplicada'
      else 'Sugerencia marcada como no aplicada'
    end::text;
end;
$$;


--
-- Name: actualizar_fecha_modificacion(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".actualizar_fecha_modificacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.actualizado_en = now();
  RETURN NEW;
END;
$$;


--
-- Name: admin_listar_pagos(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".admin_listar_pagos() RETURNS TABLE(pago_id uuid, pagador_id uuid, pagador_nombre text, pagador_rol character varying, asesor_id uuid, asesor_nombre character varying, concepto character varying, monto numeric, estado character varying, codigo_operacion character varying, documento_drive_id text, url_archivo_drive text, nombre_archivo_voucher text, tipo_mime_voucher character varying, tamano_bytes_voucher bigint, subido_en timestamp with time zone, verificado_por uuid, verificado_por_nombre text, verificado_en timestamp with time zone, nota_verificacion text, metadata jsonb, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
declare
  v_auth_user_id uuid;
  v_admin_id uuid;
  v_rol varchar;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
  into v_admin_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  limit 1;

  if v_admin_id is null then
    raise exception 'Usuario no válido';
  end if;

  if v_rol not in ('admin', 'coordinador') then
    raise exception 'No autorizado';
  end if;

  return query
  select
    p.id as pago_id,
    p.pagador_id,
    case
      when up.rol = 'estudiante' then trim(coalesce(pe.nombres, '') || ' ' || coalesce(pe.apellidos, ''))
      when up.rol = 'asesor' then coalesce(ppa_pagador.nombre_mostrar, 'Asesor')
      else 'Usuario'
    end as pagador_nombre,
    up.rol as pagador_rol,
    pa.asesor_id,
    ppa_asesor.nombre_mostrar as asesor_nombre,
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
    p.verificado_por,
    case
      when uv.rol = 'estudiante' then trim(coalesce(pev.nombres, '') || ' ' || coalesce(pev.apellidos, ''))
      when uv.rol = 'asesor' then coalesce(ppa_verificador.nombre_mostrar, 'Asesor')
      when uv.rol = 'admin' then 'Admin'
      else null
    end as verificado_por_nombre,
    p.verificado_en,
    p.nota_verificacion,
    p.metadata,
    p.creado_en,
    p.actualizado_en
  from "AT".pagos p
  left join "AT".usuarios up
    on up.id = p.pagador_id
  left join "AT".perfil_estudiante pe
    on pe.estudiante_id = p.pagador_id
  left join "AT".perfil_publico_asesor ppa_pagador
    on ppa_pagador.asesor_id = p.pagador_id
  left join "AT".pagos_asesor pa
    on pa.pago_id = p.id
  left join "AT".perfil_publico_asesor ppa_asesor
    on ppa_asesor.asesor_id = pa.asesor_id
  left join "AT".usuarios uv
    on uv.id = p.verificado_por
  left join "AT".perfil_estudiante pev
    on pev.estudiante_id = p.verificado_por
  left join "AT".perfil_publico_asesor ppa_verificador
    on ppa_verificador.asesor_id = p.verificado_por
  order by p.creado_en desc;
end;
$$;


--
-- Name: admin_listar_usuarios(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".admin_listar_usuarios() RETURNS TABLE(usuario_id uuid, auth_usuario_id uuid, rol character varying, verificado boolean, estudiante_nombres character varying, estudiante_apellidos character varying, estudiante_carrera character varying, asesor_nombre_mostrar character varying, asesor_email_publico character varying, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
declare
  v_auth_user_id uuid;
  v_admin_id uuid;
  v_rol varchar;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
  into v_admin_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  limit 1;

  if v_admin_id is null then
    raise exception 'Usuario no válido';
  end if;

  if v_rol not in ('admin', 'coordinador') then
    raise exception 'No autorizado';
  end if;

  return query
  select
    u.id,
    u.auth_usuario_id,
    u.rol,
    coalesce(u.verificado, false),
    pe.nombres,
    pe.apellidos,
    pe.carrera,
    ppa.nombre_mostrar,
    ppa.email_publico,
    u.creado_en,
    u.actualizado_en
  from "AT".usuarios u
  left join "AT".perfil_estudiante pe
    on pe.estudiante_id = u.id
  left join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = u.id
  order by u.creado_en desc;
end;
$$;


--
-- Name: admin_obtener_pago(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".admin_obtener_pago(p_pago_id uuid) RETURNS TABLE(pago_id uuid, pagador_id uuid, pagador_nombre text, pagador_rol character varying, asesor_id uuid, asesor_nombre character varying, concepto character varying, monto numeric, estado character varying, codigo_operacion character varying, metadata jsonb, documento_drive_id text, url_archivo_drive text, nombre_archivo_voucher text, tipo_mime_voucher character varying, tamano_bytes_voucher bigint, subido_en timestamp with time zone, verificado_por uuid, verificado_en timestamp with time zone, nota_verificacion text, creado_en timestamp with time zone, actualizado_en timestamp with time zone, reunion_id uuid, reunion_estado character varying, reunion_inicio timestamp with time zone, reunion_fin timestamp with time zone, enlace_reunion text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
declare
  v_auth_user_id uuid;
  v_admin_id uuid;
  v_rol varchar;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
  into v_admin_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  limit 1;

  if v_admin_id is null then
    raise exception 'Usuario no válido';
  end if;

  if v_rol not in ('admin', 'coordinador') then
    raise exception 'No autorizado';
  end if;

  return query
  select
    p.id as pago_id,
    p.pagador_id,
    case
      when up.rol = 'estudiante' then trim(coalesce(pe.nombres, '') || ' ' || coalesce(pe.apellidos, ''))
      when up.rol = 'asesor' then coalesce(ppa_pagador.nombre_mostrar, 'Asesor')
      else 'Usuario'
    end as pagador_nombre,
    up.rol as pagador_rol,
    pa.asesor_id,
    ppa_asesor.nombre_mostrar as asesor_nombre,
    p.concepto,
    p.monto,
    p.estado,
    p.codigo_operacion,
    p.metadata,
    p.documento_drive_id,
    p.url_archivo_drive,
    p.nombre_archivo_voucher,
    p.tipo_mime_voucher,
    p.tamano_bytes_voucher,
    p.subido_en,
    p.verificado_por,
    p.verificado_en,
    p.nota_verificacion,
    p.creado_en,
    p.actualizado_en,
    ra.id as reunion_id,
    ra.estado as reunion_estado,
    ra.inicio as reunion_inicio,
    ra.fin as reunion_fin,
    ra.enlace_reunion
  from "AT".pagos p
  left join "AT".usuarios up
    on up.id = p.pagador_id
  left join "AT".perfil_estudiante pe
    on pe.estudiante_id = p.pagador_id
  left join "AT".perfil_publico_asesor ppa_pagador
    on ppa_pagador.asesor_id = p.pagador_id
  left join "AT".pagos_asesor pa
    on pa.pago_id = p.id
  left join "AT".perfil_publico_asesor ppa_asesor
    on ppa_asesor.asesor_id = pa.asesor_id
  left join "AT".reuniones_asesor ra
    on ra.pago_id = p.id
  where p.id = p_pago_id
  order by ra.creado_en desc nulls last
  limit 1;
end;
$$;


--
-- Name: admin_verificar_pago(uuid, character varying, text, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".admin_verificar_pago(p_pago_id uuid, p_estado character varying, p_nota_verificacion text DEFAULT NULL::text, p_enlace_reunion text DEFAULT NULL::text) RETURNS TABLE(ok boolean, pago_id uuid, estado character varying, verificado_por uuid, verificado_en timestamp with time zone, mensaje text, reunion_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
declare
  v_auth_user_id uuid;
  v_admin_id uuid;
  v_rol varchar;
  v_verificado_en timestamptz;
  v_pago record;
  v_validation record;
  v_meeting_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
  into v_admin_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  limit 1;

  if v_admin_id is null then
    raise exception 'Usuario no válido';
  end if;

  if v_rol not in ('admin', 'coordinador') then
    raise exception 'No autorizado';
  end if;

  if p_estado not in ('validado', 'rechazado') then
    raise exception 'Estado de pago no válido. Usa validado o rechazado';
  end if;

  select *
  into v_pago
  from "AT".pagos p
  where p.id = p_pago_id
  for update;

  if v_pago.id is null then
    raise exception 'No se encontró el pago';
  end if;

  v_verificado_en := now();

  update "AT".pagos
  set
    estado = p_estado,
    verificado_por = v_admin_id,
    verificado_en = v_verificado_en,
    nota_verificacion = p_nota_verificacion,
    actualizado_en = v_verificado_en
  where id = p_pago_id;

  if p_estado = 'rechazado' then
    update "AT".validation_cita
    set
      status = 'rejected',
      updated_at = now()
    where id = (v_pago.metadata->>'validation_cita_id')::uuid;

    return query
    select
      true,
      p_pago_id,
      p_estado,
      v_admin_id,
      v_verificado_en,
      'Pago rechazado'::text,
      null::uuid;

    return;
  end if;

  select *
  into v_validation
  from "AT".validation_cita vc
  where vc.id = (v_pago.metadata->>'validation_cita_id')::uuid
  for update;

  if v_validation.id is null then
    raise exception 'No se encontró la validación de cita asociada';
  end if;

  select ra.id
  into v_meeting_id
  from "AT".reuniones_asesor ra
  where ra.pago_id = p_pago_id
  order by ra.creado_en desc
  limit 1;

  if v_meeting_id is null then
    insert into "AT".reuniones_asesor (
      disponibilidad_id,
      asesor_id,
      estudiante_id,
      tesis_id,
      tarifa_id,
      estado,
      pago_id,
      motivo,
      notas,
      modalidad,
      lugar,
      enlace_reunion,
      inicio,
      fin,
      duracion_minutos,
      costo_reunion,
      moneda,
      creado_en,
      actualizado_en
    )
    values (
      v_validation.disponibilidad_id,
      v_validation.advisor_id,
      v_validation.user_id,
      v_validation.tesis_id,
      null,
      'confirmado',
      p_pago_id,
      v_validation.motivo,
      v_validation.notas,
      v_validation.modalidad,
      v_validation.lugar,
      coalesce(p_enlace_reunion, v_validation.enlace_reunion),
      v_validation.start_at,
      v_validation.end_at,
      v_validation.duration_minutes,
      coalesce(v_pago.monto, 0),
      'PEN',
      now(),
      now()
    )
    returning id into v_meeting_id;
  else
    update "AT".reuniones_asesor
    set
      enlace_reunion = coalesce(p_enlace_reunion, enlace_reunion),
      actualizado_en = now()
    where id = v_meeting_id;
  end if;

  update "AT".validation_cita
  set
    status = 'confirmed',
    payment_id = p_pago_id,
    meeting_id = v_meeting_id,
    enlace_reunion = coalesce(p_enlace_reunion, enlace_reunion),
    updated_at = now()
  where id = v_validation.id;

  return query
  select
    true,
    p_pago_id,
    p_estado,
    v_admin_id,
    v_verificado_en,
    'Pago validado y reunión creada correctamente'::text,
    v_meeting_id;
end;
$$;


--
-- Name: admin_verificar_pago_plan(uuid, character varying, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".admin_verificar_pago_plan(p_pago_id uuid, p_estado character varying, p_nota_verificacion text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'at', 'public'
    AS $$
declare
  v_pago record;
  v_pago_plan record;
  v_plan record;
  v_suscripcion record;
  v_admin_usuario_id uuid;
  v_inicio timestamptz;
  v_fin timestamptz;
  v_asesorias_incluidas integer := 0;
  v_presustentaciones_incluidas integer := 0;
begin
  if p_estado not in ('validado', 'rechazado') then
    raise exception 'Estado no válido. Use validado o rechazado';
  end if;

  select u.id
    into v_admin_usuario_id
  from "AT".usuarios u
  where u.auth_usuario_id = auth.uid()
    and u.rol = 'admin'
  limit 1;

  if v_admin_usuario_id is null then
    raise exception 'No autorizado';
  end if;

  select p.*
    into v_pago
  from "AT".pagos p
  where p.id = p_pago_id
  limit 1;

  if v_pago.id is null then
    raise exception 'No existe el pago indicado';
  end if;

  if v_pago.estado in ('validado', 'rechazado') then
    raise exception 'Este pago ya fue procesado previamente';
  end if;

  select pp.*
    into v_pago_plan
  from "AT".pagos_plan pp
  where pp.pago_id = p_pago_id
  limit 1;

  if v_pago_plan.id is null then
    raise exception 'El pago no está vinculado a un plan';
  end if;

  select pl.*
    into v_plan
  from "AT".planes pl
  where pl.id = v_pago_plan.plan_id
    and coalesce(pl.activo, true) = true
  limit 1;

  if v_plan.id is null then
    raise exception 'El plan asociado no existe o está inactivo';
  end if;

  v_asesorias_incluidas :=
    coalesce((v_plan.caracteristicas->>'asesorias_incluidas')::integer, 0);

  v_presustentaciones_incluidas :=
    coalesce((v_plan.caracteristicas->>'presustentaciones_incluidas')::integer, 0);

  update "AT".pagos
     set estado = p_estado,
         verificado_por = v_admin_usuario_id,
         verificado_en = now(),
         nota_verificacion = p_nota_verificacion,
         actualizado_en = now()
   where id = p_pago_id;

  if p_estado = 'rechazado' then
    return jsonb_build_object(
      'ok', true,
      'accion', 'pago_rechazado',
      'pago_id', p_pago_id
    );
  end if;

  select s.*
    into v_suscripcion
  from "AT".suscripciones_estudiante s
  where s.estudiante_id = v_pago.pagador_id
    and s.plan_id = v_pago_plan.plan_id
  order by s.creado_en desc
  limit 1;

  if v_suscripcion.id is not null
     and v_suscripcion.expira_en is not null
     and v_suscripcion.expira_en > now() then
    v_inicio := v_suscripcion.expira_en;
  else
    v_inicio := now();
  end if;

  v_fin := v_inicio + make_interval(days => v_plan.duracion_dias);

  if v_suscripcion.id is null then
    insert into "AT".suscripciones_estudiante (
      estudiante_id,
      plan_id,
      estado,
      iniciado_en,
      expira_en,
      asesorias_incluidas,
      asesorias_usadas,
      presustentaciones_incluidas,
      presustentaciones_usadas,
      creado_en,
      actualizado_en
    )
    values (
      v_pago.pagador_id,
      v_pago_plan.plan_id,
      'activo',
      now(),
      v_fin,
      v_asesorias_incluidas,
      0,
      v_presustentaciones_incluidas,
      0,
      now(),
      now()
    );
  else
    update "AT".suscripciones_estudiante
       set estado = 'activo',
           expira_en = v_fin,
           asesorias_incluidas = coalesce(asesorias_incluidas, 0) + v_asesorias_incluidas,
           presustentaciones_incluidas = coalesce(presustentaciones_incluidas, 0) + v_presustentaciones_incluidas,
           actualizado_en = now()
     where id = v_suscripcion.id;
  end if;

  insert into "AT".actividad_log (
    usuario_id,
    accion,
    tabla_afectada,
    registro_id,
    metadata
  )
  values (
    v_admin_usuario_id,
    'verificacion_pago_plan',
    'pagos',
    p_pago_id,
    jsonb_build_object(
      'pago_id', p_pago_id,
      'plan_id', v_pago_plan.plan_id,
      'plan_nombre', v_plan.nombre,
      'duracion_dias', v_plan.duracion_dias,
      'asesorias_incluidas', v_asesorias_incluidas,
      'presustentaciones_incluidas', v_presustentaciones_incluidas,
      'expira_en', v_fin,
      'pagador_id', v_pago.pagador_id
    )
  );

  return jsonb_build_object(
    'ok', true,
    'accion', 'pago_validado',
    'pago_id', p_pago_id,
    'plan_id', v_pago_plan.plan_id,
    'plan_nombre', v_plan.nombre,
    'duracion_dias', v_plan.duracion_dias,
    'asesorias_incluidas', v_asesorias_incluidas,
    'presustentaciones_incluidas', v_presustentaciones_incluidas,
    'expira_en', v_fin
  );
end;
$$;


--
-- Name: aprobar_pago_reserva_cita(uuid, text, text, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".aprobar_pago_reserva_cita(p_validation_cita_id uuid, p_enlace_reunion text DEFAULT NULL::text, p_lugar text DEFAULT NULL::text, p_notas text DEFAULT NULL::text) RETURNS TABLE(ok boolean, reunion_id uuid, pago_id uuid, estado character varying, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_reserva record;
  v_reunion_id uuid;
begin
  select *
  into v_reserva
  from "AT".validation_cita vc
  where vc.id = p_validation_cita_id
  for update;

  if v_reserva.id is null then
    raise exception 'No se encontró la reserva';
  end if;

  if v_reserva.status <> 'payment_pending' then
    raise exception 'La reserva no está pendiente de pago';
  end if;

  update "AT".pagos
  set estado = 'aprobado',
      actualizado_en = now()
  where id = v_reserva.payment_id;

  insert into "AT".reuniones_asesor (
    disponibilidad_id,
    asesor_id,
    estudiante_id,
    tesis_id,
    tarifa_id,
    estado,
    pago_id,
    motivo,
    notas,
    modalidad,
    lugar,
    enlace_reunion,
    inicio,
    fin,
    duracion_minutos,
    costo_reunion,
    moneda,
    creado_en,
    actualizado_en
  )
  values (
    v_reserva.disponibilidad_id,
    v_reserva.advisor_id,
    v_reserva.user_id,
    v_reserva.tesis_id,
    null,
    'confirmado',
    v_reserva.payment_id,
    v_reserva.motivo,
    coalesce(p_notas, v_reserva.notas),
    v_reserva.modalidad,
    coalesce(p_lugar, v_reserva.lugar),
    coalesce(p_enlace_reunion, v_reserva.enlace_reunion),
    v_reserva.start_at,
    v_reserva.end_at,
    v_reserva.duration_minutes,
    100,
    'PEN',
    now(),
    now()
  )
  returning id into v_reunion_id;

  update "AT".validation_cita
  set status = 'confirmed',
      meeting_id = v_reunion_id,
      updated_at = now()
  where id = v_reserva.id;

  insert into "AT".notifications (
    user_id, title, message, type, status, related_id, created_at
  )
  values (
    v_reserva.user_id,
    'Cita confirmada',
    'Tu pago fue validado y tu cita ya está confirmada',
    'cita_confirmada',
    'unread',
    v_reunion_id,
    now()
  );

  return query
  select true, v_reunion_id, v_reserva.payment_id, 'confirmed'::varchar, 'Pago aprobado y reunión creada'::text;
end;
$$;


--
-- Name: asignar_mi_tesis_a_asesor(uuid, uuid, character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".asignar_mi_tesis_a_asesor(p_tesis_id uuid, p_asesor_id uuid, p_rol character varying DEFAULT 'principal'::character varying) RETURNS TABLE(ok boolean, asesoria_tesis_id uuid, tesis_id uuid, asesor_id uuid, relacion_id uuid, rol character varying, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_relacion_id uuid;
  v_asignacion_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  -- validar que la tesis pertenece al estudiante
  if not exists (
    select 1
    from "AT".tesis t
    where t.id = p_tesis_id
      and t.estudiante_id = v_estudiante_id
      and t.eliminado_en is null
  ) then
    raise exception 'La tesis no pertenece al estudiante autenticado';
  end if;

  -- validar relación activa con el asesor
  select r.id
    into v_relacion_id
  from "AT".relaciones_asesor_estudiante r
  where r.estudiante_id = v_estudiante_id
    and r.asesor_id = p_asesor_id
    and r.estado = 'activo'
  limit 1;

  if v_relacion_id is null then
    raise exception 'No tienes una relación activa con este asesor';
  end if;

  -- evitar duplicado activo
  select at.id
    into v_asignacion_id
  from "AT".asesores_tesis at
  where at.tesis_id = p_tesis_id
    and at.asesor_id = p_asesor_id
    and coalesce(at.activo, true) = true
  limit 1;

  if v_asignacion_id is not null then
    return query
    select
      true,
      v_asignacion_id,
      p_tesis_id,
      p_asesor_id,
      v_relacion_id,
      p_rol,
      'La tesis ya está asignada a este asesor'::text;
    return;
  end if;

  insert into "AT".asesores_tesis (
    asesor_id,
    tesis_id,
    activo,
    rol,
    creado_en,
    relacion_id
  )
  values (
    p_asesor_id,
    p_tesis_id,
    true,
    p_rol,
    now(),
    v_relacion_id
  )
  returning id into v_asignacion_id;

  return query
  select
    true,
    v_asignacion_id,
    p_tesis_id,
    p_asesor_id,
    v_relacion_id,
    p_rol,
    'Tesis asignada correctamente al asesor'::text;
end;
$$;


--
-- Name: asignar_tesis_asesor(uuid, uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".asignar_tesis_asesor(p_relacion_id uuid, p_tesis_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
relacion_record record;
begin

select *
into relacion_record
from "AT".relaciones_asesor_estudiante
where id = p_relacion_id
and estudiante_id = "AT".usuario_id()
and estado = 'activo';

if not found then
raise exception 'No autorizado';
end if;

insert into "AT".asesores_tesis(
relacion_id,
asesor_id,
tesis_id,
rol
)
values(
p_relacion_id,
relacion_record.asesor_id,
p_tesis_id,
'principal'
);

end;
$$;


--
-- Name: cambiar_estado_relacion(uuid, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".cambiar_estado_relacion(p_relacion_id uuid, p_estado text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
estado_actual text;
begin

select estado
into estado_actual
from "AT".relaciones_asesor_estudiante
where id = p_relacion_id
and asesor_id = usuario_id();

if not found then
raise exception 'No autorizado';
end if;

if estado_actual != 'pendiente' then
raise exception 'Solo relaciones pendientes pueden modificarse';
end if;

update "AT".relaciones_asesor_estudiante
set estado = p_estado,
actualizado_en = now()
where id = p_relacion_id;

end;
$$;


--
-- Name: cancelar_cita_estudiante(uuid, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".cancelar_cita_estudiante(p_reunion_id uuid, p_motivo text DEFAULT NULL::text) RETURNS TABLE(ok boolean, reunion_id uuid, estado_reunion character varying, pago_id uuid, estado_pago character varying, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_pago_id uuid;
  v_estado_pago varchar;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
  into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  update "AT".reuniones_asesor
  set
    estado = 'cancelado',
    notas = coalesce(notas, '') || case when p_motivo is not null then E'\nCancelación: ' || p_motivo else '' end,
    actualizado_en = now()
  where id = p_reunion_id
    and estudiante_id = v_estudiante_id
    and estado in ('pendiente', 'confirmado')
  returning pago_id into v_pago_id;

  if v_pago_id is null then
    raise exception 'No se pudo cancelar la cita';
  end if;

  update "AT".pagos
  set
    actualizado_en = now()
  where id = v_pago_id
  returning estado into v_estado_pago;

  return query
  select
    true,
    p_reunion_id,
    'cancelado'::varchar,
    v_pago_id,
    v_estado_pago,
    'Cita cancelada correctamente'::text;
end;
$$;


--
-- Name: consumir_beneficio_suscripcion(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".consumir_beneficio_suscripcion(p_beneficio_consumo_id uuid) RETURNS TABLE(beneficio_consumo_id uuid, cantidad_total integer, cantidad_usada integer, cantidad_disponible integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_row record;
begin
  update "AT"."suscripcion_beneficios_consumo"
  set
    "cantidad_usada" = "cantidad_usada" + 1,
    "actualizado_en" = now()
  where "id" = p_beneficio_consumo_id
    and ("cantidad_total" - "cantidad_usada") > 0
  returning *
  into v_row;

  if v_row."id" is null then
    raise exception 'No hay beneficios disponibles para consumir';
  end if;

  return query
  select
    v_row."id",
    v_row."cantidad_total",
    v_row."cantidad_usada",
    greatest(v_row."cantidad_total" - v_row."cantidad_usada", 0);
end;
$$;


--
-- Name: cotizar_tesis_plan(uuid, uuid, character varying, boolean); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".cotizar_tesis_plan(p_plan_id uuid, p_tipo_tesis_id uuid, p_nivel_academico character varying, p_requiere_analisis_estadistico boolean DEFAULT true) RETURNS TABLE(plan_id uuid, plan_nombre character varying, tipo_tesis_id uuid, tipo_tesis_codigo character varying, tipo_tesis_nombre character varying, nivel_academico character varying, precio_base numeric, porcentaje_nivel numeric, monto_ajuste_nivel numeric, descuento_analisis_estadistico numeric, precio_total numeric, moneda character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_plan_nombre varchar;
  v_tipo_tesis_codigo varchar;
  v_tipo_tesis_nombre varchar;
  v_precio_base numeric(10,2);
  v_moneda varchar := 'PEN';
  v_porcentaje_nivel numeric(5,2) := 0;
  v_monto_ajuste_nivel numeric(10,2) := 0;
  v_descuento_analisis numeric(10,2) := 0;
  v_precio_total numeric(10,2) := 0;
  v_nivel_normalizado varchar;
begin
  if p_plan_id is null then
    raise exception 'El plan es obligatorio';
  end if;

  if p_tipo_tesis_id is null then
    raise exception 'El tipo de tesis es obligatorio';
  end if;

  if p_nivel_academico is null or btrim(p_nivel_academico) = '' then
    raise exception 'El nivel académico es obligatorio';
  end if;

  v_nivel_normalizado := upper(trim(p_nivel_academico));

  if v_nivel_normalizado not in ('PREGRADO', 'MAESTRIA', 'ESPECIALIDAD', 'DOCTORADO') then
    raise exception 'Nivel académico inválido. Debe ser PREGRADO, MAESTRIA, ESPECIALIDAD o DOCTORADO';
  end if;

  select
    p."nombre",
    tt."codigo",
    tt."nombre",
    pt."precio_base",
    pt."moneda"
  into
    v_plan_nombre,
    v_tipo_tesis_codigo,
    v_tipo_tesis_nombre,
    v_precio_base,
    v_moneda
  from "AT"."planes_tipos_tesis_precios" pt
  inner join "AT"."planes" p
    on p."id" = pt."plan_id"
  inner join "AT"."tipos_tesis" tt
    on tt."id" = pt."tipo_tesis_id"
  where pt."plan_id" = p_plan_id
    and pt."tipo_tesis_id" = p_tipo_tesis_id
    and coalesce(pt."activo", true) = true
    and coalesce(p."activo", true) = true
    and coalesce(tt."activo", true) = true
  limit 1;

  if v_precio_base is null then
    raise exception 'No existe una configuración de precio para el plan y tipo de tesis enviados';
  end if;

  v_porcentaje_nivel := case
    when v_nivel_normalizado = 'PREGRADO' then 0
    when v_nivel_normalizado = 'MAESTRIA' then 15
    when v_nivel_normalizado = 'ESPECIALIDAD' then 15
    when v_nivel_normalizado = 'DOCTORADO' then 20
    else 0
  end;

  v_monto_ajuste_nivel := round((v_precio_base * v_porcentaje_nivel / 100.0)::numeric, 2);

  v_descuento_analisis := case
    when coalesce(p_requiere_analisis_estadistico, true) = false then 500
    else 0
  end;

  v_precio_total := greatest(v_precio_base + v_monto_ajuste_nivel - v_descuento_analisis, 0);

  return query
  select
    p_plan_id as "plan_id",
    v_plan_nombre as "plan_nombre",
    p_tipo_tesis_id as "tipo_tesis_id",
    v_tipo_tesis_codigo as "tipo_tesis_codigo",
    v_tipo_tesis_nombre as "tipo_tesis_nombre",
    v_nivel_normalizado as "nivel_academico",
    v_precio_base as "precio_base",
    v_porcentaje_nivel as "porcentaje_nivel",
    v_monto_ajuste_nivel as "monto_ajuste_nivel",
    v_descuento_analisis as "descuento_analisis_estadistico",
    v_precio_total as "precio_total",
    coalesce(v_moneda, 'PEN') as "moneda";
end;
$$;


--
-- Name: crear_asesoria_plan_o_pago(uuid, uuid, uuid, timestamp with time zone, timestamp with time zone, text, character varying, text, text, text, uuid, uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_asesoria_plan_o_pago(p_estudiante_id uuid, p_tesis_id uuid, p_disponibilidad_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text DEFAULT NULL::text, p_modalidad character varying DEFAULT NULL::character varying, p_lugar text DEFAULT NULL::text, p_enlace_reunion text DEFAULT NULL::text, p_notas text DEFAULT NULL::text, p_tarifa_id uuid DEFAULT NULL::uuid, p_asesor_id_alternativo uuid DEFAULT NULL::uuid) RETURNS TABLE(reunion_id uuid, asesor_id uuid, pago_id uuid, suscripcion_id uuid, beneficio_consumo_id uuid, cubierta_por_plan boolean, costo_reunion numeric, estado character varying, tipo_reunion character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_reunion_id uuid;
  v_pago_id uuid;
  v_asesor_id uuid := '4729085e-b781-40ba-a5a2-049e8d3ddd5d';
  v_suscripcion_id uuid;
  v_beneficio_consumo_id uuid;
  v_cubierta_por_plan boolean := false;
  v_costo_reunion numeric(10,2) := 0;
  v_estado varchar := 'pendiente';
  v_tarifa_precio numeric(10,2);
begin
  if p_estudiante_id is null then
    raise exception 'El estudiante es obligatorio';
  end if;

  if p_inicio is null or p_fin is null or p_fin <= p_inicio then
    raise exception 'Rango horario inválido';
  end if;

  select
    x."suscripcion_id",
    x."beneficio_consumo_id"
  into
    v_suscripcion_id,
    v_beneficio_consumo_id
  from "AT"."obtener_beneficio_disponible_estudiante"(
    p_estudiante_id,
    'asesorias_gratis'
  ) x
  limit 1;

  if v_beneficio_consumo_id is not null then
    v_cubierta_por_plan := true;
    v_costo_reunion := 0;
    v_estado := 'confirmada';

    perform *
    from "AT"."consumir_beneficio_suscripcion"(v_beneficio_consumo_id);

  else
    v_cubierta_por_plan := false;
    v_asesor_id := coalesce(p_asesor_id_alternativo, v_asesor_id);

    if p_tarifa_id is null then
      raise exception 'No hay asesorías incluidas disponibles; se requiere tarifa para crear el pago';
    end if;

    select t."precio"
    into v_tarifa_precio
    from "AT"."tarifas_asesor" t
    where t."id" = p_tarifa_id
      and coalesce(t."activo", true) = true
    limit 1;

    if v_tarifa_precio is null then
      raise exception 'No se encontró la tarifa de asesoría';
    end if;

    v_costo_reunion := v_tarifa_precio;

    insert into "AT"."pagos" (
      "pagador_id",
      "concepto",
      "monto",
      "estado",
      "metadata"
    )
    values (
      p_estudiante_id,
      'Pago por asesoría',
      v_costo_reunion,
      'pendiente',
      jsonb_build_object(
        'tipo_pago', 'asesoria',
        'tesis_id', p_tesis_id,
        'asesor_id', v_asesor_id,
        'tarifa_id', p_tarifa_id
      )
    )
    returning "id" into v_pago_id;

    v_estado := 'pendiente_pago';
  end if;

  insert into "AT"."reuniones_asesor" (
    "disponibilidad_id",
    "asesor_id",
    "estudiante_id",
    "tesis_id",
    "tarifa_id",
    "estado",
    "pago_id",
    "motivo",
    "notas",
    "modalidad",
    "lugar",
    "enlace_reunion",
    "inicio",
    "fin",
    "duracion_minutos",
    "costo_reunion",
    "moneda",
    "suscripcion_id",
    "beneficio_consumo_id",
    "cubierta_por_plan",
    "tipo_reunion"
  )
  values (
    p_disponibilidad_id,
    v_asesor_id,
    p_estudiante_id,
    p_tesis_id,
    p_tarifa_id,
    v_estado,
    v_pago_id,
    p_motivo,
    p_notas,
    p_modalidad,
    p_lugar,
    p_enlace_reunion,
    p_inicio,
    p_fin,
    greatest((extract(epoch from (p_fin - p_inicio)) / 60)::integer, 1),
    v_costo_reunion,
    'PEN',
    v_suscripcion_id,
    v_beneficio_consumo_id,
    v_cubierta_por_plan,
    'asesoria'
  )
  returning "id" into v_reunion_id;

  return query
  select
    v_reunion_id,
    v_asesor_id,
    v_pago_id,
    v_suscripcion_id,
    v_beneficio_consumo_id,
    v_cubierta_por_plan,
    v_costo_reunion,
    v_estado,
    'asesoria'::varchar;
end;
$$;


--
-- Name: crear_cita_asesor_estudiante(uuid, uuid, timestamp with time zone, timestamp with time zone, uuid, text, text, character varying, text, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_cita_asesor_estudiante(p_estudiante_id uuid, p_disponibilidad_id uuid, p_bloque_inicio timestamp with time zone, p_bloque_fin timestamp with time zone, p_tesis_id uuid DEFAULT NULL::uuid, p_motivo text DEFAULT NULL::text, p_notas text DEFAULT NULL::text, p_modalidad character varying DEFAULT 'virtual'::character varying, p_lugar text DEFAULT NULL::text, p_enlace_reunion text DEFAULT NULL::text) RETURNS TABLE(r_ok boolean, r_reunion_id uuid, r_asesor_id uuid, r_estudiante_id uuid, r_inicio timestamp with time zone, r_fin timestamp with time zone, r_estado character varying, r_pago_id uuid, r_costo_reunion numeric, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_reunion_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  if not exists (
    select 1
    from "AT".relaciones_asesor_estudiante r
    where r.asesor_id = v_asesor_id
      and r.estudiante_id = p_estudiante_id
      and r.estado in ('activo','pendiente')
  ) then
    raise exception 'El estudiante no está vinculado con este asesor';
  end if;

  if exists (
    select 1
    from "AT".reuniones_asesor r
    where r.asesor_id = v_asesor_id
      and r.estado in ('pendiente','confirmado','completado')
      and p_bloque_inicio < r.fin
      and p_bloque_fin > r.inicio
  ) then
    raise exception 'Ese bloque ya fue reservado';
  end if;

  insert into "AT".reuniones_asesor (
    disponibilidad_id,
    asesor_id,
    estudiante_id,
    tesis_id,
    tarifa_id,
    estado,
    pago_id,
    motivo,
    notas,
    modalidad,
    lugar,
    enlace_reunion,
    inicio,
    fin,
    duracion_minutos,
    costo_reunion,
    moneda,
    creado_en,
    actualizado_en
  )
  values (
    p_disponibilidad_id,
    v_asesor_id,
    p_estudiante_id,
    p_tesis_id,
    null,
    'pendiente',
    null,
    p_motivo,
    p_notas,
    p_modalidad,
    p_lugar,
    p_enlace_reunion,
    p_bloque_inicio,
    p_bloque_fin,
    1,
    0,
    'PEN',
    now(),
    now()
  )
  returning id into v_reunion_id;

  return query
  select
    true,
    v_reunion_id,
    v_asesor_id,
    p_estudiante_id,
    p_bloque_inicio,
    p_bloque_fin,
    'pendiente'::varchar,
    (select r.pago_id from "AT".reuniones_asesor r where r.id = v_reunion_id),
    200::numeric,
    'Cita creada correctamente por el asesor'::text;
end;
$$;


--
-- Name: crear_cita_asesoria(uuid, uuid, timestamp with time zone, timestamp with time zone, uuid, text, character varying, text, text, text, character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_cita_asesoria(p_asesor_id uuid, p_disponibilidad_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_tesis_id uuid DEFAULT NULL::uuid, p_motivo text DEFAULT NULL::text, p_modalidad character varying DEFAULT NULL::character varying, p_lugar text DEFAULT NULL::text, p_enlace_reunion text DEFAULT NULL::text, p_notas text DEFAULT NULL::text, p_tipo_servicio character varying DEFAULT 'asesoria'::character varying) RETURNS TABLE(ok boolean, validation_cita_id uuid, estado character varying, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_relacion_id uuid;
  v_disp record;
  v_validation_id uuid;
  v_duracion_minutos integer;
  v_solapa boolean;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
  into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  select r.id
  into v_relacion_id
  from "AT".relaciones_asesor_estudiante r
  where r.asesor_id = p_asesor_id
    and r.estudiante_id = v_estudiante_id
    and r.estado = 'activo'
  limit 1;

  if v_relacion_id is null then
    raise exception 'No tienes una relación activa con este asesor';
  end if;

  if p_fin <= p_inicio then
    raise exception 'La fecha fin debe ser mayor que la fecha inicio';
  end if;

  select
    d.id,
    d.asesor_id,
    d.inicio,
    d.fin,
    d.usa_bloques,
    d.duracion_bloque_minutos,
    d.disponible,
    d.activo,
    d.recurrente,
    d.dia_semana,
    d.fecha_inicio,
    d.fecha_fin
  into v_disp
  from "AT".disponibilidad_asesor d
  where d.id = p_disponibilidad_id
    and d.asesor_id = p_asesor_id
  for update;

  if v_disp.id is null then
    raise exception 'No se encontró la disponibilidad del asesor';
  end if;

  if coalesce(v_disp.activo, false) = false then
    raise exception 'La disponibilidad no está activa';
  end if;

  if coalesce(v_disp.disponible, false) = false then
    raise exception 'La disponibilidad no está disponible';
  end if;

  if coalesce(v_disp.recurrente, false) = false then
    if p_inicio < v_disp.inicio or p_fin > v_disp.fin then
      raise exception 'La cita está fuera del rango de disponibilidad';
    end if;
  else
    if v_disp.fecha_inicio is null or v_disp.fecha_fin is null or v_disp.dia_semana is null then
      raise exception 'La disponibilidad recurrente está incompleta';
    end if;

    if (p_inicio at time zone 'America/Lima')::date < v_disp.fecha_inicio
       or (p_inicio at time zone 'America/Lima')::date > v_disp.fecha_fin then
      raise exception 'La cita está fuera del rango de fechas permitidas';
    end if;

    if extract(dow from (p_inicio at time zone 'America/Lima'))::int <> v_disp.dia_semana then
      raise exception 'La cita no corresponde al día permitido de la disponibilidad';
    end if;

    if (p_fin at time zone 'America/Lima')::date <> (p_inicio at time zone 'America/Lima')::date then
      raise exception 'La cita recurrente debe iniciar y terminar el mismo día';
    end if;

    if (p_inicio at time zone 'America/Lima')::time < (v_disp.inicio at time zone 'America/Lima')::time
       or (p_fin at time zone 'America/Lima')::time > (v_disp.fin at time zone 'America/Lima')::time then
      raise exception 'La cita está fuera del rango horario de disponibilidad';
    end if;
  end if;

  v_duracion_minutos := floor(extract(epoch from (p_fin - p_inicio)) / 60);

  if v_duracion_minutos <= 0 then
    raise exception 'La duración de la cita debe ser mayor a 0 minutos';
  end if;

  if coalesce(v_disp.usa_bloques, false) = true then
    if mod(v_duracion_minutos, v_disp.duracion_bloque_minutos) <> 0 then
      raise exception 'La duración no coincide con los bloques permitidos';
    end if;

    if coalesce(v_disp.recurrente, false) = false then
      if mod(
        floor(extract(epoch from (p_inicio - v_disp.inicio)) / 60)::integer,
        v_disp.duracion_bloque_minutos
      ) <> 0 then
        raise exception 'La hora de inicio no coincide con la grilla de bloques';
      end if;
    else
      if mod(
        (
          extract(hour from (p_inicio at time zone 'America/Lima')::time)::int * 60 +
          extract(minute from (p_inicio at time zone 'America/Lima')::time)::int
        ) -
        (
          extract(hour from (v_disp.inicio at time zone 'America/Lima')::time)::int * 60 +
          extract(minute from (v_disp.inicio at time zone 'America/Lima')::time)::int
        ),
        v_disp.duracion_bloque_minutos
      ) <> 0 then
        raise exception 'La hora de inicio no coincide con la grilla de bloques';
      end if;
    end if;
  end if;

  select exists (
    select 1
    from "AT".validation_cita vc
    where vc.advisor_id = p_asesor_id
      and vc.status in ('pending', 'payment_pending', 'paid', 'confirmed')
      and tstzrange(vc.start_at, vc.end_at, '[)') && tstzrange(p_inicio, p_fin, '[)')
  )
  into v_solapa;

  if v_solapa then
    raise exception 'Ya existe una solicitud o cita en ese bloque';
  end if;

  select exists (
    select 1
    from "AT".reuniones_asesor r
    where r.asesor_id = p_asesor_id
      and r.estado in ('pendiente', 'confirmado')
      and tstzrange(r.inicio, r.fin, '[)') && tstzrange(p_inicio, p_fin, '[)')
  )
  into v_solapa;

  if v_solapa then
    raise exception 'El bloque seleccionado ya no está libre';
  end if;

  insert into "AT".validation_cita (
    user_id,
    advisor_id,
    tesis_id,
    disponibilidad_id,
    status,
    reservation_date,
    start_at,
    end_at,
    duration_minutes,
    motivo,
    modalidad,
    lugar,
    enlace_reunion,
    notas,
    tipo_servicio,
    created_at,
    updated_at
  )
  values (
    v_estudiante_id,
    p_asesor_id,
    p_tesis_id,
    p_disponibilidad_id,
    'pending',
    (p_inicio at time zone 'America/Lima')::date,
    p_inicio,
    p_fin,
    v_duracion_minutos,
    p_motivo,
    p_modalidad,
    p_lugar,
    p_enlace_reunion,
    p_notas,
    coalesce(p_tipo_servicio, 'asesoria'),
    now(),
    now()
  )
  returning id into v_validation_id;

  insert into "AT".notifications (
    user_id,
    title,
    message,
    type,
    status,
    related_id,
    created_at
  )
  values (
    p_asesor_id,
    'Nueva solicitud de cita',
    'Un estudiante quiere reservar una cita contigo',
    'solicitud_cita',
    'unread',
    v_validation_id,
    now()
  );

  return query
  select
    true,
    v_validation_id,
    'pending'::varchar,
    'Solicitud de cita creada correctamente'::text;
end;
$$;


--
-- Name: crear_cita_estudiante_asesor(uuid, timestamp with time zone, timestamp with time zone, uuid, text, text, character varying, text, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_cita_estudiante_asesor(p_disponibilidad_id uuid, p_bloque_inicio timestamp with time zone, p_bloque_fin timestamp with time zone, p_tesis_id uuid DEFAULT NULL::uuid, p_motivo text DEFAULT NULL::text, p_notas text DEFAULT NULL::text, p_modalidad character varying DEFAULT 'virtual'::character varying, p_lugar text DEFAULT NULL::text, p_enlace_reunion text DEFAULT NULL::text) RETURNS TABLE(r_ok boolean, r_reunion_id uuid, r_asesor_id uuid, r_estudiante_id uuid, r_inicio timestamp with time zone, r_fin timestamp with time zone, r_estado character varying, r_pago_id uuid, r_costo_reunion numeric, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_asesor_id uuid;
  v_reunion_id uuid;
  v_pago_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  select d.asesor_id
    into v_asesor_id
  from "AT".disponibilidad_asesor d
  where d.id = p_disponibilidad_id
    and d.disponible = true
    and d.activo = true
  limit 1;

  if v_asesor_id is null then
    raise exception 'No se encontró una disponibilidad válida';
  end if;

  if exists (
    select 1
    from "AT".reuniones_asesor r
    where r.asesor_id = v_asesor_id
      and r.estado in ('pendiente','confirmado','completado')
      and p_bloque_inicio < r.fin
      and p_bloque_fin > r.inicio
  ) then
    raise exception 'Ese bloque ya fue reservado';
  end if;

  insert into "AT".reuniones_asesor (
    disponibilidad_id,
    asesor_id,
    estudiante_id,
    tesis_id,
    tarifa_id,
    estado,
    pago_id,
    motivo,
    notas,
    modalidad,
    lugar,
    enlace_reunion,
    inicio,
    fin,
    duracion_minutos,
    costo_reunion,
    moneda,
    creado_en,
    actualizado_en
  )
  values (
    p_disponibilidad_id,
    v_asesor_id,
    v_estudiante_id,
    p_tesis_id,
    null,
    'pendiente',
    null,
    p_motivo,
    p_notas,
    p_modalidad,
    p_lugar,
    p_enlace_reunion,
    p_bloque_inicio,
    p_bloque_fin,
    1,   -- luego el trigger lo recalcula
    0,   -- luego el trigger lo fija a 200
    'PEN',
    now(),
    now()
  )
  returning id, pago_id into v_reunion_id, v_pago_id;

  return query
  select
    true,
    v_reunion_id,
    v_asesor_id,
    v_estudiante_id,
    p_bloque_inicio,
    p_bloque_fin,
    'pendiente'::varchar,
    (select r.pago_id from "AT".reuniones_asesor r where r.id = v_reunion_id),
    200::numeric,
    'Cita creada correctamente'::text;
end;
$$;


--
-- Name: crear_espacio_libre_asesor(timestamp with time zone, timestamp with time zone, boolean, integer, boolean, integer[], date, date); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_espacio_libre_asesor(p_inicio timestamp with time zone, p_fin timestamp with time zone, p_usa_bloques boolean DEFAULT true, p_duracion_bloque_minutos integer DEFAULT 30, p_recurrente boolean DEFAULT false, p_dias_semana integer[] DEFAULT NULL::integer[], p_fecha_inicio date DEFAULT NULL::date, p_fecha_fin date DEFAULT NULL::date) RETURNS TABLE(ok boolean, disponibilidad_id uuid, asesor_id uuid, inicio timestamp with time zone, fin timestamp with time zone, usa_bloques boolean, duracion_bloque_minutos integer, recurrente boolean, dia_semana integer, fecha_inicio date, fecha_fin date, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_disponibilidad_id uuid;
  v_dia integer;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  if p_fin <= p_inicio then
    raise exception 'La fecha fin debe ser mayor a la fecha inicio';
  end if;

  if p_duracion_bloque_minutos <= 0 then
    raise exception 'La duración del bloque debe ser mayor a 0';
  end if;

  if p_recurrente then
    if p_dias_semana is null or array_length(p_dias_semana, 1) is null then
      raise exception 'Si es recurrente debe indicar al menos un día de semana';
    end if;

    if p_fecha_inicio is null or p_fecha_fin is null then
      raise exception 'Si es recurrente debe indicar fecha_inicio y fecha_fin';
    end if;

    if p_fecha_fin < p_fecha_inicio then
      raise exception 'fecha_fin debe ser mayor o igual a fecha_inicio';
    end if;

    foreach v_dia in array p_dias_semana
    loop
      insert into "AT".disponibilidad_asesor (
        asesor_id,
        inicio,
        fin,
        usa_bloques,
        duracion_bloque_minutos,
        recurrente,
        dia_semana,
        fecha_inicio,
        fecha_fin,
        disponible,
        activo,
        creado_en,
        actualizado_en
      )
      values (
        v_asesor_id,
        p_inicio,
        p_fin,
        p_usa_bloques,
        p_duracion_bloque_minutos,
        true,
        v_dia,
        p_fecha_inicio,
        p_fecha_fin,
        true,
        true,
        now(),
        now()
      )
      returning id into v_disponibilidad_id;

      return query
      select
        true,
        v_disponibilidad_id,
        v_asesor_id,
        p_inicio,
        p_fin,
        p_usa_bloques,
        p_duracion_bloque_minutos,
        true,
        v_dia,
        p_fecha_inicio,
        p_fecha_fin,
        'Espacio recurrente creado correctamente'::text;
    end loop;

  else
    insert into "AT".disponibilidad_asesor (
      asesor_id,
      inicio,
      fin,
      usa_bloques,
      duracion_bloque_minutos,
      recurrente,
      dia_semana,
      fecha_inicio,
      fecha_fin,
      disponible,
      activo,
      creado_en,
      actualizado_en
    )
    values (
      v_asesor_id,
      p_inicio,
      p_fin,
      p_usa_bloques,
      p_duracion_bloque_minutos,
      false,
      null,
      null,
      null,
      true,
      true,
      now(),
      now()
    )
    returning id into v_disponibilidad_id;

    return query
    select
      true,
      v_disponibilidad_id,
      v_asesor_id,
      p_inicio,
      p_fin,
      p_usa_bloques,
      p_duracion_bloque_minutos,
      false,
      null::integer,
      null::date,
      null::date,
      'Espacio único creado correctamente'::text;
  end if;
end;
$$;


--
-- Name: crear_espacio_libre_asesor(timestamp with time zone, timestamp with time zone, boolean, integer, boolean, integer, date, date); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_espacio_libre_asesor(p_inicio timestamp with time zone, p_fin timestamp with time zone, p_usa_bloques boolean DEFAULT true, p_duracion_bloque_minutos integer DEFAULT 30, p_recurrente boolean DEFAULT false, p_dia_semana integer DEFAULT NULL::integer, p_fecha_inicio date DEFAULT NULL::date, p_fecha_fin date DEFAULT NULL::date) RETURNS TABLE(ok boolean, disponibilidad_id uuid, asesor_id uuid, inicio timestamp with time zone, fin timestamp with time zone, usa_bloques boolean, duracion_bloque_minutos integer, recurrente boolean, dia_semana integer, fecha_inicio date, fecha_fin date, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_disponibilidad_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  if p_fin <= p_inicio then
    raise exception 'La fecha fin debe ser mayor a la fecha inicio';
  end if;

  if p_duracion_bloque_minutos <= 0 then
    raise exception 'La duración del bloque debe ser mayor a 0';
  end if;

  if p_recurrente = true and p_dia_semana is null then
    raise exception 'Si es recurrente debe indicar dia_semana';
  end if;

  insert into "AT".disponibilidad_asesor (
    asesor_id,
    inicio,
    fin,
    usa_bloques,
    duracion_bloque_minutos,
    recurrente,
    dia_semana,
    fecha_inicio,
    fecha_fin,
    disponible,
    activo,
    creado_en,
    actualizado_en
  )
  values (
    v_asesor_id,
    p_inicio,
    p_fin,
    p_usa_bloques,
    p_duracion_bloque_minutos,
    p_recurrente,
    p_dia_semana,
    p_fecha_inicio,
    p_fecha_fin,
    true,
    true,
    now(),
    now()
  )
  returning id into v_disponibilidad_id;

  return query
  select
    true,
    v_disponibilidad_id,
    v_asesor_id,
    p_inicio,
    p_fin,
    p_usa_bloques,
    p_duracion_bloque_minutos,
    p_recurrente,
    p_dia_semana,
    p_fecha_inicio,
    p_fecha_fin,
    'Espacio libre creado correctamente'::text;
end;
$$;


--
-- Name: crear_mi_tesis(uuid, text, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_mi_tesis(p_universidad_id uuid, p_titulo text, p_descripcion text DEFAULT NULL::text) RETURNS TABLE(r_ok boolean, r_tesis_id uuid, r_estudiante_id uuid, r_universidad_id uuid, r_titulo text, r_descripcion text, r_estado character varying, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_tesis_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  insert into "AT".tesis (
    estudiante_id,
    universidad_id,
    titulo,
    descripcion,
    estado,
    creado_en,
    actualizado_en
  )
  values (
    v_estudiante_id,
    p_universidad_id,
    p_titulo,
    p_descripcion,
    'borrador',
    now(),
    now()
  )
  returning id into v_tesis_id;

  return query
  select
    true,
    v_tesis_id,
    v_estudiante_id,
    p_universidad_id,
    p_titulo,
    p_descripcion,
    'borrador'::varchar,
    'Tesis creada correctamente'::text;
end;
$$;


--
-- Name: crear_observacion_tesis_enriquecida(uuid, uuid, uuid, uuid, text, text, text, jsonb, character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_observacion_tesis_enriquecida(p_tesis_id uuid, p_documento_tesis_id uuid DEFAULT NULL::uuid, p_reunion_id uuid DEFAULT NULL::uuid, p_validation_cita_id uuid DEFAULT NULL::uuid, p_titulo text DEFAULT NULL::text, p_texto text DEFAULT NULL::text, p_contenido_html text DEFAULT NULL::text, p_contenido_delta jsonb DEFAULT NULL::jsonb, p_tipo_origen character varying DEFAULT 'manual'::character varying) RETURNS TABLE(ok boolean, observacion_id uuid, tesis_id uuid, reunion_id uuid, validation_cita_id uuid, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
declare
  v_auth_user_id uuid;
  v_usuario_id uuid;
  v_rol varchar;
  v_observacion_id uuid;
  v_asesor_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
  into v_usuario_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  limit 1;

  if v_usuario_id is null then
    raise exception 'Usuario no válido';
  end if;

  if v_rol not in ('asesor', 'admin') then
    raise exception 'No autorizado para registrar observaciones';
  end if;

  if not exists (
    select 1
    from "AT".tesis t
    where t.id = p_tesis_id
      and t.eliminado_en is null
  ) then
    raise exception 'La tesis no existe';
  end if;

  if p_documento_tesis_id is not null then
    if not exists (
      select 1
      from "AT".documentos_tesis d
      where d.id = p_documento_tesis_id
        and d.tesis_id = p_tesis_id
    ) then
      raise exception 'El documento no pertenece a la tesis';
    end if;
  end if;

  if v_rol = 'asesor' then
    v_asesor_id := v_usuario_id;
  else
    v_asesor_id := null;
  end if;

  insert into "AT".observaciones_tesis (
    tesis_id,
    documento_tesis_id,
    asesor_id,
    reunion_id,
    validation_cita_id,
    texto,
    titulo,
    contenido_html,
    contenido_delta,
    tipo_origen,
    creado_en,
    actualizado_en
  )
  values (
    p_tesis_id,
    p_documento_tesis_id,
    v_asesor_id,
    p_reunion_id,
    p_validation_cita_id,
    coalesce(p_texto, p_contenido_html, ''),
    p_titulo,
    p_contenido_html,
    p_contenido_delta,
    p_tipo_origen,
    now(),
    now()
  )
  returning id into v_observacion_id;

  return query
  select
    true,
    v_observacion_id,
    p_tesis_id,
    p_reunion_id,
    p_validation_cita_id,
    'Observación registrada correctamente'::text;
end;
$$;


--
-- Name: crear_presustentacion_plan_o_pago(uuid, uuid, uuid, timestamp with time zone, timestamp with time zone, text, character varying, text, text, text, numeric); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_presustentacion_plan_o_pago(p_estudiante_id uuid, p_tesis_id uuid, p_disponibilidad_id uuid, p_inicio timestamp with time zone, p_fin timestamp with time zone, p_motivo text DEFAULT 'Presustentación'::text, p_modalidad character varying DEFAULT NULL::character varying, p_lugar text DEFAULT NULL::text, p_enlace_reunion text DEFAULT NULL::text, p_notas text DEFAULT NULL::text, p_monto_presustentacion numeric DEFAULT 200) RETURNS TABLE(reunion_id uuid, asesor_id uuid, pago_id uuid, suscripcion_id uuid, beneficio_consumo_id uuid, cubierta_por_plan boolean, costo_reunion numeric, estado character varying, tipo_reunion character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_reunion_id uuid;
  v_pago_id uuid;
  v_asesor_id uuid := '4729085e-b781-40ba-a5a2-049e8d3ddd5d';
  v_suscripcion_id uuid;
  v_beneficio_consumo_id uuid;
  v_cubierta_por_plan boolean := false;
  v_costo_reunion numeric(10,2) := 0;
  v_estado varchar := 'pendiente';
begin
  if p_estudiante_id is null then
    raise exception 'El estudiante es obligatorio';
  end if;

  if p_inicio is null or p_fin is null or p_fin <= p_inicio then
    raise exception 'Rango horario inválido';
  end if;

  select
    x."suscripcion_id",
    x."beneficio_consumo_id"
  into
    v_suscripcion_id,
    v_beneficio_consumo_id
  from "AT"."obtener_beneficio_disponible_estudiante"(
    p_estudiante_id,
    'presustentacion_incluida'
  ) x
  limit 1;

  if v_beneficio_consumo_id is not null then
    v_cubierta_por_plan := true;
    v_costo_reunion := 0;
    v_estado := 'confirmada';

    perform *
    from "AT"."consumir_beneficio_suscripcion"(v_beneficio_consumo_id);

  else
    v_cubierta_por_plan := false;
    v_costo_reunion := coalesce(p_monto_presustentacion, 200);

    insert into "AT"."pagos" (
      "pagador_id",
      "concepto",
      "monto",
      "estado",
      "metadata"
    )
    values (
      p_estudiante_id,
      'Pago por presustentación',
      v_costo_reunion,
      'pendiente',
      jsonb_build_object(
        'tipo_pago', 'presustentacion',
        'tesis_id', p_tesis_id,
        'asesor_id', v_asesor_id
      )
    )
    returning "id" into v_pago_id;

    v_estado := 'pendiente_pago';
  end if;

  insert into "AT"."reuniones_asesor" (
    "disponibilidad_id",
    "asesor_id",
    "estudiante_id",
    "tesis_id",
    "estado",
    "pago_id",
    "motivo",
    "notas",
    "modalidad",
    "lugar",
    "enlace_reunion",
    "inicio",
    "fin",
    "duracion_minutos",
    "costo_reunion",
    "moneda",
    "suscripcion_id",
    "beneficio_consumo_id",
    "cubierta_por_plan",
    "tipo_reunion"
  )
  values (
    p_disponibilidad_id,
    v_asesor_id,
    p_estudiante_id,
    p_tesis_id,
    v_estado,
    v_pago_id,
    p_motivo,
    p_notas,
    p_modalidad,
    p_lugar,
    p_enlace_reunion,
    p_inicio,
    p_fin,
    greatest((extract(epoch from (p_fin - p_inicio)) / 60)::integer, 1),
    v_costo_reunion,
    'PEN',
    v_suscripcion_id,
    v_beneficio_consumo_id,
    v_cubierta_por_plan,
    'presustentacion'
  )
  returning "id" into v_reunion_id;

  return query
  select
    v_reunion_id,
    v_asesor_id,
    v_pago_id,
    v_suscripcion_id,
    v_beneficio_consumo_id,
    v_cubierta_por_plan,
    v_costo_reunion,
    v_estado,
    'presustentacion'::varchar;
end;
$$;


--
-- Name: crear_schedule_asesor(timestamp with time zone, timestamp with time zone, boolean, integer, boolean, integer, date, date); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_schedule_asesor(p_inicio timestamp with time zone, p_fin timestamp with time zone, p_usa_bloques boolean DEFAULT true, p_duracion_bloque_minutos integer DEFAULT 30, p_recurrente boolean DEFAULT false, p_dia_semana integer DEFAULT NULL::integer, p_fecha_inicio date DEFAULT NULL::date, p_fecha_fin date DEFAULT NULL::date) RETURNS TABLE(r_ok boolean, r_disponibilidad_id uuid, r_asesor_id uuid, r_inicio timestamp with time zone, r_fin timestamp with time zone, r_usa_bloques boolean, r_duracion_bloque_minutos integer, r_recurrente boolean, r_dia_semana integer, r_fecha_inicio date, r_fecha_fin date, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_disponibilidad_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  if p_fin <= p_inicio then
    raise exception 'La fecha fin debe ser mayor a la fecha inicio';
  end if;

  if p_duracion_bloque_minutos <= 0 then
    raise exception 'La duración del bloque debe ser mayor a 0';
  end if;

  if p_recurrente = true and p_dia_semana is null then
    raise exception 'Si es recurrente debe indicar dia_semana';
  end if;

  insert into "AT".disponibilidad_asesor (
    asesor_id,
    inicio,
    fin,
    usa_bloques,
    duracion_bloque_minutos,
    recurrente,
    dia_semana,
    fecha_inicio,
    fecha_fin,
    disponible,
    activo,
    creado_en,
    actualizado_en
  )
  values (
    v_asesor_id,
    p_inicio,
    p_fin,
    p_usa_bloques,
    p_duracion_bloque_minutos,
    p_recurrente,
    p_dia_semana,
    p_fecha_inicio,
    p_fecha_fin,
    true,
    true,
    now(),
    now()
  )
  returning id into v_disponibilidad_id;

  return query
  select
    true,
    v_disponibilidad_id,
    v_asesor_id,
    p_inicio,
    p_fin,
    p_usa_bloques,
    p_duracion_bloque_minutos,
    p_recurrente,
    p_dia_semana,
    p_fecha_inicio,
    p_fecha_fin,
    'Schedule creado correctamente'::text;
end;
$$;


--
-- Name: crear_sugerencia_asesor(uuid, uuid, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_sugerencia_asesor(p_tesis_id uuid, p_documento_tesis_id uuid, p_sugerencia text) RETURNS TABLE(r_ok boolean, r_sugerencia_id uuid, r_tesis_id uuid, r_documento_tesis_id uuid, r_asesor_id uuid, r_sugerencia text, r_aplicado boolean, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_estudiante_id uuid;
  v_sugerencia_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  -- tesis válida
  select t.estudiante_id
    into v_estudiante_id
  from "AT".tesis t
  where t.id = p_tesis_id
    and t.eliminado_en is null
  limit 1;

  if v_estudiante_id is null then
    raise exception 'La tesis no existe';
  end if;

  -- validar vínculo asesor-estudiante
  if not exists (
    select 1
    from "AT".relaciones_asesor_estudiante r
    where r.asesor_id = v_asesor_id
      and r.estudiante_id = v_estudiante_id
      and r.estado in ('activo', 'pendiente')
  ) then
    raise exception 'El asesor no está vinculado a esta tesis';
  end if;

  -- validar documento si viene
  if p_documento_tesis_id is not null then
    if not exists (
      select 1
      from "AT".documentos_tesis d
      where d.id = p_documento_tesis_id
        and d.tesis_id = p_tesis_id
    ) then
      raise exception 'El documento de tesis no pertenece a la tesis indicada';
    end if;
  end if;

  insert into "AT".historial_sugerencias_asesor (
    tesis_id,
    asesor_id,
    documento_tesis_id,
    sugerencia,
    aplicado,
    creado_en,
    actualizado_en
  )
  values (
    p_tesis_id,
    v_asesor_id,
    p_documento_tesis_id,
    p_sugerencia,
    false,
    now(),
    now()
  )
  returning id into v_sugerencia_id;

  return query
  select
    true,
    v_sugerencia_id,
    p_tesis_id,
    p_documento_tesis_id,
    v_asesor_id,
    p_sugerencia,
    false,
    'Sugerencia registrada correctamente'::text;
end;
$$;


--
-- Name: crear_sugerencia_asesor(uuid, uuid, uuid, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_sugerencia_asesor(p_tesis_id uuid, p_documento_tesis_id uuid, p_tipo_sugerencia_id uuid, p_detalle text) RETURNS TABLE(r_ok boolean, r_sugerencia_id uuid, r_tesis_id uuid, r_documento_tesis_id uuid, r_asesor_id uuid, r_tipo_sugerencia_id uuid, r_detalle text, r_aplicado boolean, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_estudiante_id uuid;
  v_sugerencia_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  select t.estudiante_id
    into v_estudiante_id
  from "AT".tesis t
  where t.id = p_tesis_id
    and t.eliminado_en is null
  limit 1;

  if v_estudiante_id is null then
    raise exception 'La tesis no existe';
  end if;

  if not exists (
    select 1
    from "AT".relaciones_asesor_estudiante r
    where r.asesor_id = v_asesor_id
      and r.estudiante_id = v_estudiante_id
      and r.estado in ('activo', 'pendiente')
  ) then
    raise exception 'El asesor no está vinculado a esta tesis';
  end if;

  if p_documento_tesis_id is not null then
    if not exists (
      select 1
      from "AT".documentos_tesis d
      where d.id = p_documento_tesis_id
        and d.tesis_id = p_tesis_id
    ) then
      raise exception 'El documento de tesis no pertenece a la tesis indicada';
    end if;
  end if;

  if not exists (
    select 1
    from "AT".tipos_sugerencia_asesor ts
    where ts.id = p_tipo_sugerencia_id
      and coalesce(ts.activo, true) = true
  ) then
    raise exception 'El tipo de sugerencia no es válido';
  end if;

  insert into "AT".historial_sugerencias_asesor (
    tesis_id,
    asesor_id,
    documento_tesis_id,
    tipo_sugerencia_id,
    sugerencia,
    detalle,
    aplicado,
    aplicado_por_estudiante,
    creado_en,
    actualizado_en
  )
  values (
    p_tesis_id,
    v_asesor_id,
    p_documento_tesis_id,
    p_tipo_sugerencia_id,
    p_detalle,
    p_detalle,
    false,
    false,
    now(),
    now()
  )
  returning id into v_sugerencia_id;

  return query
  select
    true,
    v_sugerencia_id,
    p_tesis_id,
    p_documento_tesis_id,
    v_asesor_id,
    p_tipo_sugerencia_id,
    p_detalle,
    false,
    'Sugerencia registrada correctamente'::text;
end;
$$;


--
-- Name: crear_tesis_con_plan(uuid, uuid, text, text, uuid, uuid, character varying, boolean, uuid, character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_tesis_con_plan(p_estudiante_id uuid, p_universidad_id uuid, p_titulo text, p_descripcion text, p_plan_id uuid, p_tipo_tesis_id uuid, p_nivel_academico character varying, p_requiere_analisis_estadistico boolean DEFAULT true, p_programa_id uuid DEFAULT NULL::uuid, p_estado_tesis character varying DEFAULT 'pendiente_pago'::character varying) RETURNS TABLE(tesis_id uuid, pago_id uuid, plan_id uuid, plan_nombre character varying, tipo_tesis_id uuid, tipo_tesis_nombre character varying, nivel_academico character varying, precio_base numeric, porcentaje_nivel numeric, monto_ajuste_nivel numeric, descuento_analisis_estadistico numeric, precio_total numeric, moneda character varying, estado_tesis character varying, estado_pago character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_tesis_id uuid;
  v_pago_id uuid;

  v_plan_nombre varchar;
  v_tipo_tesis_nombre varchar;

  v_precio_base numeric(10,2);
  v_porcentaje_nivel numeric(5,2) := 0;
  v_monto_ajuste_nivel numeric(10,2) := 0;
  v_descuento_analisis numeric(10,2) := 0;
  v_precio_total numeric(10,2) := 0;
  v_moneda varchar := 'PEN';

  v_nivel_normalizado varchar;
begin
  if p_estudiante_id is null then
    raise exception 'El estudiante es obligatorio';
  end if;

  if p_titulo is null or btrim(p_titulo) = '' then
    raise exception 'El título de la tesis es obligatorio';
  end if;

  if p_plan_id is null then
    raise exception 'El plan es obligatorio';
  end if;

  if p_tipo_tesis_id is null then
    raise exception 'El tipo de tesis es obligatorio';
  end if;

  if p_nivel_academico is null or btrim(p_nivel_academico) = '' then
    raise exception 'El nivel académico es obligatorio';
  end if;

  v_nivel_normalizado := upper(trim(p_nivel_academico));

  if v_nivel_normalizado not in ('PREGRADO', 'MAESTRIA', 'ESPECIALIDAD', 'DOCTORADO') then
    raise exception 'Nivel académico inválido. Debe ser PREGRADO, MAESTRIA, ESPECIALIDAD o DOCTORADO';
  end if;

  select
    p."nombre",
    tt."nombre",
    pt."precio_base",
    pt."moneda"
  into
    v_plan_nombre,
    v_tipo_tesis_nombre,
    v_precio_base,
    v_moneda
  from "AT"."planes_tipos_tesis_precios" pt
  inner join "AT"."planes" p
    on p."id" = pt."plan_id"
  inner join "AT"."tipos_tesis" tt
    on tt."id" = pt."tipo_tesis_id"
  where pt."plan_id" = p_plan_id
    and pt."tipo_tesis_id" = p_tipo_tesis_id
    and coalesce(pt."activo", true) = true
    and coalesce(p."activo", true) = true
    and coalesce(tt."activo", true) = true
  limit 1;

  if v_precio_base is null then
    raise exception 'No existe precio configurado para el plan y tipo de tesis enviados';
  end if;

  v_porcentaje_nivel := case
    when v_nivel_normalizado = 'PREGRADO' then 0
    when v_nivel_normalizado = 'MAESTRIA' then 15
    when v_nivel_normalizado = 'ESPECIALIDAD' then 15
    when v_nivel_normalizado = 'DOCTORADO' then 20
    else 0
  end;

  v_monto_ajuste_nivel := round((v_precio_base * v_porcentaje_nivel / 100.0)::numeric, 2);

  v_descuento_analisis := case
    when coalesce(p_requiere_analisis_estadistico, true) = false then 500
    else 0
  end;

  v_precio_total := greatest(
    v_precio_base + v_monto_ajuste_nivel - v_descuento_analisis,
    0
  );

  insert into "AT"."tesis" (
    "estudiante_id",
    "universidad_id",
    "titulo",
    "descripcion",
    "estado",
    "tipo_tesis_id",
    "plan_id",
    "programa_id",
    "nivel_academico",
    "requiere_analisis_estadistico",
    "precio_base",
    "porcentaje_nivel",
    "monto_ajuste_nivel",
    "descuento_analisis_estadistico",
    "precio_total",
    "moneda"
  )
  values (
    p_estudiante_id,
    p_universidad_id,
    p_titulo,
    p_descripcion,
    p_estado_tesis,
    p_tipo_tesis_id,
    p_plan_id,
    p_programa_id,
    v_nivel_normalizado,
    coalesce(p_requiere_analisis_estadistico, true),
    v_precio_base,
    v_porcentaje_nivel,
    v_monto_ajuste_nivel,
    v_descuento_analisis,
    v_precio_total,
    coalesce(v_moneda, 'PEN')
  )
  returning "id" into v_tesis_id;

  insert into "AT"."pagos" (
    "pagador_id",
    "tesis_id",
    "concepto",
    "monto",
    "estado",
    "metadata"
  )
  values (
    p_estudiante_id,
    v_tesis_id,
    'Pago por plan de tesis: ' || p_titulo,
    v_precio_total,
    'pendiente',
    jsonb_build_object(
      'origen_pago', 'deposito_cuenta',
      'plan_id', p_plan_id,
      'plan_nombre', v_plan_nombre,
      'tipo_tesis_id', p_tipo_tesis_id,
      'tipo_tesis_nombre', v_tipo_tesis_nombre,
      'nivel_academico', v_nivel_normalizado,
      'precio_base', v_precio_base,
      'porcentaje_nivel', v_porcentaje_nivel,
      'monto_ajuste_nivel', v_monto_ajuste_nivel,
      'descuento_analisis_estadistico', v_descuento_analisis,
      'precio_total', v_precio_total,
      'moneda', coalesce(v_moneda, 'PEN')
    )
  )
  returning "id" into v_pago_id;

  insert into "AT"."pagos_plan" (
    "pago_id",
    "plan_id"
  )
  values (
    v_pago_id,
    p_plan_id
  );

  return query
  select
    v_tesis_id,
    v_pago_id,
    p_plan_id,
    v_plan_nombre,
    p_tipo_tesis_id,
    v_tipo_tesis_nombre,
    v_nivel_normalizado,
    v_precio_base,
    v_porcentaje_nivel,
    v_monto_ajuste_nivel,
    v_descuento_analisis,
    v_precio_total,
    coalesce(v_moneda, 'PEN'),
    p_estado_tesis,
    'pendiente'::varchar;
end;
$$;


--
-- Name: crear_tesis_y_pago_plan(uuid, uuid, text, text, uuid, uuid, uuid, character varying, integer, boolean, boolean, boolean, boolean, character varying, character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".crear_tesis_y_pago_plan(p_estudiante_id uuid, p_universidad_id uuid, p_titulo text, p_descripcion text, p_plan_id uuid, p_tipo_tesis_id uuid, p_programa_id uuid DEFAULT NULL::uuid, p_nivel_academico character varying DEFAULT 'pregrado'::character varying, p_cantidad_variables integer DEFAULT 1, p_requiere_analisis_estadistico boolean DEFAULT true, p_es_arquitectura_diseno boolean DEFAULT false, p_tiene_variable_exogena_simple boolean DEFAULT false, p_tiene_variable_exogena_analisis_adicional boolean DEFAULT false, p_metodo_pago character varying DEFAULT 'pendiente'::character varying, p_estado_tesis character varying DEFAULT 'pendiente_pago'::character varying) RETURNS TABLE(tesis_id uuid, pago_id uuid, plan_id uuid, tipo_tesis_id uuid, precio_base numeric, precio_ajustes numeric, precio_total numeric, moneda character varying, metodo_pago character varying, estado_pago character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_tesis_id uuid;
  v_pago_id uuid;
  v_precio_base numeric(10,2);
  v_precio_ajustes numeric(10,2) := 0;
  v_precio_total numeric(10,2) := 0;
  v_moneda varchar := 'PEN';

  v_ajuste record;
  v_valor_aplicado numeric(10,2);
begin
  if p_titulo is null or btrim(p_titulo) = '' then
    raise exception 'El título es obligatorio';
  end if;

  if p_plan_id is null then
    raise exception 'El plan es obligatorio';
  end if;

  if p_tipo_tesis_id is null then
    raise exception 'El tipo de tesis es obligatorio';
  end if;

  if p_cantidad_variables is null or p_cantidad_variables < 1 then
    raise exception 'La cantidad de variables debe ser al menos 1';
  end if;

  select
    pt."precio_base",
    pt."moneda"
  into
    v_precio_base,
    v_moneda
  from "AT"."planes_tipos_tesis_precios" pt
  where pt."plan_id" = p_plan_id
    and pt."tipo_tesis_id" = p_tipo_tesis_id
    and coalesce(pt."activo", true) = true
  limit 1;

  if v_precio_base is null then
    raise exception 'No existe precio configurado para el plan y tipo de tesis enviados';
  end if;

  insert into "AT"."tesis" (
    "estudiante_id",
    "universidad_id",
    "titulo",
    "descripcion",
    "estado",
    "tipo_tesis_id",
    "plan_id",
    "programa_id",
    "nivel_academico",
    "cantidad_variables",
    "requiere_analisis_estadistico",
    "es_arquitectura_diseno",
    "precio_base",
    "precio_ajustes",
    "precio_total",
    "moneda"
  )
  values (
    p_estudiante_id,
    p_universidad_id,
    p_titulo,
    p_descripcion,
    p_estado_tesis,
    p_tipo_tesis_id,
    p_plan_id,
    p_programa_id,
    lower(coalesce(p_nivel_academico, 'pregrado')),
    p_cantidad_variables,
    p_requiere_analisis_estadistico,
    p_es_arquitectura_diseno,
    v_precio_base,
    0,
    v_precio_base,
    v_moneda
  )
  returning "id" into v_tesis_id;

  for v_ajuste in
    select *
    from "AT"."ajustes_adicionales_tesis" a
    where coalesce(a."activo", true) = true
  loop
    v_valor_aplicado := null;

    if v_ajuste."codigo" = 'nivel_pregrado'
       and lower(coalesce(p_nivel_academico, 'pregrado')) = 'pregrado' then

      v_valor_aplicado := round((v_precio_base * coalesce(v_ajuste."valor", 0) / 100.0)::numeric, 2);

    elsif v_ajuste."codigo" = 'nivel_maestria'
       and lower(coalesce(p_nivel_academico, 'pregrado')) = 'maestria' then

      v_valor_aplicado := round((v_precio_base * coalesce(v_ajuste."valor", 0) / 100.0)::numeric, 2);

    elsif v_ajuste."codigo" = 'nivel_especialidad'
       and lower(coalesce(p_nivel_academico, 'pregrado')) = 'especialidad' then

      v_valor_aplicado := round((v_precio_base * coalesce(v_ajuste."valor", 0) / 100.0)::numeric, 2);

    elsif v_ajuste."codigo" = 'nivel_doctorado'
       and lower(coalesce(p_nivel_academico, 'pregrado')) = 'doctorado' then

      v_valor_aplicado := round((v_precio_base * coalesce(v_ajuste."valor", 0) / 100.0)::numeric, 2);

    elsif v_ajuste."codigo" = 'variable_adicional'
       and p_cantidad_variables > 1 then

      v_valor_aplicado := (p_cantidad_variables - 1) * coalesce(v_ajuste."valor", 0);

    elsif v_ajuste."codigo" = 'variable_exogena_simple'
       and coalesce(p_tiene_variable_exogena_simple, false) = true then

      v_valor_aplicado := coalesce(v_ajuste."valor", 0);

    elsif v_ajuste."codigo" = 'variable_exogena_analisis_adicional'
       and coalesce(p_tiene_variable_exogena_analisis_adicional, false) = true then

      insert into "AT"."tesis_ajustes_aplicados" (
        "tesis_id",
        "ajuste_id",
        "estado",
        "base_calculo",
        "valor_configurado",
        "valor_aplicado",
        "signo",
        "tipo_ajuste",
        "automatico",
        "requiere_evaluacion",
        "observacion",
        "metadata"
      )
      values (
        v_tesis_id,
        v_ajuste."id",
        'pendiente',
        v_precio_base,
        v_ajuste."valor",
        null,
        v_ajuste."signo",
        v_ajuste."tipo_ajuste",
        coalesce(v_ajuste."automatico", false),
        coalesce(v_ajuste."requiere_evaluacion", false),
        'Pendiente de evaluación por análisis adicional',
        jsonb_build_object('origen', 'crear_tesis_y_pago_plan')
      );

    elsif v_ajuste."codigo" = 'sin_analisis_estadistico'
       and coalesce(p_requiere_analisis_estadistico, true) = false then

      v_valor_aplicado := coalesce(v_ajuste."valor", 0);

    elsif v_ajuste."codigo" = 'arquitectura_diseno'
       and coalesce(p_es_arquitectura_diseno, false) = true then

      insert into "AT"."tesis_ajustes_aplicados" (
        "tesis_id",
        "ajuste_id",
        "estado",
        "base_calculo",
        "valor_configurado",
        "valor_aplicado",
        "signo",
        "tipo_ajuste",
        "automatico",
        "requiere_evaluacion",
        "observacion",
        "metadata"
      )
      values (
        v_tesis_id,
        v_ajuste."id",
        'pendiente',
        v_precio_base,
        v_ajuste."valor",
        null,
        v_ajuste."signo",
        v_ajuste."tipo_ajuste",
        coalesce(v_ajuste."automatico", false),
        coalesce(v_ajuste."requiere_evaluacion", false),
        'Pendiente de evaluación por arquitectura/diseño',
        jsonb_build_object('origen', 'crear_tesis_y_pago_plan')
      );
    end if;

    if v_valor_aplicado is not null then
      insert into "AT"."tesis_ajustes_aplicados" (
        "tesis_id",
        "ajuste_id",
        "estado",
        "base_calculo",
        "valor_configurado",
        "valor_aplicado",
        "signo",
        "tipo_ajuste",
        "automatico",
        "requiere_evaluacion",
        "observacion",
        "metadata"
      )
      values (
        v_tesis_id,
        v_ajuste."id",
        'aplicado',
        v_precio_base,
        v_ajuste."valor",
        v_valor_aplicado,
        v_ajuste."signo",
        v_ajuste."tipo_ajuste",
        coalesce(v_ajuste."automatico", false),
        coalesce(v_ajuste."requiere_evaluacion", false),
        'Ajuste aplicado automáticamente',
        jsonb_build_object('origen', 'crear_tesis_y_pago_plan')
      );

      if v_ajuste."signo" = '-' then
        v_precio_ajustes := v_precio_ajustes - v_valor_aplicado;
      else
        v_precio_ajustes := v_precio_ajustes + v_valor_aplicado;
      end if;
    end if;
  end loop;

  v_precio_total := greatest(v_precio_base + v_precio_ajustes, 0);

  update "AT"."tesis"
  set
    "precio_ajustes" = v_precio_ajustes,
    "precio_total" = v_precio_total,
    "actualizado_en" = now()
  where "id" = v_tesis_id;

  insert into "AT"."pagos" (
    "pagador_id",
    "tesis_id",
    "concepto",
    "monto",
    "estado",
    "metadata"
  )
  values (
    p_estudiante_id,
    v_tesis_id,
    'Pago de plan de tesis: ' || p_titulo,
    v_precio_total,
    'pendiente',
    jsonb_build_object(
      'plan_id', p_plan_id,
      'tipo_tesis_id', p_tipo_tesis_id,
      'metodo_pago', p_metodo_pago,
      'precio_base', v_precio_base,
      'precio_ajustes', v_precio_ajustes,
      'precio_total', v_precio_total,
      'moneda', v_moneda
    )
  )
  returning "id" into v_pago_id;

  insert into "AT"."pagos_plan" (
    "pago_id",
    "plan_id"
  )
  values (
    v_pago_id,
    p_plan_id
  );

  return query
  select
    v_tesis_id,
    v_pago_id,
    p_plan_id,
    p_tipo_tesis_id,
    v_precio_base,
    v_precio_ajustes,
    v_precio_total,
    v_moneda,
    p_metodo_pago,
    'pendiente'::varchar;
end;
$$;


--
-- Name: desactivar_espacio_libre_asesor(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".desactivar_espacio_libre_asesor(p_disponibilidad_id uuid) RETURNS TABLE(ok boolean, disponibilidad_id uuid, activo boolean, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  update "AT".disponibilidad_asesor
  set
    activo = false,
    actualizado_en = now()
  where id = p_disponibilidad_id
    and asesor_id = v_asesor_id;

  if not found then
    raise exception 'No se encontró el espacio libre o no tienes permiso';
  end if;

  return query
  select
    true,
    p_disponibilidad_id,
    false,
    'Espacio libre desactivado correctamente'::text;
end;
$$;


--
-- Name: encolar_creacion_google_meet(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".encolar_creacion_google_meet() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
begin
  -- solo cuando pase de cualquier estado a validado
  if new.estado = 'validado'
     and coalesce(old.estado, '') is distinct from 'validado' then

    insert into "AT".cola_google_meet (reunion_id, pago_id)
    select r.id, r.pago_id
    from "AT".reuniones_asesor r
    where r.pago_id = new.id
      and coalesce(r.enlace_reunion, '') = ''
    on conflict (reunion_id) do nothing;

    update "AT".reuniones_asesor
    set estado = 'pago_validado',
        actualizado_en = now()
    where pago_id = new.id
      and coalesce(enlace_reunion, '') = '';
  end if;

  return new;
end;
$$;


--
-- Name: encolar_invitacion_post_signup(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".encolar_invitacion_post_signup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
begin
  insert into "AT".invitaciones_pendientes (
    email,
    nombre,
    payload,
    estado,
    intentos,
    creado_en,
    actualizado_en
  )
  values (
    new.email,
    coalesce(new.raw_user_meta_data->>'nombre', null),
    jsonb_build_object(
      'auth_user_id', new.id,
      'email', new.email,
      'user_metadata', new.raw_user_meta_data
    ),
    'pendiente',
    0,
    now(),
    now()
  );

  return new;
end;
$$;


--
-- Name: encolar_invitacion_usuario_app(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".encolar_invitacion_usuario_app() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
begin
  insert into "AT".invitaciones_pendientes (
    email,
    nombre,
    payload,
    estado,
    intentos,
    creado_en,
    actualizado_en
  )
  select
    coalesce(new_payload.email, ''),
    null,
    jsonb_build_object(
      'usuario_id', new.id,
      'auth_usuario_id', new.auth_usuario_id,
      'rol', new.rol
    ),
    'pendiente',
    0,
    now(),
    now()
  from (
    select row_to_json(new)::jsonb as new_payload
  ) s
  where coalesce(new_payload.email, '') <> '';

  return new;
end;
$$;


--
-- Name: fn_crear_usuario_desde_auth(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_crear_usuario_desde_auth() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_rol varchar(20);
begin
  /*
    Toma el rol desde raw_user_meta_data si existe.
    Si no viene, por defecto será 'estudiante'.
  */
  v_rol := coalesce(new.raw_user_meta_data->>'rol', 'estudiante');

  /*
    Validación defensiva:
    solo se permiten los roles definidos en tu tabla.
  */
  if v_rol not in ('admin', 'asesor', 'estudiante') then
    v_rol := 'estudiante';
  end if;

  insert into "AT".usuarios (
    auth_usuario_id,
    rol,
    verificado,
    creado_en,
    actualizado_en
  )
  values (
    new.id,
    v_rol,
    coalesce(new.email_confirmed_at is not null, false),
    now(),
    now()
  )
  on conflict (auth_usuario_id) do nothing;

  return new;
end;
$$;


--
-- Name: fn_generar_pago_por_suscripcion(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_generar_pago_por_suscripcion() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_precio numeric;
  v_pago_id uuid;
  v_nombre_plan text;
begin
  select
    precio,
    nombre
  into
    v_precio,
    v_nombre_plan
  from "AT".planes
  where id = new.plan_id
    and coalesce(activo, true) = true;

  if v_precio is null then
    raise exception 'No se encontró un plan activo para plan_id=%', new.plan_id;
  end if;

  insert into "AT".pagos (
    pagador_id,
    concepto,
    monto,
    estado,
    metadata
  )
  values (
    new.estudiante_id,
    'Compra de plan: ' || v_nombre_plan,
    v_precio,
    'pendiente',
    jsonb_build_object(
      'suscripcion_id', new.id,
      'plan_id', new.plan_id,
      'tipo', 'plan'
    )
  )
  returning id into v_pago_id;

  insert into "AT".pagos_plan (
    pago_id,
    plan_id
  )
  values (
    v_pago_id,
    new.plan_id
  );

  return new;
end;
$$;


--
-- Name: fn_get_planes(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_get_planes() RETURNS TABLE(id uuid, nombre text, precio numeric, duracion_dias integer, caracteristicas jsonb, activo boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
  select
    p.id,
    p.nombre::text,
    p.precio,
    p.duracion_dias,
    p.caracteristicas,
    coalesce(p.activo, true) as activo
  from "AT".planes p
  where coalesce(p.activo, true) = true
  order by p.precio asc;
$$;


--
-- Name: fn_iniciar_pago_plan(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_iniciar_pago_plan(plan_id uuid) RETURNS TABLE(pago_id uuid, monto numeric, estado text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  v_precio numeric;
  v_nombre text;
  v_pagador_id uuid;
  v_pago_id uuid;
begin
  select u.id
  into v_pagador_id
  from "AT".usuarios u
  where u.auth_usuario_id = auth.uid()
    and u.rol = 'estudiante'
  limit 1;

  if v_pagador_id is null then
    raise exception 'No se encontro usuario AT para el estudiante autenticado';
  end if;

  select p.precio, p.nombre
  into v_precio, v_nombre
  from "AT".planes p
  where p.id = plan_id
    and coalesce(p.activo, true);

  if v_precio is null then
    raise exception 'Plan no encontrado o inactivo';
  end if;

  insert into "AT".pagos (
    id,
    pagador_id,
    concepto,
    monto,
    estado,
    codigo_operacion,
    creado_en,
    actualizado_en,
    nota_verificacion
  )
  values (
    gen_random_uuid(),
    v_pagador_id,
    'plan:' || v_nombre,
    v_precio,
    'pendiente',
    'PAY-' || substr(md5(random()::text), 1, 10),
    now(),
    now(),
    'Creado automaticamente'
  )
  returning id into v_pago_id;

  insert into "AT".pagos_plan (
    id,
    pago_id,
    plan_id,
    creado_en
  )
  values (
    gen_random_uuid(),
    v_pago_id,
    plan_id,
    now()
  );

  pago_id := v_pago_id;
  monto := v_precio;
  estado := 'pendiente';
  return next;
end;
$$;


--
-- Name: fn_iniciar_pago_plan(uuid, uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_iniciar_pago_plan(pagador_id uuid, plan_id uuid) RETURNS TABLE(pago_id uuid, monto numeric, estado text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare v_precio numeric; v_nombre text;
begin
  select precio, nombre into v_precio, v_nombre from "AT".planes where id = plan_id and coalesce(activo, true);
  if v_precio is null then raise exception 'Plan no encontrado o inactivo'; end if;

  insert into "AT".pagos(id, pagador_id, concepto, monto, estado, codigo_operacion, creado_en, actualizado_en, nota_verificacion)
  values (gen_random_uuid(), pagador_id, 'plan:'||v_nombre, v_precio, 'pendiente', 'PAY-'||substr(md5(random()::text),1,10), now(), now(), 'Creado automáticamente')
  returning id into pago_id;

  insert into "AT".pagos_plan(id, pago_id, plan_id, creado_en)
  values (gen_random_uuid(), pago_id, plan_id, now());

  estado := 'pendiente'; monto := v_precio;
  return;
end;
$$;


--
-- Name: fn_on_pago_before_insert_defaults(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_on_pago_before_insert_defaults() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  if new.estado is null then new.estado := 'pendiente'; end if;
  if new.monto is null then new.monto := 200; end if; -- monto fijo si no envían
  if new.creado_en is null then new.creado_en := now(); end if;
  new.actualizado_en := now();
  if new.codigo_operacion is null then new.codigo_operacion := 'PAY-'||substr(md5(random()::text),1,10); end if;
  return new;
end;
$$;


--
-- Name: fn_on_pago_plan_pagado(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_on_pago_plan_pagado() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare v_plan uuid; v_dias int; v_estudiante uuid;
begin
  select plan_id into v_plan from "AT".pagos_plan where pago_id = new.id;
  if v_plan is null then return new; end if;

  v_estudiante := new.pagador_id;
  select duracion_dias into v_dias from "AT".planes where id = v_plan;

  insert into "AT".suscripciones_estudiante(id, estudiante_id, plan_id, estado, iniciado_en, expira_en, creado_en, actualizado_en)
  values (gen_random_uuid(), v_estudiante, v_plan, 'activa', now(), now() + (v_dias || ' days')::interval, now(), now());
  return new;
end;
$$;


--
-- Name: fn_on_pago_reunion_pagado(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_on_pago_reunion_pagado() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare v_reunion uuid;
begin
  select id into v_reunion from "AT".reuniones_asesor where pago_id = new.id;
  if v_reunion is null then return new; end if;
  update "AT".reuniones_asesor set estado = 'confirmado', actualizado_en = now() where id = v_reunion;
  return new;
end;
$$;


--
-- Name: fn_on_reunion_insert_set_costo(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_on_reunion_insert_set_costo() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  new.costo_reunion := 200;
  new.moneda := 'PEN';
  if new.estado is null then new.estado := 'pendiente_pago'; end if;
  return new;
end;
$$;


--
-- Name: fn_planes_disponibles(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_planes_disponibles() RETURNS TABLE(id uuid, nombre text, precio numeric, duracion_dias integer, caracteristicas jsonb)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
  select p.id, p.nombre, p.precio, p.duracion_dias, p.caracteristicas
  from "AT".planes p
  where coalesce(p.activo, true)
  order by p.precio asc;
$$;


--
-- Name: fn_reservar_reunion(uuid, uuid, uuid, text, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".fn_reservar_reunion(p_disponibilidad uuid, p_asesor uuid, p_tesis uuid DEFAULT NULL::uuid, p_motivo text DEFAULT NULL::text, p_modalidad text DEFAULT 'virtual'::text) RETURNS TABLE(out_reunion_id uuid, out_pago_id uuid, out_enlace text, out_estado text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_inicio timestamptz;
  v_fin timestamptz;
  v_estudiante_id uuid;
  v_pago_id uuid;
  v_reunion_id uuid;
  v_enlace text;
  v_estado text;
begin
  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = auth.uid()
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'No se encontro usuario AT para el estudiante autenticado';
  end if;

  select d.inicio, d.fin
    into v_inicio, v_fin
  from "AT".disponibilidad_asesor d
  where d.id = p_disponibilidad
    and d.asesor_id = p_asesor
    and coalesce(d.disponible, true) = true
    and coalesce(d.activo, true) = true
  for update;

  if v_inicio is null then
    raise exception 'Disponibilidad no encontrada o no disponible';
  end if;

  insert into "AT".pagos (
    id,
    pagador_id,
    concepto,
    monto,
    estado,
    codigo_operacion,
    creado_en,
    actualizado_en,
    nota_verificacion
  )
  values (
    gen_random_uuid(),
    v_estudiante_id,
    'reunion',
    200,
    'pendiente',
    'PAY-' || substr(md5(random()::text), 1, 10),
    now(),
    now(),
    'Reunion pendiente de pago'
  )
  returning id into v_pago_id;

  insert into "AT".reuniones_asesor (
    id,
    disponibilidad_id,
    asesor_id,
    estudiante_id,
    tesis_id,
    estado,
    pago_id,
    motivo,
    modalidad,
    enlace_reunion,
    inicio,
    fin,
    duracion_minutos,
    costo_reunion,
    moneda,
    creado_en,
    actualizado_en
  )
  values (
    gen_random_uuid(),
    p_disponibilidad,
    p_asesor,
    v_estudiante_id,
    p_tesis,
    'pendiente',
    v_pago_id,
    p_motivo,
    p_modalidad,
    'https://meet.jit.si/' || gen_random_uuid(),
    v_inicio,
    v_fin,
    (extract(epoch from (v_fin - v_inicio)) / 60)::integer,
    200,
    'PEN',
    now(),
    now()
  )
  returning id, pago_id, enlace_reunion, estado
    into v_reunion_id, v_pago_id, v_enlace, v_estado;

  update "AT".disponibilidad_asesor
  set disponible = false,
      actualizado_en = now()
  where id = p_disponibilidad;

  out_reunion_id := v_reunion_id;
  out_pago_id := v_pago_id;
  out_enlace := v_enlace;
  out_estado := v_estado;

  return next;
end;
$$;


--
-- Name: generar_codigo_publico_asesor(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".generar_codigo_publico_asesor() RETURNS TABLE(r_ok boolean, r_codigo_id uuid, r_asesor_id uuid, r_codigo_publico character varying, r_activo boolean, r_expira_en timestamp with time zone, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_codigo_id uuid;
  v_codigo varchar(20);
  v_expira_en timestamptz;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  -- opcional: dejar un solo código activo por asesor
  update "AT".codigos_publicos_asesor
     set activo = false
   where asesor_id = v_asesor_id
     and activo = true;

  v_codigo := 'ASE-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));
  v_expira_en := now() + interval '30 days';

  insert into "AT".codigos_publicos_asesor (
    asesor_id,
    codigo_publico,
    activo,
    expira_en,
    creado_en,
    actualizado_en
  )
  values (
    v_asesor_id,
    v_codigo,
    true,
    v_expira_en,
    now(),
    now()
  )
  returning id into v_codigo_id;

  return query
  select
    true,
    v_codigo_id,
    v_asesor_id,
    v_codigo,
    true,
    v_expira_en,
    'Código generado correctamente'::text;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: estudiante_documentos; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".estudiante_documentos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    thesis_id uuid NOT NULL,
    nombre text NOT NULL,
    tipo text NOT NULL,
    url_google_doc text,
    activo boolean DEFAULT true,
    creado_por uuid,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT estudiante_documentos_tipo_check CHECK ((tipo = ANY (ARRAY['reglamento'::text, 'instrumento'::text, 'rubrica'::text, 'criterios'::text, 'formatoAPA'::text, 'Vancouver'::text, 'fuente'::text])))
);


--
-- Name: TABLE estudiante_documentos; Type: COMMENT; Schema: AT; Owner: -
--

COMMENT ON TABLE "AT".estudiante_documentos IS 'Documentos del estudiante: reglamentos, instrumentos, rúbricas, criterios, formatos APA, Vancouver y fuentes';


--
-- Name: COLUMN estudiante_documentos.tipo; Type: COMMENT; Schema: AT; Owner: -
--

COMMENT ON COLUMN "AT".estudiante_documentos.tipo IS 'reglamento|instrumento|rubrica|criterios|formatoAPA|Vancouver|fuente';


--
-- Name: get_documentos_apoyo(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".get_documentos_apoyo(p_tesis_id uuid) RETURNS SETOF "AT".estudiante_documentos
    LANGUAGE sql SECURITY DEFINER
    AS $$
  select ed.*
  from "AT".estudiante_documentos ed
  join "AT".tesis t on t.id = ed.thesis_id
  join "AT".usuarios u on u.id = t.estudiante_id
  where ed.thesis_id = p_tesis_id
    and u.auth_usuario_id = auth.uid()
    and ed.activo = true
  order by ed.creado_en desc;
$$;


--
-- Name: get_estudiante_documentos(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".get_estudiante_documentos(p_tesis_id uuid) RETURNS TABLE(id uuid, nombre text, tipo text, url_google_doc text, creado_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$

declare
usuario_actual uuid;

begin

usuario_actual := "AT".usuario_id();


if not exists (

select 1
from "AT".tesis t
where
t.id = p_tesis_id
and t.estudiante_id = usuario_actual

)

and not exists (

select 1
from "AT".asesores_tesis at
join "AT".relaciones_asesor_estudiante r
on r.id = at.relacion_id

where
at.tesis_id = p_tesis_id
and r.asesor_id = usuario_actual
and at.activo = true

)

then
raise exception 'No autorizado';

end if;


return query

select
ed.id,
ed.nombre,
ed.tipo,
ed.url_google_doc,
ed.creado_en

from "AT".estudiante_documentos ed

where
ed.thesis_id = p_tesis_id
and ed.activo = true

order by ed.creado_en desc;

end;

$$;


--
-- Name: tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    estudiante_id uuid NOT NULL,
    universidad_id uuid,
    titulo text NOT NULL,
    descripcion text,
    estado character varying(20) NOT NULL,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    eliminado_en timestamp with time zone,
    carpeta_drive_id text,
    tipo_tesis_id uuid,
    plan_id uuid,
    programa_id uuid,
    nivel_academico character varying,
    cantidad_variables integer DEFAULT 1,
    requiere_estadistica boolean DEFAULT true,
    es_arquitectura_diseno boolean DEFAULT false,
    precio_base numeric(10,2),
    precio_ajustes numeric(10,2) DEFAULT 0,
    precio_total numeric(10,2),
    moneda character varying DEFAULT 'PEN'::character varying,
    requiere_analisis_estadistico boolean DEFAULT true,
    porcentaje_nivel numeric(5,2),
    monto_ajuste_nivel numeric(10,2),
    descuento_analisis_estadistico numeric(10,2),
    CONSTRAINT tesis_estado_check CHECK (((estado)::text = ANY ((ARRAY['borrador'::character varying, 'pendiente_pago'::character varying, 'en_progreso'::character varying, 'revision'::character varying, 'completado'::character varying, 'cancelado'::character varying])::text[])))
);


--
-- Name: get_mis_tesis(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".get_mis_tesis() RETURNS SETOF "AT".tesis
    LANGUAGE sql SECURITY DEFINER
    AS $$
  select t.*
  from "AT".tesis t
  join "AT".usuarios u on u.id = t.estudiante_id
  where u.auth_usuario_id = auth.uid()
    and t.eliminado_en is null;
$$;


--
-- Name: get_tesis_asesor(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".get_tesis_asesor() RETURNS TABLE(tesis_id uuid, titulo text, descripcion text, estado text, estudiante_id uuid, estudiante_nombre text, documentos json)
    LANGUAGE sql SECURITY DEFINER
    AS $$

select

t.id,
t.titulo,
t.descripcion,
t.estado,
t.estudiante_id,

coalesce(
pe.nombres || ' ' || pe.apellidos,
'Sin nombre'
),

json_agg(
json_build_object(
'id', dt.id,
'nombre_archivo', dt.nombre_archivo,
'version', dt.version,
'estado_revision', dt.estado_revision,
'url_archivo_drive', dt.url_archivo_drive,
'tipo_mime', dt.tipo_mime,
'tamano_bytes', dt.tamano_bytes,
'creado_en', dt.creado_en
)
order by dt.version desc
)

from "AT".asesores_tesis at

join "AT".tesis t
on t.id = at.tesis_id

join "AT".usuarios asesor
on asesor.id = at.asesor_id

left join "AT".perfil_estudiante pe
on pe.estudiante_id = t.estudiante_id

left join "AT".documentos_tesis dt
on dt.tesis_id = t.id

where
asesor.auth_usuario_id = auth.uid()
and at.activo = true
and t.eliminado_en is null

group by
t.id,
pe.nombres,
pe.apellidos;

$$;


--
-- Name: guardar_perfil_asesor(character varying, uuid, character varying, character varying, text, text, uuid, character varying, character varying, character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".guardar_perfil_asesor(p_nombre_mostrar character varying, p_universidad_id uuid, p_slug character varying, p_email_publico character varying, p_biografia text, p_foto_url text, p_especialidad_id uuid, p_carrera character varying, p_nivel_academico character varying, p_nombres character varying, p_apellidos character varying, p_dni character varying, p_telefono character varying DEFAULT NULL::character varying) RETURNS TABLE(r_tiene_informacion boolean, r_asesor_id uuid, r_perfil_id uuid, r_nombre_mostrar character varying, r_universidad_id uuid, r_slug character varying, r_email_publico character varying, r_biografia text, r_foto_url text, r_especialidad_id uuid, r_carrera character varying, r_nivel_academico character varying, r_nombres character varying, r_apellidos character varying, r_dni character varying, r_telefono character varying, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'extensions', 'auth', 'public'
    AS $$

declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_perfil_id uuid;
  v_clave text;

begin

  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;


  select u.id
  into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  and u.rol = 'asesor'
  limit 1;


  if v_asesor_id is null then
    raise exception 'Usuario autenticado no es asesor';
  end if;


  v_clave := "AT".obtener_clave_cifrado_estudiante();

  if v_clave is null then
    raise exception 'Clave de cifrado no encontrada';
  end if;



  insert into "AT".perfil_publico_asesor(
    asesor_id,
    nombre_mostrar,
    universidad_id,
    slug,
    email_publico,
    biografia,
    foto_url,
    especialidad_id,
    carrera,
    nivel_academico
  )

  values(
    v_asesor_id,
    p_nombre_mostrar,
    p_universidad_id,
    p_slug,
    p_email_publico,
    p_biografia,
    p_foto_url,
    p_especialidad_id,
    p_carrera,
    p_nivel_academico
  )

  on conflict on constraint perfil_publico_asesor_asesor_id_key

  do update set
    nombre_mostrar = excluded.nombre_mostrar,
    universidad_id = excluded.universidad_id,
    slug = excluded.slug,
    email_publico = excluded.email_publico,
    biografia = excluded.biografia,
    foto_url = excluded.foto_url,
    especialidad_id = excluded.especialidad_id,
    carrera = excluded.carrera,
    nivel_academico = excluded.nivel_academico,
    actualizado_en = now()

  returning id into v_perfil_id;



  insert into "AT".datos_privados_asesor(
    asesor_id,
    nombres_encriptados,
    apellidos_encriptados,
    dni_encriptado,
    telefono_encriptado
  )

  values(
    v_asesor_id,

    extensions.pgp_sym_encrypt(p_nombres, v_clave)::text,

    extensions.pgp_sym_encrypt(p_apellidos, v_clave)::text,

    extensions.pgp_sym_encrypt(p_dni, v_clave)::text,

    case
      when p_telefono is not null
      then extensions.pgp_sym_encrypt(p_telefono, v_clave)::text
      else null
    end
  )


  on conflict on constraint datos_privados_asesor_asesor_id_key

  do update set
    nombres_encriptados = excluded.nombres_encriptados,
    apellidos_encriptados = excluded.apellidos_encriptados,
    dni_encriptado = excluded.dni_encriptado,
    telefono_encriptado = excluded.telefono_encriptado,
    actualizado_en = now();



  return query

  select

    true,

    p.asesor_id,

    p.id,

    p.nombre_mostrar,

    p.universidad_id,

    p.slug,

    p.email_publico,

    p.biografia,

    p.foto_url,

    p.especialidad_id,

    p.carrera,

    p.nivel_academico,


    extensions.pgp_sym_decrypt(dp.nombres_encriptados::bytea, v_clave)::varchar,

    extensions.pgp_sym_decrypt(dp.apellidos_encriptados::bytea, v_clave)::varchar,

    extensions.pgp_sym_decrypt(dp.dni_encriptado::bytea, v_clave)::varchar,


    case
      when dp.telefono_encriptado is not null
      then extensions.pgp_sym_decrypt(dp.telefono_encriptado::bytea, v_clave)::varchar
      else null
    end,


    'Perfil asesor guardado correctamente'


  from "AT".perfil_publico_asesor p

  left join "AT".datos_privados_asesor dp

  on dp.asesor_id = p.asesor_id

  where p.asesor_id = v_asesor_id;

end;

$$;


--
-- Name: guardar_perfil_estudiante(character varying, character varying, uuid, character varying, character varying, character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".guardar_perfil_estudiante(p_nombres character varying, p_apellidos character varying, p_universidad_id uuid, p_carrera character varying, p_dni character varying, p_telefono character varying DEFAULT NULL::character varying) RETURNS TABLE(r_tiene_informacion boolean, r_estudiante_id uuid, r_perfil_id uuid, r_nombres character varying, r_apellidos character varying, r_universidad_id uuid, r_carrera character varying, r_dni character varying, r_telefono character varying, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'vault', 'extensions', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_perfil_id uuid;
  v_clave text;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no existe como estudiante en AT.usuarios';
  end if;

  v_clave := "AT".obtener_clave_cifrado_estudiante();

  if v_clave is null then
    raise exception 'No se encontró la clave de cifrado';
  end if;

  insert into "AT".perfil_estudiante (
    estudiante_id,
    nombres,
    apellidos,
    universidad_id,
    carrera
  )
  values (
    v_estudiante_id,
    p_nombres,
    p_apellidos,
    p_universidad_id,
    p_carrera
  )
  on conflict on constraint perfil_estudiante_estudiante_id_key
  do update set
    nombres = excluded.nombres,
    apellidos = excluded.apellidos,
    universidad_id = excluded.universidad_id,
    carrera = excluded.carrera,
    actualizado_en = now()
  returning id into v_perfil_id;

  insert into "AT".datos_privados_estudiante (
    estudiante_id,
    dni_encriptado,
    telefono_encriptado
  )
  values (
    v_estudiante_id,
    extensions.pgp_sym_encrypt(p_dni::text, v_clave)::text,
    case
      when p_telefono is not null and length(trim(p_telefono)) > 0
      then extensions.pgp_sym_encrypt(p_telefono::text, v_clave)::text
      else null
    end
  )
  on conflict on constraint datos_privados_estudiante_estudiante_id_key
  do update set
    dni_encriptado = excluded.dni_encriptado,
    telefono_encriptado = excluded.telefono_encriptado,
    actualizado_en = now();

  return query
  select
    true as r_tiene_informacion,
    p.estudiante_id as r_estudiante_id,
    p.id as r_perfil_id,
    p.nombres as r_nombres,
    p.apellidos as r_apellidos,
    p.universidad_id as r_universidad_id,
    p.carrera as r_carrera,
    extensions.pgp_sym_decrypt(dp.dni_encriptado::bytea, v_clave)::varchar as r_dni,
    case
      when dp.telefono_encriptado is not null
      then extensions.pgp_sym_decrypt(dp.telefono_encriptado::bytea, v_clave)::varchar
      else null
    end as r_telefono,
    'Perfil guardado correctamente'::text as r_mensaje
  from "AT".perfil_estudiante p
  left join "AT".datos_privados_estudiante dp
    on dp.estudiante_id = p.estudiante_id
  where p.estudiante_id = v_estudiante_id;

end;
$$;


--
-- Name: guardar_resultado_google_meet(uuid, uuid, text, text, text, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".guardar_resultado_google_meet(p_cola_id uuid, p_reunion_id uuid, p_google_event_id text, p_enlace_reunion text, p_meet_codigo text DEFAULT NULL::text, p_error text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
begin
  if p_error is null then
    update "AT".reuniones_asesor
    set enlace_reunion = p_enlace_reunion,
        google_event_id = p_google_event_id,
        meet_codigo = p_meet_codigo,
        meet_creado_en = now(),
        meet_error = null,
        estado = 'confirmada',
        actualizado_en = now()
    where id = p_reunion_id;

    update "AT".cola_google_meet
    set estado = 'completado',
        error = null,
        actualizado_en = now()
    where id = p_cola_id;
  else
    update "AT".reuniones_asesor
    set meet_error = p_error,
        estado = 'error_meet',
        actualizado_en = now()
    where id = p_reunion_id;

    update "AT".cola_google_meet
    set estado = 'error',
        error = p_error,
        actualizado_en = now()
    where id = p_cola_id;
  end if;
end;
$$;


--
-- Name: listar_historial_observaciones_tesis(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".listar_historial_observaciones_tesis(p_tesis_id uuid) RETURNS TABLE(observacion_id uuid, tesis_id uuid, documento_tesis_id uuid, reunion_id uuid, validation_cita_id uuid, tipo_origen character varying, titulo text, texto text, contenido_html text, contenido_delta jsonb, asesor_id uuid, asesor_nombre character varying, enlace_reunion text, modalidad character varying, lugar text, inicio_reunion timestamp with time zone, fin_reunion timestamp with time zone, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
  select
    o.id as observacion_id,
    o.tesis_id,
    o.documento_tesis_id,
    o.reunion_id,
    o.validation_cita_id,
    o.tipo_origen,
    o.titulo,
    o.texto,
    o.contenido_html,
    o.contenido_delta,
    o.asesor_id,
    ppa.nombre_mostrar as asesor_nombre,
    coalesce(r.enlace_reunion, vc.enlace_reunion) as enlace_reunion,
    coalesce(r.modalidad, vc.modalidad) as modalidad,
    coalesce(r.lugar, vc.lugar) as lugar,
    r.inicio as inicio_reunion,
    r.fin as fin_reunion,
    o.creado_en,
    o.actualizado_en
  from "AT".observaciones_tesis o
  left join "AT".reuniones_asesor r
    on r.id = o.reunion_id
  left join "AT".validation_cita vc
    on vc.id = o.validation_cita_id
  left join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = o.asesor_id
  where o.tesis_id = p_tesis_id
  order by o.creado_en desc;
$$;


--
-- Name: listar_log_validacion_sugerencia(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".listar_log_validacion_sugerencia(p_historial_sugerencia_id uuid) RETURNS TABLE(id uuid, validacion_sugerencia_id uuid, historial_sugerencia_id uuid, tesis_id uuid, documento_tesis_id uuid, usuario_id uuid, usuario_nombre text, rol_usuario character varying, accion character varying, estado_anterior character varying, estado_nuevo character varying, comentario text, metadata jsonb, creado_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
  select
    v.id,
    v.validacion_sugerencia_id,
    v.historial_sugerencia_id,
    v.tesis_id,
    v.documento_tesis_id,
    v.usuario_id,
    v.usuario_nombre,
    v.rol_usuario,
    v.accion,
    v.estado_anterior,
    v.estado_nuevo,
    v.comentario,
    v.metadata,
    v.creado_en
  from "AT".vw_log_validacion_sugerencia v
  where v.historial_sugerencia_id = p_historial_sugerencia_id
  order by v.creado_en asc;
$$;


--
-- Name: listar_sugerencias_tesis(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".listar_sugerencias_tesis(p_tesis_id uuid) RETURNS TABLE(id uuid, tesis_id uuid, documento_tesis_id uuid, asesor_id uuid, asesor_nombre character varying, tipo_sugerencia_id uuid, tipo_codigo character varying, tipo_nombre character varying, detalle text, aplicado boolean, aplicado_por_estudiante boolean, aplicado_en timestamp with time zone, aplicado_por uuid, estado_validacion character varying, verificado_por_asesor boolean, verificado_en timestamp with time zone, comentario_estudiante text, comentario_asesor text, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
  select
    h.id,
    h.tesis_id,
    h.documento_tesis_id,
    h.asesor_id,
    ppa.nombre_mostrar as asesor_nombre,
    h.tipo_sugerencia_id,
    tsa.codigo as tipo_codigo,
    tsa.nombre as tipo_nombre,
    coalesce(h.detalle, h.sugerencia) as detalle,
    coalesce(h.aplicado, false) as aplicado,
    coalesce(h.aplicado_por_estudiante, false) as aplicado_por_estudiante,
    h.aplicado_en,
    h.aplicado_por,
    coalesce(v.estado, 'pendiente') as estado_validacion,
    coalesce(v.verificado_por_asesor, false) as verificado_por_asesor,
    v.verificado_en,
    v.comentario_estudiante,
    v.comentario_asesor,
    h.creado_en,
    greatest(
      h.actualizado_en,
      coalesce(v.actualizado_en, h.actualizado_en)
    ) as actualizado_en
  from "AT".historial_sugerencias_asesor h
  left join "AT".validaciones_sugerencia_asesor v
    on v.historial_sugerencia_id = h.id
  left join "AT".tipos_sugerencia_asesor tsa
    on tsa.id = h.tipo_sugerencia_id
  left join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = h.asesor_id
  where h.tesis_id = p_tesis_id
  order by h.creado_en desc;
$$;


--
-- Name: listar_sugerencias_tesis_validacion(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".listar_sugerencias_tesis_validacion(p_tesis_id uuid) RETURNS TABLE(id uuid, tesis_id uuid, documento_tesis_id uuid, asesor_id uuid, detalle text, aplicado boolean, aplicado_por_estudiante boolean, aplicado_en timestamp with time zone, aplicado_por uuid, estado_validacion character varying, verificado_por_asesor boolean, verificado_en timestamp with time zone, comentario_estudiante text, comentario_asesor text, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
  select
    h.id,
    h.tesis_id,
    h.documento_tesis_id,
    h.asesor_id,
    coalesce(h.detalle, h.sugerencia) as detalle,
    h.aplicado,
    h.aplicado_por_estudiante,
    h.aplicado_en,
    h.aplicado_por,
    coalesce(v.estado, 'pendiente') as estado_validacion,
    coalesce(v.verificado_por_asesor, false) as verificado_por_asesor,
    v.verificado_en,
    v.comentario_estudiante,
    v.comentario_asesor,
    h.creado_en,
    h.actualizado_en
  from "AT".historial_sugerencias_asesor h
  left join "AT".validaciones_sugerencia_asesor v
    on v.historial_sugerencia_id = h.id
  where h.tesis_id = p_tesis_id
  order by h.creado_en desc;
$$;


--
-- Name: listar_tipos_sugerencia_asesor(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".listar_tipos_sugerencia_asesor() RETURNS TABLE(id uuid, codigo character varying, nombre character varying, descripcion text)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
  select
    t.id,
    t.codigo,
    t.nombre,
    t.descripcion
  from "AT".tipos_sugerencia_asesor t
  where coalesce(t.activo, true) = true
  order by t.nombre asc;
$$;


--
-- Name: marcar_sugerencia_aplicada(uuid, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".marcar_sugerencia_aplicada(p_historial_sugerencia_id uuid, p_comentario_estudiante text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_usuario_id uuid;
  v_rol varchar;
  v_sug record;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
    into v_usuario_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id;

  if v_usuario_id is null then
    raise exception 'Usuario no encontrado';
  end if;

  if v_rol <> 'estudiante' then
    raise exception 'Solo un estudiante puede marcar la sugerencia como aplicada';
  end if;

  select h.*
    into v_sug
  from "AT".historial_sugerencias_asesor h
  join "AT".tesis t on t.id = h.tesis_id
  where h.id = p_historial_sugerencia_id
    and t.estudiante_id = v_usuario_id;

  if not found then
    raise exception 'La sugerencia no existe o no pertenece al estudiante';
  end if;

  insert into "AT".validaciones_sugerencia_asesor (
    historial_sugerencia_id,
    tesis_id,
    documento_tesis_id,
    estudiante_id,
    asesor_id,
    marcado_aplicado,
    marcado_en,
    comentario_estudiante,
    estado
  )
  values (
    v_sug.id,
    v_sug.tesis_id,
    v_sug.documento_tesis_id,
    v_usuario_id,
    v_sug.asesor_id,
    true,
    now(),
    p_comentario_estudiante,
    'marcado_por_estudiante'
  )
  on conflict (historial_sugerencia_id)
  do update set
    marcado_aplicado = true,
    marcado_en = now(),
    comentario_estudiante = excluded.comentario_estudiante,
    estado = 'marcado_por_estudiante',
    verificado_por_asesor = false,
    verificado_en = null,
    comentario_asesor = null,
    actualizado_en = now();

  update "AT".historial_sugerencias_asesor
  set aplicado = true,
      aplicado_por_estudiante = true,
      aplicado_en = now(),
      aplicado_por = v_usuario_id,
      actualizado_en = now()
  where id = p_historial_sugerencia_id;

  return jsonb_build_object(
    'ok', true,
    'message', 'Sugerencia marcada como aplicada por el estudiante'
  );
end;
$$;


--
-- Name: marcar_sugerencia_aplicada_estudiante(uuid, boolean); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".marcar_sugerencia_aplicada_estudiante(p_sugerencia_id uuid, p_aplicado boolean) RETURNS TABLE(ok boolean, sugerencia_id uuid, aplicado boolean, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_tesis_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  select h.tesis_id
    into v_tesis_id
  from "AT".historial_sugerencias_asesor h
  join "AT".tesis t on t.id = h.tesis_id
  where h.id = p_sugerencia_id
    and t.estudiante_id = v_estudiante_id
    and t.eliminado_en is null
  limit 1;

  if v_tesis_id is null then
    raise exception 'No se encontró la sugerencia o no tienes permiso';
  end if;

  update "AT".historial_sugerencias_asesor
  set
    aplicado = p_aplicado,
    aplicado_por_estudiante = p_aplicado,
    aplicado_en = case when p_aplicado then now() else null end,
    aplicado_por = case when p_aplicado then v_estudiante_id else null end,
    actualizado_en = now()
  where id = p_sugerencia_id;

  return query
  select
    true,
    p_sugerencia_id,
    p_aplicado,
    case
      when p_aplicado then 'Sugerencia marcada como aplicada por el estudiante'
      else 'Sugerencia marcada como no aplicada'
    end::text;
end;
$$;


--
-- Name: obtener_asesores(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_asesores() RETURNS TABLE(asesor_id uuid, perfil_id uuid, nombre_mostrar character varying, slug character varying, email_publico character varying, biografia text, foto_url text, carrera character varying, nivel_academico character varying, universidad_id uuid, universidad_nombre character varying, especialidad_id uuid, especialidad_nombre character varying)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'AT'
    AS $$
  select
    u.id as asesor_id,
    p.id as perfil_id,
    p.nombre_mostrar,
    p.slug,
    p.email_publico,
    p.biografia,
    p.foto_url,
    p.carrera,
    p.nivel_academico,
    p.universidad_id,
    un.nombre as universidad_nombre,
    p.especialidad_id,
    e.nombre as especialidad_nombre
  from "AT".usuarios u
  inner join "AT".perfil_publico_asesor p
    on p.asesor_id = u.id
  left join "AT".universidades un
    on un.id = p.universidad_id
  left join "AT".especialidades e
    on e.id = p.especialidad_id
  where u.rol = 'asesor'
  order by p.nombre_mostrar asc;
$$;


--
-- Name: obtener_beneficio_disponible_estudiante(uuid, character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_beneficio_disponible_estudiante(p_estudiante_id uuid, p_beneficio_codigo character varying) RETURNS TABLE(suscripcion_id uuid, beneficio_consumo_id uuid, plan_id uuid, plan_nombre character varying, cantidad_total integer, cantidad_usada integer, cantidad_disponible integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
begin
  return query
  select
    se."id" as "suscripcion_id",
    sbc."id" as "beneficio_consumo_id",
    se."plan_id",
    p."nombre" as "plan_nombre",
    sbc."cantidad_total",
    sbc."cantidad_usada",
    greatest(sbc."cantidad_total" - sbc."cantidad_usada", 0) as "cantidad_disponible"
  from "AT"."suscripciones_estudiante" se
  inner join "AT"."planes" p
    on p."id" = se."plan_id"
  inner join "AT"."suscripcion_beneficios_consumo" sbc
    on sbc."suscripcion_id" = se."id"
  inner join "AT"."beneficios_plan_catalogo" b
    on b."id" = sbc."beneficio_id"
  where se."estudiante_id" = p_estudiante_id
    and se."estado" = 'activa'
    and b."codigo" = p_beneficio_codigo
    and greatest(sbc."cantidad_total" - sbc."cantidad_usada", 0) > 0
  order by se."creado_en" desc
  limit 1;
end;
$$;


--
-- Name: obtener_bloques_disponibles_asesor(uuid, date, date); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_bloques_disponibles_asesor(p_asesor_id uuid, p_desde date, p_hasta date) RETURNS TABLE(r_disponibilidad_id uuid, r_asesor_id uuid, r_bloque_inicio timestamp with time zone, r_bloque_fin timestamp with time zone, r_duracion_minutos integer)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'AT'
    AS $$
  with dias as (
    select gs::date as fecha
    from generate_series(p_desde::timestamp, p_hasta::timestamp, interval '1 day') gs
  ),
  base as (
    select
      d.id as disponibilidad_id,
      d.asesor_id,
      dias.fecha,
      d.inicio,
      d.fin,
      d.usa_bloques,
      d.duracion_bloque_minutos,
      d.recurrente,
      d.dia_semana,
      d.fecha_inicio,
      d.fecha_fin
    from "AT".disponibilidad_asesor d
    join dias on (
      (
        d.recurrente = false
        and d.inicio::date = dias.fecha
      )
      or
      (
        d.recurrente = true
        and (d.fecha_inicio is null or dias.fecha >= d.fecha_inicio)
        and (d.fecha_fin is null or dias.fecha <= d.fecha_fin)
        and extract(dow from dias.fecha)::int = d.dia_semana
      )
    )
    where d.asesor_id = p_asesor_id
      and d.disponible = true
      and d.activo = true
  ),
  rangos as (
    select
      b.disponibilidad_id,
      b.asesor_id,
      (b.fecha + (b.inicio::time))::timestamptz as rango_inicio,
      (b.fecha + (b.fin::time))::timestamptz as rango_fin,
      b.duracion_bloque_minutos
    from base b
  )
  select
    r.disponibilidad_id,
    r.asesor_id,
    gs as bloque_inicio,
    gs + make_interval(mins => r.duracion_bloque_minutos) as bloque_fin,
    r.duracion_bloque_minutos
  from rangos r
  cross join lateral generate_series(
    r.rango_inicio,
    r.rango_fin - make_interval(mins => r.duracion_bloque_minutos),
    make_interval(mins => r.duracion_bloque_minutos)
  ) gs
  where not exists (
    select 1
    from "AT".reuniones_asesor ra
    where ra.asesor_id = r.asesor_id
      and ra.estado in ('pendiente','confirmado','completado')
      and gs < ra.fin
      and (gs + make_interval(mins => r.duracion_bloque_minutos)) > ra.inicio
  )
  order by bloque_inicio asc;
$$;


--
-- Name: obtener_clave_cifrado_estudiante(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_clave_cifrado_estudiante() RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'vault', 'AT'
    AS $$
  select decrypted_secret
  from vault.decrypted_secrets
  where name = 'at_estudiante_crypto_key'
  limit 1;
$$;


--
-- Name: obtener_detalle_cita_estudiante(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_detalle_cita_estudiante(p_reunion_id uuid) RETURNS TABLE(reunion_id uuid, asesor_id uuid, asesor_nombre character varying, asesor_foto_url text, inicio timestamp with time zone, fin timestamp with time zone, estado_reunion character varying, modalidad character varying, lugar text, enlace_reunion text, motivo text, notas text, pago_id uuid, estado_pago character varying, monto_pago numeric, codigo_operacion character varying, tesis_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
  into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  return query
  select
    r.id,
    r.asesor_id,
    ppa.nombre_mostrar,
    ppa.foto_url,
    r.inicio,
    r.fin,
    r.estado,
    r.modalidad,
    r.lugar,
    r.enlace_reunion,
    r.motivo,
    r.notas,
    p.id as pago_id,
    p.estado as estado_pago,
    p.monto as monto_pago,
    p.codigo_operacion,
    r.tesis_id
  from "AT".reuniones_asesor r
  left join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = r.asesor_id
  left join "AT".pagos p
    on p.id = r.pago_id
  where r.id = p_reunion_id
    and r.estudiante_id = v_estudiante_id
  limit 1;
end;
$$;


--
-- Name: obtener_documentos_mi_tesis(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_documentos_mi_tesis(p_tesis_id uuid) RETURNS TABLE(id uuid, tesis_id uuid, nombre text, tipo text, url_google_doc text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
select
    d.id,
    d.tesis_id,
    d.nombre_archivo as nombre,
    d.tipo_mime as tipo,
    concat('https://drive.google.com/uc?id=', d.documento_drive_id) as url_google_doc
from "AT".documentos_tesis d
where d.tesis_id = p_tesis_id
union all
select
    e.id,
    e.thesis_id,
    e.nombre,
    e.tipo,
    e.url_google_doc
from "AT".estudiante_documentos e
where e.thesis_id = p_tesis_id;
$$;


--
-- Name: obtener_documentos_tesis_asignada(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_documentos_tesis_asignada(p_tesis_id uuid) RETURNS TABLE(documento_id uuid, tesis_id uuid, nombre_archivo character varying, url_archivo_drive text, documento_drive_id text, version integer, estado_revision character varying, comentario_revision text, ruta_storage text, tipo_mime character varying, tamano_bytes bigint, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  if not exists (
    select 1
    from "AT".asesores_tesis at
    where at.tesis_id = p_tesis_id
      and at.asesor_id = v_asesor_id
      and coalesce(at.activo, true) = true
  ) then
    raise exception 'No tienes acceso a esta tesis';
  end if;

  return query
  select
    d.id,
    d.tesis_id,
    d.nombre_archivo,
    d.url_archivo_drive,
    d.documento_drive_id,
    d.version,
    d.estado_revision,
    d.comentario_revision,
    d.ruta_storage,
    d.tipo_mime,
    d.tamano_bytes,
    d.creado_en,
    d.actualizado_en
  from "AT".documentos_tesis d
  where d.tesis_id = p_tesis_id
  order by d.creado_en desc;
end;
$$;


--
-- Name: obtener_estudiantes_asesor(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_estudiantes_asesor() RETURNS TABLE(r_relacion_id uuid, r_estudiante_id uuid, r_nombres character varying, r_apellidos character varying, r_universidad_id uuid, r_carrera character varying, r_estado_relacion character varying, r_creado_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$

declare
  v_auth_user_id uuid;
  v_asesor_id uuid;

begin

  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;


  select id
  into v_asesor_id
  from "AT".usuarios
  where auth_usuario_id = v_auth_user_id
  and rol = 'asesor'
  limit 1;


  if v_asesor_id is null then
    raise exception 'Usuario no es asesor';
  end if;


  return query

  select

    r.id,
    r.estudiante_id,

    p.nombres,
    p.apellidos,
    p.universidad_id,
    p.carrera,

    r.estado,
    r.creado_en

  from "AT".relaciones_asesor_estudiante r

  left join "AT".perfil_estudiante p
  on p.estudiante_id = r.estudiante_id

  where r.asesor_id = v_asesor_id

  order by r.creado_en desc;


end;

$$;


--
-- Name: obtener_estudiantes_mis_asesorias(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_estudiantes_mis_asesorias() RETURNS TABLE(r_relacion_id uuid, r_estudiante_id uuid, r_nombres character varying, r_apellidos character varying, r_tesis_id uuid, r_tesis_titulo text, r_tesis_estado character varying, r_reunion_id uuid, r_reunion_estado character varying, r_reunion_inicio timestamp with time zone, r_estado_relacion character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$

declare
  v_auth_user_id uuid;
  v_asesor_id uuid;

begin


  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;



  select id
  into v_asesor_id
  from "AT".usuarios
  where auth_usuario_id = v_auth_user_id
  and rol = 'asesor'
  limit 1;



  if v_asesor_id is null then
    raise exception 'Usuario no es asesor';
  end if;



  return query

  select

    r.id,
    r.estudiante_id,

    p.nombres,
    p.apellidos,

    t.id,
    t.titulo,
    t.estado,

    re.id,
    re.estado,
    re.inicio,

    r.estado

  from "AT".relaciones_asesor_estudiante r

  left join "AT".perfil_estudiante p
  on p.estudiante_id = r.estudiante_id

  left join "AT".tesis t
  on t.estudiante_id = r.estudiante_id
  and t.eliminado_en is null

  left join lateral (

    select *

    from "AT".reuniones_asesor re2

    where re2.estudiante_id = r.estudiante_id
    and re2.asesor_id = v_asesor_id

    order by re2.inicio desc

    limit 1

  ) re on true


  where r.asesor_id = v_asesor_id

  order by r.creado_en desc;


end;

$$;


--
-- Name: obtener_historial_validaciones_cita_asesor(character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_historial_validaciones_cita_asesor(p_status character varying DEFAULT NULL::character varying) RETURNS TABLE(validation_cita_id uuid, estudiante_id uuid, estudiante_nombre text, tesis_id uuid, tesis_titulo text, disponibilidad_id uuid, status character varying, reservation_date date, start_at timestamp with time zone, end_at timestamp with time zone, duration_minutes integer, motivo text, modalidad character varying, lugar text, enlace_reunion text, notas text, payment_id uuid, meeting_id uuid, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
  into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  return query
  select
    vc.id as validation_cita_id,
    vc.user_id as estudiante_id,
    trim(coalesce(pe.nombres, '') || ' ' || coalesce(pe.apellidos, '')) as estudiante_nombre,
    vc.tesis_id,
    t.titulo as tesis_titulo,
    vc.disponibilidad_id,
    vc.status,
    vc.reservation_date,
    vc.start_at,
    vc.end_at,
    vc.duration_minutes,
    vc.motivo,
    vc.modalidad,
    vc.lugar,
    vc.enlace_reunion,
    vc.notas,
    vc.payment_id,
    vc.meeting_id,
    vc.created_at,
    vc.updated_at
  from "AT".validation_cita vc
  left join "AT".perfil_estudiante pe
    on pe.estudiante_id = vc.user_id
  left join "AT".tesis t
    on t.id = vc.tesis_id
  where vc.advisor_id = v_asesor_id
    and (p_status is null or vc.status = p_status)
  order by vc.created_at desc;
end;
$$;


--
-- Name: obtener_historial_validaciones_cita_estudiante(character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_historial_validaciones_cita_estudiante(p_status character varying DEFAULT NULL::character varying) RETURNS TABLE(validation_cita_id uuid, asesor_id uuid, asesor_nombre text, tesis_id uuid, tesis_titulo text, disponibilidad_id uuid, status character varying, reservation_date date, start_at timestamp with time zone, end_at timestamp with time zone, duration_minutes integer, motivo text, modalidad character varying, lugar text, enlace_reunion text, notas text, payment_id uuid, meeting_id uuid, created_at timestamp with time zone, updated_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
  into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  return query
  select
    vc.id as validation_cita_id,
    vc.advisor_id as asesor_id,
    ppa.nombre_mostrar::text as asesor_nombre,
    vc.tesis_id,
    t.titulo as tesis_titulo,
    vc.disponibilidad_id,
    vc.status,
    vc.reservation_date,
    vc.start_at,
    vc.end_at,
    vc.duration_minutes,
    vc.motivo,
    vc.modalidad,
    vc.lugar,
    vc.enlace_reunion,
    vc.notas,
    vc.payment_id,
    vc.meeting_id,
    vc.created_at,
    vc.updated_at
  from "AT".validation_cita vc
  left join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = vc.advisor_id
  left join "AT".tesis t
    on t.id = vc.tesis_id
  where vc.user_id = v_estudiante_id
    and (p_status is null or vc.status = p_status)
  order by vc.created_at desc;
end;
$$;


--
-- Name: obtener_horarios_disponibles_asesor(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_horarios_disponibles_asesor(p_asesor_id uuid) RETURNS TABLE(disponibilidad_id uuid, asesor_id uuid, inicio_bloque timestamp with time zone, fin_bloque timestamp with time zone, duracion_minutos integer, estado text, reunion_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_relacion_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  select r.id
    into v_relacion_id
  from "AT".relaciones_asesor_estudiante r
  where r.asesor_id = p_asesor_id
    and r.estudiante_id = v_estudiante_id
    and r.estado = 'activo'
  limit 1;

  if v_relacion_id is null then
    raise exception 'No tienes una relación activa con este asesor';
  end if;

  return query
  with disponibilidades_base as (
    select
      d.id as disponibilidad_id,
      d.asesor_id,
      d.inicio,
      d.fin,
      d.recurrente,
      d.dia_semana,
      d.fecha_inicio,
      d.fecha_fin,
      coalesce(d.duracion_bloque_minutos, 30) as duracion_bloque_minutos,
      coalesce(d.usa_bloques, true) as usa_bloques
    from "AT".disponibilidad_asesor d
    where d.asesor_id = p_asesor_id
      and coalesce(d.activo, true) = true
      and coalesce(d.disponible, true) = true
  ),

  disponibilidades_unicas as (
    select
      db.disponibilidad_id,
      db.asesor_id,
      db.inicio as inicio_real,
      db.fin as fin_real,
      db.duracion_bloque_minutos,
      db.usa_bloques
    from disponibilidades_base db
    where coalesce(db.recurrente, false) = false
      and db.fin > now()
  ),

  fechas_recurrentes as (
    select
      db.disponibilidad_id,
      db.asesor_id,
      gs::date as fecha_slot,
      db.inicio::time as hora_inicio,
      db.fin::time as hora_fin,
      db.duracion_bloque_minutos,
      db.usa_bloques
    from disponibilidades_base db
    cross join lateral generate_series(
      db.fecha_inicio::timestamp,
      db.fecha_fin::timestamp,
      interval '1 day'
    ) gs
    where coalesce(db.recurrente, false) = true
      and db.fecha_inicio is not null
      and db.fecha_fin is not null
      and db.dia_semana is not null
      and extract(isodow from gs) = db.dia_semana
  ),

  disponibilidades_recurrentes as (
    select
      fr.disponibilidad_id,
      fr.asesor_id,
      (fr.fecha_slot + fr.hora_inicio)::timestamptz as inicio_real,
      case
        when fr.hora_fin > fr.hora_inicio
          then (fr.fecha_slot + fr.hora_fin)::timestamptz
        else ((fr.fecha_slot + interval '1 day') + fr.hora_fin)::timestamptz
      end as fin_real,
      fr.duracion_bloque_minutos,
      fr.usa_bloques
    from fechas_recurrentes fr
    where (
      case
        when fr.hora_fin > fr.hora_inicio
          then (fr.fecha_slot + fr.hora_fin)::timestamptz
        else ((fr.fecha_slot + interval '1 day') + fr.hora_fin)::timestamptz
      end
    ) > now()
  ),

  disponibilidades_expandidas as (
    select * from disponibilidades_unicas
    union all
    select * from disponibilidades_recurrentes
  ),

  bloques as (
    select
      de.disponibilidad_id,
      de.asesor_id,
      case
        when de.usa_bloques then gs
        else de.inicio_real
      end as inicio_bloque,
      case
        when de.usa_bloques then gs + make_interval(mins => de.duracion_bloque_minutos)
        else de.fin_real
      end as fin_bloque,
      case
        when de.usa_bloques then de.duracion_bloque_minutos
        else extract(epoch from (de.fin_real - de.inicio_real))::int / 60
      end as duracion_minutos
    from disponibilidades_expandidas de
    cross join lateral (
      select gs
      from generate_series(
        de.inicio_real,
        case
          when de.usa_bloques then de.fin_real - make_interval(mins => de.duracion_bloque_minutos)
          else de.inicio_real
        end,
        case
          when de.usa_bloques then make_interval(mins => de.duracion_bloque_minutos)
          else interval '1 day'
        end
      ) gs
    ) s
  ),

  bloques_con_estado as (
    select
      b.disponibilidad_id,
      b.asesor_id,
      b.inicio_bloque,
      b.fin_bloque,
      b.duracion_minutos,
      r.id as reunion_id,
      case
        when r.id is not null then 'ocupado'
        else 'libre'
      end as estado
    from bloques b
    left join lateral (
      select r.id
      from "AT".reuniones_asesor r
      where r.asesor_id = p_asesor_id
        and r.estado in ('pendiente_pago', 'pendiente', 'confirmada')
        and tstzrange(r.inicio, r.fin, '[)') && tstzrange(b.inicio_bloque, b.fin_bloque, '[)')
      limit 1
    ) r on true
  )

  select
    bce.disponibilidad_id,
    bce.asesor_id,
    bce.inicio_bloque,
    bce.fin_bloque,
    bce.duracion_minutos,
    bce.estado,
    bce.reunion_id
  from bloques_con_estado bce
  order by bce.inicio_bloque asc;

end;
$$;


--
-- Name: obtener_horarios_libres_asesor(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_horarios_libres_asesor(p_asesor_id uuid) RETURNS TABLE(disponibilidad_id uuid, asesor_id uuid, inicio_bloque timestamp with time zone, fin_bloque timestamp with time zone, duracion_minutos integer)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
  select
    disponibilidad_id,
    asesor_id,
    inicio_bloque,
    fin_bloque,
    duracion_minutos
  from "AT".obtener_horarios_disponibles_asesor(p_asesor_id)
  where estado = 'libre'
  order by inicio_bloque asc;
$$;


--
-- Name: obtener_horarios_presustentacion_asesor(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_horarios_presustentacion_asesor(p_asesor_id uuid) RETURNS TABLE(disponibilidad_id uuid, asesor_id uuid, inicio_bloque timestamp with time zone, fin_bloque timestamp with time zone, duracion_minutos integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  return query
  with disponibilidades as (
    select
      d.id as disponibilidad_id,
      d.asesor_id,
      d.inicio,
      d.fin,
      coalesce(d.duracion_bloque_minutos, 30) as duracion_bloque_minutos
    from "AT".disponibilidad_asesor d
    where d.asesor_id = p_asesor_id
      and coalesce(d.activo, true) = true
      and coalesce(d.disponible, true) = true
      and d.fin > now()
  ),
  bloques as (
    select
      d.disponibilidad_id,
      d.asesor_id,
      gs as inicio_bloque,
      gs + make_interval(mins => d.duracion_bloque_minutos) as fin_bloque,
      d.duracion_bloque_minutos as duracion_minutos
    from disponibilidades d
    cross join lateral generate_series(
      d.inicio,
      d.fin - make_interval(mins => d.duracion_bloque_minutos),
      make_interval(mins => d.duracion_bloque_minutos)
    ) gs
  )
  select
    b.disponibilidad_id,
    b.asesor_id,
    b.inicio_bloque,
    b.fin_bloque,
    b.duracion_minutos
  from bloques b
  where not exists (
    select 1
    from "AT".reuniones_asesor r
    where r.asesor_id = b.asesor_id
      and r.estado in ('pendiente', 'confirmado')
      and tstzrange(r.inicio, r.fin, '[)') && tstzrange(b.inicio_bloque, b.fin_bloque, '[)')
  )
  order by b.inicio_bloque asc;
end;
$$;


--
-- Name: obtener_horarios_presustentacion_asesor(uuid, date, date); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_horarios_presustentacion_asesor(p_asesor_id uuid, p_fecha_desde date, p_fecha_hasta date) RETURNS TABLE(disponibilidad_id uuid, asesor_id uuid, inicio_bloque timestamp with time zone, fin_bloque timestamp with time zone, duracion_minutos integer, estado text, reunion_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  if p_fecha_desde is null or p_fecha_hasta is null then
    raise exception 'Debe indicar p_fecha_desde y p_fecha_hasta';
  end if;

  if p_fecha_hasta < p_fecha_desde then
    raise exception 'p_fecha_hasta debe ser mayor o igual a p_fecha_desde';
  end if;

  return query
  with disponibilidades_base as (
    select
      d.id as disponibilidad_id,
      d.asesor_id,
      d.inicio,
      d.fin,
      coalesce(d.usa_bloques, true) as usa_bloques,
      coalesce(d.duracion_bloque_minutos, 30) as duracion_bloque_minutos,
      coalesce(d.recurrente, false) as recurrente,
      d.dia_semana,
      d.fecha_inicio,
      d.fecha_fin
    from "AT".disponibilidad_asesor d
    where d.asesor_id = p_asesor_id
      and coalesce(d.activo, true) = true
      and coalesce(d.disponible, true) = true
  ),

  unicas as (
    select
      db.disponibilidad_id,
      db.asesor_id,
      db.inicio as inicio_real,
      db.fin as fin_real,
      db.usa_bloques,
      db.duracion_bloque_minutos
    from disponibilidades_base db
    where db.recurrente = false
      and db.inicio::date between p_fecha_desde and p_fecha_hasta
      and db.fin > now()
  ),

  fechas_recurrentes as (
    select
      db.disponibilidad_id,
      db.asesor_id,
      gs::date as fecha_slot,
      db.inicio::time as hora_inicio,
      db.fin::time as hora_fin,
      db.usa_bloques,
      db.duracion_bloque_minutos
    from disponibilidades_base db
    cross join lateral generate_series(
      greatest(db.fecha_inicio, p_fecha_desde)::timestamp,
      least(db.fecha_fin, p_fecha_hasta)::timestamp,
      interval '1 day'
    ) gs
    where db.recurrente = true
      and db.fecha_inicio is not null
      and db.fecha_fin is not null
      and db.dia_semana is not null
      and greatest(db.fecha_inicio, p_fecha_desde) <= least(db.fecha_fin, p_fecha_hasta)
      and extract(isodow from gs) = db.dia_semana
  ),

  recurrentes as (
    select
      fr.disponibilidad_id,
      fr.asesor_id,
      (fr.fecha_slot + fr.hora_inicio)::timestamptz as inicio_real,
      case
        when fr.hora_fin > fr.hora_inicio
          then (fr.fecha_slot + fr.hora_fin)::timestamptz
        else ((fr.fecha_slot + interval '1 day') + fr.hora_fin)::timestamptz
      end as fin_real,
      fr.usa_bloques,
      fr.duracion_bloque_minutos
    from fechas_recurrentes fr
  ),

  expansiones as (
    select * from unicas
    union all
    select * from recurrentes
  ),

  bloques as (
    select
      e.disponibilidad_id,
      e.asesor_id,
      case
        when e.usa_bloques then gs
        else e.inicio_real
      end as inicio_bloque,
      case
        when e.usa_bloques then gs + make_interval(mins => e.duracion_bloque_minutos)
        else e.fin_real
      end as fin_bloque,
      case
        when e.usa_bloques then e.duracion_bloque_minutos
        else extract(epoch from (e.fin_real - e.inicio_real))::int / 60
      end as duracion_minutos
    from expansiones e
    cross join lateral (
      select gs
      from generate_series(
        e.inicio_real,
        case
          when e.usa_bloques then e.fin_real - make_interval(mins => e.duracion_bloque_minutos)
          else e.inicio_real
        end,
        case
          when e.usa_bloques then make_interval(mins => e.duracion_bloque_minutos)
          else interval '1 day'
        end
      ) gs
    ) s
    where e.fin_real > now()
  ),

  bloques_con_estado as (
    select
      b.disponibilidad_id,
      b.asesor_id,
      b.inicio_bloque,
      b.fin_bloque,
      b.duracion_minutos,
      r.id as reunion_id,
      case
        when r.id is not null then 'ocupado'
        else 'libre'
      end as estado
    from bloques b
    left join lateral (
      select r.id
      from "AT".reuniones_asesor r
      where r.asesor_id = b.asesor_id
        and r.estado in ('pendiente', 'confirmado', 'confirmada', 'pendiente_pago')
        and tstzrange(r.inicio, r.fin, '[)') && tstzrange(b.inicio_bloque, b.fin_bloque, '[)')
      limit 1
    ) r on true
  )

  select
    bce.disponibilidad_id,
    bce.asesor_id,
    bce.inicio_bloque,
    bce.fin_bloque,
    bce.duracion_minutos,
    bce.estado,
    bce.reunion_id
  from bloques_con_estado bce
  order by bce.inicio_bloque asc;
end;
$$;


--
-- Name: obtener_mi_codigo_publico_asesor(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mi_codigo_publico_asesor() RETURNS TABLE(r_codigo_id uuid, r_codigo_publico character varying, r_activo boolean, r_expira_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
  select
    c.id,
    c.codigo_publico,
    c.activo,
    c.expira_en
  from "AT".codigos_publicos_asesor c
  join "AT".usuarios u
    on u.id = c.asesor_id
  where u.auth_usuario_id = auth.uid()
    and u.rol = 'asesor'
    and c.activo = true
  order by c.creado_en desc
  limit 1;
$$;


--
-- Name: obtener_mi_rol(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mi_rol() RETURNS TABLE(usuario_id uuid, auth_usuario_id uuid, rol character varying, verificado boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
declare
  v_auth_user_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  return query
  select
    u.id,
    u.auth_usuario_id,
    u.rol,
    coalesce(u.verificado, false)
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  limit 1;
end;
$$;


--
-- Name: obtener_mi_suscripcion(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mi_suscripcion() RETURNS TABLE(id uuid, estudiante_id uuid, plan_id uuid, estado character varying, asesorias_incluidas integer, asesorias_usadas integer, asesorias_disponibles integer, iniciado_en timestamp with time zone, expira_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'at', 'public'
    AS $$
  select
    s.id,
    s.estudiante_id,
    s.plan_id,
    s.estado,
    s.asesorias_incluidas,
    s.asesorias_usadas,
    greatest(s.asesorias_incluidas - s.asesorias_usadas, 0),
    s.iniciado_en,
    s.expira_en
  from "AT".suscripciones_estudiante s
  where s.estudiante_id = (
    select u.id
    from "AT".usuarios u
    where u.auth_usuario_id = auth.uid()
  )
    and s.estado = 'activo'
  order by s.creado_en desc
  limit 1;
$$;


--
-- Name: obtener_mi_tesis(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mi_tesis() RETURNS SETOF "AT".tesis
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
  select t.*
  from "AT".tesis t
  join "AT".usuarios u
    on u.id = t.estudiante_id
  where u.auth_usuario_id = auth.uid()
    and u.rol = 'estudiante'
  order by t.creado_en desc;
$$;


--
-- Name: obtener_mis_asesores(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mis_asesores() RETURNS TABLE(relacion_id uuid, asesor_id uuid, nombre_mostrar character varying, foto_url text, carrera character varying, tiene_tesis boolean)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
  select
    r.id as relacion_id,
    r.asesor_id,
    ppa.nombre_mostrar,
    ppa.foto_url,
    ppa.carrera,
    exists (
      select 1
      from "AT".asesores_tesis atx
      where atx.relacion_id = r.id
        and atx.activo = true
    ) as tiene_tesis
  from "AT".relaciones_asesor_estudiante r
  join "AT".usuarios u
    on u.id = r.estudiante_id
  join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = r.asesor_id
  where u.auth_usuario_id = auth.uid()
    and r.estado = 'activo';
$$;


--
-- Name: obtener_mis_citas_asesor(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mis_citas_asesor() RETURNS TABLE(r_reunion_id uuid, r_estado character varying, r_inicio timestamp with time zone, r_fin timestamp with time zone, r_modalidad character varying, r_costo_reunion numeric, r_pago_id uuid, r_estudiante_id uuid)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
  select
    r.id,
    r.estado,
    r.inicio,
    r.fin,
    r.modalidad,
    r.costo_reunion,
    r.pago_id,
    r.estudiante_id
  from "AT".reuniones_asesor r
  join "AT".usuarios u
    on u.id = r.asesor_id
  where u.auth_usuario_id = auth.uid()
    and u.rol = 'asesor'
  order by r.inicio asc;
$$;


--
-- Name: obtener_mis_citas_estudiante(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mis_citas_estudiante() RETURNS TABLE(r_reunion_id uuid, r_estado character varying, r_inicio timestamp with time zone, r_fin timestamp with time zone, r_modalidad character varying, r_costo_reunion numeric, r_pago_id uuid, r_asesor_id uuid)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
  select
    r.id,
    r.estado,
    r.inicio,
    r.fin,
    r.modalidad,
    r.costo_reunion,
    r.pago_id,
    r.asesor_id
  from "AT".reuniones_asesor r
  join "AT".usuarios u
    on u.id = r.estudiante_id
  where u.auth_usuario_id = auth.uid()
    and u.rol = 'estudiante'
  order by r.inicio asc;
$$;


--
-- Name: obtener_mis_citas_estudiante(timestamp with time zone, timestamp with time zone); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mis_citas_estudiante(p_fecha_inicio timestamp with time zone DEFAULT NULL::timestamp with time zone, p_fecha_fin timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS TABLE(reunion_id uuid, asesor_id uuid, asesor_nombre character varying, inicio timestamp with time zone, fin timestamp with time zone, estado character varying, modalidad character varying, lugar text, enlace_reunion text, pago_id uuid, tesis_id uuid)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
  into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  return query
  select
    r.id as reunion_id,
    r.asesor_id,
    ppa.nombre_mostrar as asesor_nombre,
    r.inicio,
    r.fin,
    r.estado,
    r.modalidad,
    r.lugar,
    r.enlace_reunion,
    r.pago_id,
    r.tesis_id
  from "AT".reuniones_asesor r
  left join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = r.asesor_id
  where r.estudiante_id = v_estudiante_id
    and (p_fecha_inicio is null or r.inicio >= p_fecha_inicio)
    and (p_fecha_fin is null or r.inicio < p_fecha_fin)
  order by r.inicio asc;
end;
$$;


--
-- Name: obtener_mis_espacios_libres_asesor(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mis_espacios_libres_asesor() RETURNS TABLE(disponibilidad_id uuid, asesor_id uuid, inicio timestamp with time zone, fin timestamp with time zone, usa_bloques boolean, duracion_bloque_minutos integer, recurrente boolean, dia_semana integer, fecha_inicio date, fecha_fin date, disponible boolean, activo boolean, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  return query
  select
    d.id as disponibilidad_id,
    d.asesor_id,
    d.inicio,
    d.fin,
    coalesce(d.usa_bloques, true) as usa_bloques,
    coalesce(d.duracion_bloque_minutos, 30) as duracion_bloque_minutos,
    coalesce(d.recurrente, false) as recurrente,
    d.dia_semana,
    d.fecha_inicio,
    d.fecha_fin,
    coalesce(d.disponible, true) as disponible,
    coalesce(d.activo, true) as activo,
    d.creado_en,
    d.actualizado_en
  from "AT".disponibilidad_asesor d
  where d.asesor_id = v_asesor_id
  order by d.inicio asc;
end;
$$;


--
-- Name: obtener_mis_pagos_estudiante(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mis_pagos_estudiante() RETURNS TABLE(pago_id uuid, concepto character varying, monto numeric, estado_pago character varying, codigo_operacion character varying, documento_drive_id text, url_archivo_drive text, nombre_archivo_voucher text, tipo_mime_voucher character varying, tamano_bytes_voucher bigint, subido_en timestamp with time zone, creado_en timestamp with time zone, actualizado_en timestamp with time zone, reunion_id uuid, estado_reunion character varying, asesor_id uuid, asesor_nombre character varying, inicio_reunion timestamp with time zone, fin_reunion timestamp with time zone, moneda character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  return query
  select
    p.id as pago_id,
    p.concepto,
    p.monto,
    p.estado as estado_pago,
    p.codigo_operacion,
    p.documento_drive_id,
    p.url_archivo_drive,
    p.nombre_archivo_voucher,
    p.tipo_mime_voucher,
    p.tamano_bytes_voucher,
    p.subido_en,
    p.creado_en,
    p.actualizado_en,
    r.id as reunion_id,
    r.estado as estado_reunion,
    r.asesor_id,
    ppa.nombre_mostrar as asesor_nombre,
    r.inicio as inicio_reunion,
    r.fin as fin_reunion,
    r.moneda
  from "AT".pagos p
  left join "AT".reuniones_asesor r
    on r.pago_id = p.id
  left join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = r.asesor_id
  where p.pagador_id = v_estudiante_id
  order by p.creado_en desc;
end;
$$;


--
-- Name: obtener_mis_tesis(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mis_tesis() RETURNS SETOF "AT".tesis
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
  select t.*
  from "AT".tesis t
  join "AT".usuarios u
    on u.id = t.estudiante_id
  where u.auth_usuario_id = auth.uid()
    and u.rol = 'estudiante'
    and t.eliminado_en is null
  order by t.creado_en desc;
$$;


--
-- Name: obtener_mis_tesis_con_asesores(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_mis_tesis_con_asesores() RETURNS TABLE(tesis_id uuid, tesis_titulo text, asesor_id uuid, asesor_nombre character varying, relacion_id uuid, asesor_tesis_id uuid, rol character varying, activo boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  return query
  select
    t.id as tesis_id,
    t.titulo as tesis_titulo,
    at.asesor_id,
    ppa.nombre_mostrar as asesor_nombre,
    at.relacion_id,
    at.id as asesor_tesis_id,
    at.rol,
    coalesce(at.activo, true) as activo
  from "AT".tesis t
  join "AT".asesores_tesis at
    on at.tesis_id = t.id
  left join "AT".perfil_publico_asesor ppa
    on ppa.asesor_id = at.asesor_id
  where t.estudiante_id = v_estudiante_id
    and t.eliminado_en is null
    and coalesce(at.activo, true) = true
  order by t.creado_en desc, at.creado_en desc;
end;
$$;


--
-- Name: obtener_pagos_pendientes_revision(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_pagos_pendientes_revision() RETURNS TABLE(pago_id uuid, pagador_id uuid, concepto character varying, monto numeric, estado character varying, codigo_operacion character varying, url_archivo_drive text, nombre_archivo_voucher text, creado_en timestamp with time zone, subido_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_admin_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_admin_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'admin'
  limit 1;

  if v_admin_id is null then
    raise exception 'El usuario autenticado no es un administrador válido';
  end if;

  return query
  select
    p.id,
    p.pagador_id,
    p.concepto,
    p.monto,
    p.estado,
    p.codigo_operacion,
    p.url_archivo_drive,
    p.nombre_archivo_voucher,
    p.creado_en,
    p.subido_en
  from "AT".pagos p
  where p.estado in ('voucher_subido')
  order by p.subido_en desc nulls last, p.creado_en desc;
end;
$$;


--
-- Name: obtener_perfil_estudiante(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_perfil_estudiante() RETURNS TABLE(r_tiene_informacion boolean, r_estudiante_id uuid, r_perfil_id uuid, r_nombres character varying, r_apellidos character varying, r_universidad_id uuid, r_carrera character varying, r_dni character varying, r_telefono character varying, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'vault', 'extensions', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_clave text;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no existe como estudiante en AT.usuarios';
  end if;

  if not exists (
    select 1
    from "AT".perfil_estudiante p
    where p.estudiante_id = v_estudiante_id
  ) then
    return query
    select
      false as r_tiene_informacion,
      v_estudiante_id as r_estudiante_id,
      null::uuid as r_perfil_id,
      null::varchar as r_nombres,
      null::varchar as r_apellidos,
      null::uuid as r_universidad_id,
      null::varchar as r_carrera,
      null::varchar as r_dni,
      null::varchar as r_telefono,
      'No tiene información aún'::text as r_mensaje;
    return;
  end if;

  v_clave := "AT".obtener_clave_cifrado_estudiante();

  if v_clave is null then
    raise exception 'No se encontró la clave de cifrado';
  end if;

  return query
  select
    true as r_tiene_informacion,
    p.estudiante_id as r_estudiante_id,
    p.id as r_perfil_id,
    p.nombres as r_nombres,
    p.apellidos as r_apellidos,
    p.universidad_id as r_universidad_id,
    p.carrera as r_carrera,
    extensions.pgp_sym_decrypt(dp.dni_encriptado::bytea, v_clave)::varchar as r_dni,
    case
      when dp.telefono_encriptado is not null
      then extensions.pgp_sym_decrypt(dp.telefono_encriptado::bytea, v_clave)::varchar
      else null
    end as r_telefono,
    'Perfil obtenido correctamente'::text as r_mensaje
  from "AT".perfil_estudiante p
  left join "AT".datos_privados_estudiante dp
    on dp.estudiante_id = p.estudiante_id
  where p.estudiante_id = v_estudiante_id;

end;
$$;


--
-- Name: obtener_perfil_publico_asesor(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_perfil_publico_asesor(p_asesor_id uuid) RETURNS TABLE(asesor_id uuid, nombre_mostrar character varying, universidad_id uuid, slug character varying, email_publico character varying, biografia text, foto_url text, especialidad_id uuid, carrera character varying, nivel_academico character varying, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
  select
    p.asesor_id,
    p.nombre_mostrar,
    p.universidad_id,
    p.slug,
    p.email_publico,
    p.biografia,
    p.foto_url,
    p.especialidad_id,
    p.carrera,
    p.nivel_academico,
    p.creado_en,
    p.actualizado_en
  from "AT".perfil_publico_asesor p
  where p.asesor_id = p_asesor_id
  limit 1;
$$;


--
-- Name: obtener_resumen_dashboard_estudiante(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_resumen_dashboard_estudiante() RETURNS TABLE(cantidad_citas_proximas bigint, pagos_pendientes bigint, tesis_id uuid, tesis_titulo text, documentos_recientes bigint, proxima_reunion_id uuid, proxima_reunion_inicio timestamp with time zone, proxima_reunion_fin timestamp with time zone, proxima_reunion_estado character varying, proxima_reunion_enlace text, proximo_asesor_id uuid, proximo_asesor_nombre character varying)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
  into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  return query
  with tesis_activa as (
    select t.id, t.titulo
    from "AT".tesis t
    where t.estudiante_id = v_estudiante_id
      and t.eliminado_en is null
    order by t.creado_en desc
    limit 1
  ),
  prox_reunion as (
    select
      r.id,
      r.inicio,
      r.fin,
      r.estado,
      r.enlace_reunion,
      r.asesor_id,
      ppa.nombre_mostrar
    from "AT".reuniones_asesor r
    left join "AT".perfil_publico_asesor ppa
      on ppa.asesor_id = r.asesor_id
    where r.estudiante_id = v_estudiante_id
      and r.estado in ('pendiente', 'confirmado')
      and r.inicio >= now()
    order by r.inicio asc
    limit 1
  )
  select
    (
      select count(*)
      from "AT".reuniones_asesor r
      where r.estudiante_id = v_estudiante_id
        and r.estado in ('pendiente', 'confirmado')
        and r.inicio >= now()
    ) as cantidad_citas_proximas,
    (
      select count(*)
      from "AT".pagos p
      where p.pagador_id = v_estudiante_id
        and p.estado in ('pendiente', 'voucher_subido', 'rechazado')
    ) as pagos_pendientes,
    ta.id as tesis_id,
    ta.titulo as tesis_titulo,
    (
      select count(*)
      from "AT".documentos_tesis dt
      where dt.tesis_id = ta.id
    ) as documentos_recientes,
    pr.id as proxima_reunion_id,
    pr.inicio as proxima_reunion_inicio,
    pr.fin as proxima_reunion_fin,
    pr.estado as proxima_reunion_estado,
    pr.enlace_reunion as proxima_reunion_enlace,
    pr.asesor_id as proximo_asesor_id,
    pr.nombre_mostrar as proximo_asesor_nombre
  from tesis_activa ta
  full join prox_reunion pr on true;
end;
$$;


--
-- Name: obtener_sugerencias_mi_tesis(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_sugerencias_mi_tesis(p_tesis_id uuid) RETURNS TABLE(r_sugerencia_id uuid, r_tesis_id uuid, r_documento_tesis_id uuid, r_asesor_id uuid, r_nombre_asesor character varying, r_sugerencia text, r_aplicado boolean, r_creado_en timestamp with time zone, r_actualizado_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
  select
    h.id,
    h.tesis_id,
    h.documento_tesis_id,
    h.asesor_id,
    p.nombre_mostrar as nombre_asesor,
    h.sugerencia,
    h.aplicado,
    h.creado_en,
    h.actualizado_en
  from "AT".historial_sugerencias_asesor h
  join "AT".tesis t
    on t.id = h.tesis_id
  join "AT".usuarios u
    on u.id = t.estudiante_id
  left join "AT".perfil_publico_asesor p
    on p.asesor_id = h.asesor_id
  where h.tesis_id = p_tesis_id
    and u.auth_usuario_id = auth.uid()
    and u.rol = 'estudiante'
  order by h.creado_en desc;
$$;


--
-- Name: obtener_sugerencias_tesis_asignada(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_sugerencias_tesis_asignada(p_tesis_id uuid) RETURNS TABLE(sugerencia_id uuid, tesis_id uuid, asesor_id uuid, documento_tesis_id uuid, sugerencia text, aplicado boolean, creado_en timestamp with time zone, actualizado_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_usuario_id uuid;
  v_rol varchar;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
    into v_usuario_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  limit 1;

  if v_usuario_id is null then
    raise exception 'Usuario no válido';
  end if;

  if v_rol = 'asesor' then
    if not exists (
      select 1
      from "AT".asesores_tesis atx
      where atx.tesis_id = p_tesis_id
        and atx.asesor_id = v_usuario_id
        and coalesce(atx.activo, true) = true
    ) then
      raise exception 'No tienes acceso a esta tesis';
    end if;
  elsif v_rol = 'estudiante' then
    if not exists (
      select 1
      from "AT".tesis t
      where t.id = p_tesis_id
        and t.estudiante_id = v_usuario_id
        and t.eliminado_en is null
    ) then
      raise exception 'No tienes acceso a esta tesis';
    end if;
  else
    raise exception 'Rol no autorizado';
  end if;

  return query
  select
    h.id,
    h.tesis_id,
    h.asesor_id,
    h.documento_tesis_id,
    h.sugerencia,
    coalesce(h.aplicado, false),
    h.creado_en,
    h.actualizado_en
  from "AT".historial_sugerencias_asesor h
  where h.tesis_id = p_tesis_id
  order by h.creado_en desc;
end;
$$;


--
-- Name: obtener_suscripcion_estudiante(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_suscripcion_estudiante(p_estudiante_id uuid) RETURNS TABLE(id uuid, estudiante_id uuid, plan_id uuid, estado character varying, asesorias_incluidas integer, asesorias_usadas integer, asesorias_disponibles integer, presustentaciones_incluidas integer, presustentaciones_usadas integer, presustentaciones_disponibles integer, iniciado_en timestamp with time zone, expira_en timestamp with time zone)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'at', 'public'
    AS $$
  select
    s.id,
    s.estudiante_id,
    s.plan_id,
    s.estado,
    coalesce(s.asesorias_incluidas, 0),
    coalesce(s.asesorias_usadas, 0),
    greatest(coalesce(s.asesorias_incluidas, 0) - coalesce(s.asesorias_usadas, 0), 0),
    coalesce(s.presustentaciones_incluidas, 0),
    coalesce(s.presustentaciones_usadas, 0),
    greatest(coalesce(s.presustentaciones_incluidas, 0) - coalesce(s.presustentaciones_usadas, 0), 0),
    s.iniciado_en,
    s.expira_en
  from "AT".suscripciones_estudiante s
  where s.estudiante_id = p_estudiante_id
    and s.estado = 'activo'
    and (s.expira_en is null or s.expira_en > now())
  order by s.creado_en desc
  limit 1;
$$;


--
-- Name: obtener_tesis_asignadas_asesor(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_tesis_asignadas_asesor() RETURNS TABLE(asesor_tesis_id uuid, tesis_id uuid, tesis_titulo text, tesis_descripcion text, estudiante_id uuid, estudiante_nombres character varying, estudiante_apellidos character varying, relacion_id uuid, rol character varying, activo boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  return query
  select
    at.id as asesor_tesis_id,
    t.id as tesis_id,
    t.titulo as tesis_titulo,
    t.descripcion as tesis_descripcion,
    t.estudiante_id,
    pe.nombres as estudiante_nombres,
    pe.apellidos as estudiante_apellidos,
    at.relacion_id,
    at.rol,
    coalesce(at.activo, true) as activo
  from "AT".asesores_tesis at
  join "AT".tesis t
    on t.id = at.tesis_id
  left join "AT".perfil_estudiante pe
    on pe.estudiante_id = t.estudiante_id
  where at.asesor_id = v_asesor_id
    and coalesce(at.activo, true) = true
    and t.eliminado_en is null
  order by t.creado_en desc;
end;
$$;


--
-- Name: obtener_tesis_mis_asignadas(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_tesis_mis_asignadas() RETURNS TABLE(tesis_id uuid, titulo text, estado text, estudiante_nombre text, estudiante_apellido text)
    LANGUAGE sql SECURITY DEFINER
    AS $$
select
t.id,
t.titulo,
t.estado,
pe.nombres,
pe.apellidos
from "AT".asesores_tesis at
join "AT".tesis t
on t.id = at.tesis_id
join "AT".usuarios u
on u.id = t.estudiante_id
join "AT".perfil_estudiante pe
on pe.estudiante_id = u.id
where
at.asesor_id = "AT".usuario_id()
and at.activo = true;
$$;


--
-- Name: obtener_tipos_tesis_activos(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_tipos_tesis_activos() RETURNS TABLE(id uuid, codigo character varying, nombre character varying, descripcion text, activo boolean)
    LANGUAGE sql STABLE
    AS $$
  select
    tt.id,
    tt.codigo,
    tt.nombre,
    tt.descripcion,
    tt.activo
  from "AT".tipos_tesis tt
  where coalesce(tt.activo, true) = true
  order by tt.nombre;
$$;


--
-- Name: obtener_tipos_tesis_activos_por_plan(uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".obtener_tipos_tesis_activos_por_plan(p_plan_id uuid) RETURNS TABLE(tipo_tesis_id uuid, codigo character varying, nombre character varying, descripcion text, precio_base numeric, moneda character varying)
    LANGUAGE sql STABLE
    AS $$
  select
    tt.id as tipo_tesis_id,
    tt.codigo,
    tt.nombre,
    tt.descripcion,
    ptp.precio_base,
    ptp.moneda
  from "AT".tipos_tesis tt
  join "AT".planes_tipos_tesis_precios ptp
    on ptp.tipo_tesis_id = tt.id
  where coalesce(tt.activo, true) = true
    and coalesce(ptp.activo, true) = true
    and ptp.plan_id = p_plan_id
  order by tt.nombre;
$$;


--
-- Name: registrar_documento_tesis(uuid, uuid, character varying, text, text, text, integer, character varying, bigint); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".registrar_documento_tesis(p_tesis_id uuid, p_subido_por uuid, p_nombre_archivo character varying, p_url_archivo_drive text, p_carpeta_drive_id text, p_documento_drive_id text, p_version integer, p_tipo_mime character varying, p_tamano_bytes bigint) RETURNS TABLE(r_ok boolean, r_documento_id uuid, r_tesis_id uuid, r_version integer, r_documento_drive_id text, r_url_archivo_drive text, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'AT'
    AS $$
declare
  v_documento_id uuid;
begin
  insert into "AT".documentos_tesis (
    tesis_id,
    subido_por,
    nombre_archivo,
    url_archivo_drive,
    carpeta_drive_id,
    documento_drive_id,
    version,
    estado_revision,
    comentario_revision,
    creado_en,
    actualizado_en,
    ruta_storage,
    tipo_mime,
    tamano_bytes
  )
  values (
    p_tesis_id,
    p_subido_por,
    p_nombre_archivo,
    p_url_archivo_drive,
    p_carpeta_drive_id,
    p_documento_drive_id,
    p_version,
    'pendiente',
    null,
    now(),
    now(),
    null,
    p_tipo_mime,
    p_tamano_bytes
  )
  returning id into v_documento_id;

  return query
  select
    true,
    v_documento_id,
    p_tesis_id,
    p_version,
    p_documento_drive_id,
    p_url_archivo_drive,
    'Documento registrado correctamente'::text;
end;
$$;


--
-- Name: registrar_evento_validacion_sugerencia(uuid, uuid, uuid, uuid, uuid, character varying, character varying, character varying, character varying, text, jsonb); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".registrar_evento_validacion_sugerencia(p_validacion_sugerencia_id uuid, p_historial_sugerencia_id uuid, p_tesis_id uuid, p_documento_tesis_id uuid, p_usuario_id uuid, p_rol_usuario character varying, p_accion character varying, p_estado_anterior character varying DEFAULT NULL::character varying, p_estado_nuevo character varying DEFAULT NULL::character varying, p_comentario text DEFAULT NULL::text, p_metadata jsonb DEFAULT NULL::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
begin
  insert into "AT".eventos_validacion_sugerencia (
    validacion_sugerencia_id,
    historial_sugerencia_id,
    tesis_id,
    documento_tesis_id,
    usuario_id,
    rol_usuario,
    accion,
    estado_anterior,
    estado_nuevo,
    comentario,
    metadata
  )
  values (
    p_validacion_sugerencia_id,
    p_historial_sugerencia_id,
    p_tesis_id,
    p_documento_tesis_id,
    p_usuario_id,
    p_rol_usuario,
    p_accion,
    p_estado_anterior,
    p_estado_nuevo,
    p_comentario,
    p_metadata
  );
end;
$$;


--
-- Name: registrar_lead_estudiante(character varying, character varying, character varying, character varying, character varying, boolean, uuid, numeric, character varying, jsonb); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".registrar_lead_estudiante(p_telefono character varying, p_nombre character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_nivel_academico character varying DEFAULT NULL::character varying, p_tipo_tesis_codigo character varying DEFAULT NULL::character varying, p_requiere_analisis_estadistico boolean DEFAULT NULL::boolean, p_plan_recomendado_id uuid DEFAULT NULL::uuid, p_precio_cotizado numeric DEFAULT NULL::numeric, p_estado_lead character varying DEFAULT 'nuevo'::character varying, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_lead_id uuid;
  v_result jsonb;
begin
  if p_telefono is null or trim(p_telefono) = '' then
    raise exception 'El teléfono es obligatorio';
  end if;

  insert into "AT".leads_estudiantes (
    telefono,
    nombre,
    email,
    nivel_academico,
    tipo_tesis_codigo,
    requiere_analisis_estadistico,
    plan_recomendado_id,
    precio_cotizado,
    estado_lead,
    metadata,
    creado_en,
    actualizado_en
  )
  values (
    trim(p_telefono),
    nullif(trim(coalesce(p_nombre, '')), ''),
    nullif(lower(trim(coalesce(p_email, ''))), ''),
    nullif(trim(coalesce(p_nivel_academico, '')), ''),
    nullif(trim(coalesce(p_tipo_tesis_codigo, '')), ''),
    p_requiere_analisis_estadistico,
    p_plan_recomendado_id,
    p_precio_cotizado,
    coalesce(nullif(trim(p_estado_lead), ''), 'nuevo'),
    coalesce(p_metadata, '{}'::jsonb),
    now(),
    now()
  )
  on conflict (telefono)
  do update set
    nombre = coalesce(excluded.nombre, leads_estudiantes.nombre),
    email = coalesce(excluded.email, leads_estudiantes.email),
    nivel_academico = coalesce(excluded.nivel_academico, leads_estudiantes.nivel_academico),
    tipo_tesis_codigo = coalesce(excluded.tipo_tesis_codigo, leads_estudiantes.tipo_tesis_codigo),
    requiere_analisis_estadistico = coalesce(
      excluded.requiere_analisis_estadistico,
      leads_estudiantes.requiere_analisis_estadistico
    ),
    plan_recomendado_id = coalesce(excluded.plan_recomendado_id, leads_estudiantes.plan_recomendado_id),
    precio_cotizado = coalesce(excluded.precio_cotizado, leads_estudiantes.precio_cotizado),
    estado_lead = coalesce(excluded.estado_lead, leads_estudiantes.estado_lead),
    metadata = coalesce(leads_estudiantes.metadata, '{}'::jsonb) || coalesce(excluded.metadata, '{}'::jsonb),
    actualizado_en = now()
  returning id into v_lead_id;

  select jsonb_build_object(
    'ok', true,
    'lead_id', l.id,
    'telefono', l.telefono,
    'nombre', l.nombre,
    'email', l.email,
    'nivel_academico', l.nivel_academico,
    'tipo_tesis_codigo', l.tipo_tesis_codigo,
    'requiere_analisis_estadistico', l.requiere_analisis_estadistico,
    'plan_recomendado_id', l.plan_recomendado_id,
    'precio_cotizado', l.precio_cotizado,
    'estado_lead', l.estado_lead,
    'metadata', l.metadata,
    'creado_en', l.creado_en,
    'actualizado_en', l.actualizado_en
  )
  into v_result
  from "AT".leads_estudiantes l
  where l.id = v_lead_id;

  return v_result;
end;
$$;


--
-- Name: registrar_sugerencia_asesor(uuid, text, uuid); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".registrar_sugerencia_asesor(p_tesis_id uuid, p_sugerencia text, p_documento_tesis_id uuid DEFAULT NULL::uuid) RETURNS TABLE(ok boolean, sugerencia_id uuid, tesis_id uuid, documento_tesis_id uuid, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_sugerencia_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  if not exists (
    select 1
    from "AT".asesores_tesis atx
    where atx.tesis_id = p_tesis_id
      and atx.asesor_id = v_asesor_id
      and coalesce(atx.activo, true) = true
  ) then
    raise exception 'No tienes acceso a esta tesis';
  end if;

  insert into "AT".historial_sugerencias_asesor (
    tesis_id,
    asesor_id,
    documento_tesis_id,
    sugerencia,
    aplicado,
    creado_en,
    actualizado_en
  )
  values (
    p_tesis_id,
    v_asesor_id,
    p_documento_tesis_id,
    p_sugerencia,
    false,
    now(),
    now()
  )
  returning id into v_sugerencia_id;

  return query
  select
    true,
    v_sugerencia_id,
    p_tesis_id,
    p_documento_tesis_id,
    'Sugerencia registrada correctamente'::text;
end;
$$;


--
-- Name: registrar_voucher_pago(uuid, uuid, character varying, text, text, character varying, character varying, bigint, jsonb); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".registrar_voucher_pago(p_pago_id uuid, p_pagador_id uuid, p_codigo_operacion character varying DEFAULT NULL::character varying, p_documento_drive_id text DEFAULT NULL::text, p_url_archivo_drive text DEFAULT NULL::text, p_nombre_archivo_voucher character varying DEFAULT NULL::character varying, p_tipo_mime_voucher character varying DEFAULT NULL::character varying, p_tamano_bytes_voucher bigint DEFAULT NULL::bigint, p_metadata jsonb DEFAULT '{}'::jsonb) RETURNS TABLE(pago_id uuid, pagador_id uuid, tesis_id uuid, concepto character varying, monto numeric, estado_anterior character varying, estado_nuevo character varying, codigo_operacion character varying, documento_drive_id text, url_archivo_drive text, nombre_archivo_voucher character varying, tipo_mime_voucher character varying, tamano_bytes_voucher bigint, subido_en timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_pago record;
  v_estado_nuevo varchar := 'en_revision';
  v_subido_en timestamptz := now();
begin
  if p_pago_id is null then
    raise exception 'El pago es obligatorio';
  end if;

  if p_pagador_id is null then
    raise exception 'El pagador es obligatorio';
  end if;

  select
    p.*
  into v_pago
  from "AT"."pagos" p
  where p."id" = p_pago_id
    and p."pagador_id" = p_pagador_id
  limit 1;

  if v_pago."id" is null then
    raise exception 'No se encontró el pago para el pagador indicado';
  end if;

  if coalesce(v_pago."estado", '') = 'aprobado' then
    raise exception 'El pago ya fue aprobado y no admite un nuevo voucher';
  end if;

  if p_url_archivo_drive is null or btrim(p_url_archivo_drive) = '' then
    raise exception 'La URL del voucher es obligatoria';
  end if;

  update "AT"."pagos"
  set
    "codigo_operacion" = coalesce(p_codigo_operacion, "codigo_operacion"),
    "documento_drive_id" = coalesce(p_documento_drive_id, "documento_drive_id"),
    "url_archivo_drive" = p_url_archivo_drive,
    "nombre_archivo_voucher" = coalesce(p_nombre_archivo_voucher, "nombre_archivo_voucher"),
    "tipo_mime_voucher" = coalesce(p_tipo_mime_voucher, "tipo_mime_voucher"),
    "tamano_bytes_voucher" = coalesce(p_tamano_bytes_voucher, "tamano_bytes_voucher"),
    "subido_en" = v_subido_en,
    "estado" = v_estado_nuevo,
    "actualizado_en" = now(),
    "metadata" = coalesce("metadata", '{}'::jsonb)
      || coalesce(p_metadata, '{}'::jsonb)
      || jsonb_build_object(
        'voucher_registrado', true,
        'voucher_actualizado_en', v_subido_en
      )
  where "id" = p_pago_id;

  return query
  select
    p."id" as "pago_id",
    p."pagador_id",
    p."tesis_id",
    p."concepto",
    p."monto",
    v_pago."estado" as "estado_anterior",
    p."estado" as "estado_nuevo",
    p."codigo_operacion",
    p."documento_drive_id",
    p."url_archivo_drive",
    p."nombre_archivo_voucher",
    p."tipo_mime_voucher",
    p."tamano_bytes_voucher",
    p."subido_en"
  from "AT"."pagos" p
  where p."id" = p_pago_id;
end;
$$;


--
-- Name: responder_reserva_cita(uuid, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".responder_reserva_cita(p_validation_cita_id uuid, p_accion text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'at', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_asesor_id uuid;
  v_validacion record;
  v_suscripcion record;
  v_reunion_id uuid;
  v_pago_id uuid;
  v_monto numeric := 100.00;
  v_concepto text;
  v_asesorias_restantes integer := 0;
  v_presustentaciones_restantes integer := 0;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_asesor_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'El usuario autenticado no es un asesor válido';
  end if;

  select vc.*
    into v_validacion
  from "AT".validation_cita vc
  where vc.id = p_validation_cita_id
    and vc.advisor_id = v_asesor_id
  limit 1;

  if v_validacion.id is null then
    raise exception 'No se encontró la solicitud';
  end if;

  if coalesce(v_validacion.status, '') not in ('pending', 'payment_pending') then
    raise exception 'La solicitud ya fue procesada';
  end if;

  if p_accion = 'rechazar' then
    update "AT".validation_cita
       set status = 'rejected',
           updated_at = now()
     where id = p_validation_cita_id;

    return jsonb_build_object(
      'ok', true,
      'accion', 'rechazada',
      'mensaje', 'Solicitud rechazada correctamente',
      'validation_cita_id', p_validation_cita_id
    );
  end if;

  if p_accion <> 'aceptar' then
    raise exception 'Acción no válida';
  end if;

  select *
    into v_suscripcion
  from "AT".obtener_suscripcion_estudiante(v_validacion.user_id)
  limit 1;

  -- ASESORIA CUBIERTA POR PLAN
  if coalesce(v_validacion.tipo_servicio, 'asesoria') = 'asesoria'
     and v_suscripcion.id is not null
     and coalesce(v_suscripcion.asesorias_disponibles, 0) > 0 then

    update "AT".suscripciones_estudiante
       set asesorias_usadas = coalesce(asesorias_usadas, 0) + 1,
           actualizado_en = now()
     where id = v_suscripcion.id;

    v_asesorias_restantes := greatest(coalesce(v_suscripcion.asesorias_disponibles, 0) - 1, 0);

    insert into "AT".reuniones_asesor (
      disponibilidad_id,
      asesor_id,
      estudiante_id,
      tesis_id,
      estado,
      pago_id,
      motivo,
      notas,
      modalidad,
      lugar,
      enlace_reunion,
      inicio,
      fin,
      duracion_minutos,
      costo_reunion,
      moneda,
      creado_en,
      actualizado_en
    )
    values (
      v_validacion.disponibilidad_id,
      v_validacion.advisor_id,
      v_validacion.user_id,
      v_validacion.tesis_id,
      'confirmado',
      null,
      v_validacion.motivo,
      v_validacion.notas,
      v_validacion.modalidad,
      v_validacion.lugar,
      v_validacion.enlace_reunion,
      v_validacion.start_at,
      v_validacion.end_at,
      v_validacion.duration_minutes,
      0,
      'PEN',
      now(),
      now()
    )
    returning id into v_reunion_id;

    update "AT".validation_cita
       set status = 'approved',
           updated_at = now()
     where id = p_validation_cita_id;

    return jsonb_build_object(
      'ok', true,
      'accion', 'aceptada_por_plan',
      'mensaje', 'La asesoría fue aprobada y cubierta por el plan',
      'tipo_servicio', 'asesoria',
      'validation_cita_id', p_validation_cita_id,
      'reunion_id', v_reunion_id,
      'asesorias_restantes', v_asesorias_restantes
    );
  end if;

  -- PRESUSTENTACION CUBIERTA POR PLAN
  if coalesce(v_validacion.tipo_servicio, '') = 'presustentacion'
     and v_suscripcion.id is not null
     and coalesce(v_suscripcion.presustentaciones_disponibles, 0) > 0 then

    update "AT".suscripciones_estudiante
       set presustentaciones_usadas = coalesce(presustentaciones_usadas, 0) + 1,
           actualizado_en = now()
     where id = v_suscripcion.id;

    v_presustentaciones_restantes := greatest(coalesce(v_suscripcion.presustentaciones_disponibles, 0) - 1, 0);

    insert into "AT".reuniones_asesor (
      disponibilidad_id,
      asesor_id,
      estudiante_id,
      tesis_id,
      estado,
      pago_id,
      motivo,
      notas,
      modalidad,
      lugar,
      enlace_reunion,
      inicio,
      fin,
      duracion_minutos,
      costo_reunion,
      moneda,
      creado_en,
      actualizado_en
    )
    values (
      v_validacion.disponibilidad_id,
      v_validacion.advisor_id,
      v_validacion.user_id,
      v_validacion.tesis_id,
      'confirmado',
      null,
      v_validacion.motivo,
      v_validacion.notas,
      v_validacion.modalidad,
      v_validacion.lugar,
      v_validacion.enlace_reunion,
      v_validacion.start_at,
      v_validacion.end_at,
      v_validacion.duration_minutes,
      0,
      'PEN',
      now(),
      now()
    )
    returning id into v_reunion_id;

    update "AT".validation_cita
       set status = 'approved',
           updated_at = now()
     where id = p_validation_cita_id;

    return jsonb_build_object(
      'ok', true,
      'accion', 'aceptada_por_plan',
      'mensaje', 'La pre-sustentación fue aprobada y cubierta por el plan',
      'tipo_servicio', 'presustentacion',
      'validation_cita_id', p_validation_cita_id,
      'reunion_id', v_reunion_id,
      'presustentaciones_restantes', v_presustentaciones_restantes
    );
  end if;

  -- SIN CUPOS -> GENERAR PAGO PENDIENTE
  v_concepto := case
    when coalesce(v_validacion.tipo_servicio, 'asesoria') = 'presustentacion'
      then 'Reserva de pre-sustentación'
    else 'Reserva de asesoría'
  end;

  insert into "AT".pagos (
    pagador_id,
    concepto,
    monto,
    estado,
    codigo_operacion,
    metadata,
    creado_en,
    actualizado_en
  )
  values (
    v_validacion.user_id,
    v_concepto,
    v_monto,
    'pendiente',
    null,
    jsonb_build_object(
      'validation_cita_id', v_validacion.id,
      'advisor_id', v_validacion.advisor_id,
      'tipo_servicio', v_validacion.tipo_servicio,
      'start_at', v_validacion.start_at,
      'end_at', v_validacion.end_at
    ),
    now(),
    now()
  )
  returning id into v_pago_id;

  update "AT".validation_cita
     set status = 'payment_pending',
         updated_at = now()
   where id = p_validation_cita_id;

  return jsonb_build_object(
    'ok', true,
    'accion', 'pendiente_pago',
    'mensaje', 'La solicitud requiere pago para continuar',
    'validation_cita_id', p_validation_cita_id,
    'pago_id', v_pago_id
  );
end;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


--
-- Name: subir_voucher_pago(uuid, text, text, text, character varying, bigint); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".subir_voucher_pago(p_pago_id uuid, p_documento_drive_id text, p_url_archivo_drive text, p_nombre_archivo_voucher text DEFAULT NULL::text, p_tipo_mime_voucher character varying DEFAULT NULL::character varying, p_tamano_bytes_voucher bigint DEFAULT NULL::bigint) RETURNS TABLE(ok boolean, pago_id uuid, estado character varying, url_archivo_drive text, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_pago record;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  select
    p.id,
    p.pagador_id,
    p.estado
  into v_pago
  from "AT".pagos p
  where p.id = p_pago_id
  limit 1;

  if v_pago.id is null then
    raise exception 'No se encontró el pago';
  end if;

  if v_pago.pagador_id <> v_estudiante_id then
    raise exception 'No tienes permiso para modificar este pago';
  end if;

  update "AT".pagos
  set
    documento_drive_id = p_documento_drive_id,
    url_archivo_drive = p_url_archivo_drive,
    nombre_archivo_voucher = p_nombre_archivo_voucher,
    tipo_mime_voucher = p_tipo_mime_voucher,
    tamano_bytes_voucher = p_tamano_bytes_voucher,
    subido_en = now(),
    estado = 'voucher_subido',
    actualizado_en = now()
  where id = p_pago_id;

  return query
  select
    true,
    p_pago_id,
    'voucher_subido'::varchar,
    p_url_archivo_drive,
    'Voucher subido correctamente'::text;
end;
$$;


--
-- Name: tomar_cola_google_meet(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".tomar_cola_google_meet() RETURNS TABLE(cola_id uuid, reunion_id uuid, pago_id uuid, asesor_id uuid, estudiante_id uuid, inicio timestamp with time zone, fin timestamp with time zone, motivo text, notas text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
begin
  return query
  with siguiente as (
    select c.id
    from "AT".cola_google_meet c
    where c.estado = 'pendiente'
    order by c.creado_en asc
    limit 1
    for update skip locked
  ),
  marcado as (
    update "AT".cola_google_meet c
    set estado = 'procesando',
        intentos = intentos + 1,
        actualizado_en = now()
    where c.id in (select id from siguiente)
    returning c.id, c.reunion_id, c.pago_id
  )
  select
    m.id as cola_id,
    r.id as reunion_id,
    m.pago_id,
    r.asesor_id,
    r.estudiante_id,
    r.inicio,
    r.fin,
    r.motivo,
    r.notas
  from marcado m
  join "AT".reuniones_asesor r on r.id = m.reunion_id;
end;
$$;


--
-- Name: trg_reunion_set_defaults(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".trg_reunion_set_defaults() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'AT'
    AS $$
begin
  new.costo_reunion := 200;
  new.moneda := coalesce(new.moneda, 'PEN');
  new.duracion_minutos := greatest(1, floor(extract(epoch from (new.fin - new.inicio)) / 60));
  return new;
end;
$$;


--
-- Name: trg_sync_validacion_sugerencia(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".trg_sync_validacion_sugerencia() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'AT', 'public'
    AS $$
begin
  update "AT".historial_sugerencias_asesor h
  set
    aplicado = coalesce(new.marcado_aplicado, false),
    aplicado_por_estudiante = coalesce(new.marcado_aplicado, false),
    aplicado_en = new.marcado_en,
    actualizado_en = now()
  where h.id = new.historial_sugerencia_id;

  return new;
end;
$$;


--
-- Name: trigger_create_drive_folder(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".trigger_create_drive_folder() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
  project_url text := 'https://cdvsagdmfgjqvyfjrjwm.supabase.co';
  anon_key text := current_setting('app.settings.supabase_anon_key', true);
begin

  perform net.http_post(
    url := project_url || '/functions/v1/create-driver-folder',
    headers := jsonb_build_object(
      'Content-Type','application/json'
    ),
    body := jsonb_build_object(
      'tesis_id', new.id
    )
  );

  return new;
end;
$$;


--
-- Name: usuario_id(); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".usuario_id() RETURNS uuid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'at'
    AS $$
select id
from "AT".usuarios
where auth_usuario_id = auth.uid();
$$;


--
-- Name: validar_aplicacion_sugerencia(uuid, boolean, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".validar_aplicacion_sugerencia(p_historial_sugerencia_id uuid, p_aprobado boolean, p_comentario_asesor text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_usuario_id uuid;
  v_rol varchar;
  v_sug record;
  v_estado varchar;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
    into v_usuario_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id;

  if v_usuario_id is null then
    raise exception 'Usuario no encontrado';
  end if;

  if v_rol <> 'asesor' then
    raise exception 'Solo un asesor puede validar la aplicación';
  end if;

  select h.*
    into v_sug
  from "AT".historial_sugerencias_asesor h
  where h.id = p_historial_sugerencia_id
    and h.asesor_id = v_usuario_id;

  if not found then
    raise exception 'La sugerencia no existe o no pertenece al asesor';
  end if;

  if p_aprobado then
    v_estado := 'verificado';
  else
    v_estado := 'rechazado';
  end if;

  update "AT".validaciones_sugerencia_asesor
  set verificado_por_asesor = p_aprobado,
      verificado_en = now(),
      comentario_asesor = p_comentario_asesor,
      estado = v_estado,
      actualizado_en = now()
  where historial_sugerencia_id = p_historial_sugerencia_id;

  if not found then
    raise exception 'Primero el estudiante debe marcar la sugerencia como aplicada';
  end if;

  return jsonb_build_object(
    'ok', true,
    'message', case when p_aprobado
      then 'Aplicación verificada por el asesor'
      else 'Aplicación rechazada por el asesor'
    end,
    'estado', v_estado
  );
end;
$$;


--
-- Name: validar_cita_asesoria_admin(uuid, boolean, text, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".validar_cita_asesoria_admin(p_validation_cita_id uuid, p_aprobado boolean, p_notas_admin text DEFAULT NULL::text, p_enlace_reunion text DEFAULT NULL::text) RETURNS TABLE(ok boolean, validation_cita_id uuid, reunion_id uuid, status character varying, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public', 'auth'
    AS $$
declare
  v_auth_user_id uuid;
  v_admin_id uuid;
  v_rol varchar;
  v_cita record;
  v_reunion_id uuid;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id, u.rol
  into v_admin_id, v_rol
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
  limit 1;

  if v_admin_id is null then
    raise exception 'Usuario no válido';
  end if;

  if v_rol not in ('admin', 'coordinador') then
    raise exception 'Solo un admin puede validar citas';
  end if;

  select vc.*
  into v_cita
  from "AT".validation_cita vc
  where vc.id = p_validation_cita_id
  for update;

  if v_cita.id is null then
    raise exception 'La solicitud no existe';
  end if;

  if v_cita.status not in ('pending', 'approved') then
    raise exception 'La solicitud ya fue procesada';
  end if;

  if p_aprobado = false then
    update "AT".validation_cita
    set
      status = 'rejected',
      validated_by = v_admin_id,
      validated_at = now(),
      validation_notes = p_notas_admin,
      rejection_reason = p_notas_admin,
      updated_at = now()
    where id = p_validation_cita_id;

    return query
    select
      true,
      p_validation_cita_id,
      null::uuid,
      'rejected'::varchar,
      'Solicitud rechazada por el administrador'::text;

    return;
  end if;

  insert into "AT".reuniones_asesor (
    disponibilidad_id,
    asesor_id,
    estudiante_id,
    tesis_id,
    estado,
    pago_id,
    motivo,
    notas,
    modalidad,
    lugar,
    enlace_reunion,
    inicio,
    fin,
    duracion_minutos,
    costo_reunion,
    moneda,
    creado_en,
    actualizado_en
  )
  values (
    v_cita.disponibilidad_id,
    v_cita.advisor_id,
    v_cita.user_id,
    v_cita.tesis_id,
    'confirmado',
    v_cita.payment_id,
    v_cita.motivo,
    coalesce(v_cita.notas, p_notas_admin),
    v_cita.modalidad,
    v_cita.lugar,
    coalesce(p_enlace_reunion, v_cita.enlace_reunion),
    v_cita.start_at,
    v_cita.end_at,
    v_cita.duration_minutes,
    0,
    'PEN',
    now(),
    now()
  )
  returning id into v_reunion_id;

  update "AT".validation_cita
  set
    status = 'confirmed',
    validated_by = v_admin_id,
    validated_at = now(),
    validation_notes = p_notas_admin,
    meeting_id = v_reunion_id,
    enlace_reunion = coalesce(p_enlace_reunion, enlace_reunion),
    updated_at = now()
  where id = p_validation_cita_id;

  return query
  select
    true,
    p_validation_cita_id,
    v_reunion_id,
    'confirmed'::varchar,
    'Solicitud aprobada y reunión creada correctamente'::text;
end;
$$;


--
-- Name: validar_pago_admin(uuid, boolean, text); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".validar_pago_admin(p_pago_id uuid, p_aprobado boolean, p_nota_verificacion text DEFAULT NULL::text) RETURNS TABLE(ok boolean, pago_id uuid, estado_pago character varying, reunion_id uuid, estado_reunion character varying, mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'AT', 'public'
    AS $$
declare
  v_auth_user_id uuid;
  v_admin_id uuid;
  v_pago record;
  v_reunion_id uuid;
  v_estado_pago varchar;
  v_estado_reunion varchar;
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_admin_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'admin'
  limit 1;

  if v_admin_id is null then
    raise exception 'El usuario autenticado no es un administrador válido';
  end if;

  select
    p.id,
    p.estado
  into v_pago
  from "AT".pagos p
  where p.id = p_pago_id
  limit 1;

  if v_pago.id is null then
    raise exception 'No se encontró el pago';
  end if;

  if p_aprobado then
    v_estado_pago := 'validado';
    v_estado_reunion := 'confirmado';
  else
    v_estado_pago := 'rechazado';
    v_estado_reunion := 'pendiente';
  end if;

  update "AT".pagos
  set
    estado = v_estado_pago,
    verificado_por = v_admin_id,
    verificado_en = now(),
    nota_verificacion = p_nota_verificacion,
    actualizado_en = now()
  where id = p_pago_id;

  update "AT".reuniones_asesor
  set
    estado = v_estado_reunion,
    actualizado_en = now()
  where pago_id = p_pago_id
  returning id into v_reunion_id;

  return query
  select
    true,
    p_pago_id,
    v_estado_pago,
    v_reunion_id,
    v_estado_reunion,
    case
      when p_aprobado then 'Pago validado correctamente'
      else 'Pago rechazado correctamente'
    end::text;
end;
$$;


--
-- Name: vincularme_con_asesor_por_codigo(character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".vincularme_con_asesor_por_codigo(p_codigo character varying) RETURNS TABLE(r_ok boolean, r_relacion_id uuid, r_asesor_id uuid, r_estudiante_id uuid, r_codigo_publico_id uuid, r_estado character varying, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_asesor_id uuid;
  v_codigo_id uuid;
  v_relacion_id uuid;
  v_estado varchar(20);
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  select c.id, c.asesor_id
    into v_codigo_id, v_asesor_id
  from "AT".codigos_publicos_asesor c
  inner join "AT".usuarios u
    on u.id = c.asesor_id
  where c.codigo_publico = p_codigo
    and c.activo = true
    and (c.expira_en is null or c.expira_en > now())
    and u.rol = 'asesor'
  limit 1;

  if v_codigo_id is null or v_asesor_id is null then
    raise exception 'Código inválido, inactivo o vencido';
  end if;

  select r.id, r.estado
    into v_relacion_id, v_estado
  from "AT".relaciones_asesor_estudiante r
  where r.asesor_id = v_asesor_id
    and r.estudiante_id = v_estudiante_id
  limit 1;

  if v_relacion_id is not null then
    return query
    select
      true,
      v_relacion_id,
      v_asesor_id,
      v_estudiante_id,
      v_codigo_id,
      v_estado,
      'Ya existe una relación con este asesor'::text;
    return;
  end if;

  insert into "AT".relaciones_asesor_estudiante (
    asesor_id,
    estudiante_id,
    codigo_publico_id,
    estado,
    creado_en,
    actualizado_en
  )
  values (
    v_asesor_id,
    v_estudiante_id,
    v_codigo_id,
    'pendiente',
    now(),
    now()
  )
  returning id, estado
  into v_relacion_id, v_estado;

  return query
  select
    true,
    v_relacion_id,
    v_asesor_id,
    v_estudiante_id,
    v_codigo_id,
    v_estado,
    'Vinculación creada correctamente mediante código'::text;
end;
$$;


--
-- Name: vincularme_con_asesor_por_slug(character varying); Type: FUNCTION; Schema: AT; Owner: -
--

CREATE FUNCTION "AT".vincularme_con_asesor_por_slug(p_slug character varying) RETURNS TABLE(r_ok boolean, r_relacion_id uuid, r_asesor_id uuid, r_estudiante_id uuid, r_estado character varying, r_mensaje text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth', 'AT'
    AS $$
declare
  v_auth_user_id uuid;
  v_estudiante_id uuid;
  v_asesor_id uuid;
  v_relacion_id uuid;
  v_estado varchar(20);
begin
  v_auth_user_id := auth.uid();

  if v_auth_user_id is null then
    raise exception 'Usuario no autenticado';
  end if;

  -- buscar estudiante autenticado
  select u.id
    into v_estudiante_id
  from "AT".usuarios u
  where u.auth_usuario_id = v_auth_user_id
    and u.rol = 'estudiante'
  limit 1;

  if v_estudiante_id is null then
    raise exception 'El usuario autenticado no es un estudiante válido';
  end if;

  -- buscar asesor por slug
  select p.asesor_id
    into v_asesor_id
  from "AT".perfil_publico_asesor p
  inner join "AT".usuarios u
    on u.id = p.asesor_id
  where p.slug = p_slug
    and u.rol = 'asesor'
  limit 1;

  if v_asesor_id is null then
    raise exception 'No se encontró el asesor';
  end if;

  -- evitar que se vincule consigo mismo por error lógico
  if v_asesor_id = v_estudiante_id then
    raise exception 'No es posible vincularse consigo mismo';
  end if;

  -- revisar si ya existe relación
  select r.id, r.estado
    into v_relacion_id, v_estado
  from "AT".relaciones_asesor_estudiante r
  where r.asesor_id = v_asesor_id
    and r.estudiante_id = v_estudiante_id
  limit 1;

  if v_relacion_id is not null then
    return query
    select
      true,
      v_relacion_id,
      v_asesor_id,
      v_estudiante_id,
      v_estado,
      'Ya existe una relación con este asesor'::text;
    return;
  end if;

  -- crear relación sin código
  insert into "AT".relaciones_asesor_estudiante (
    asesor_id,
    estudiante_id,
    codigo_publico_id,
    estado,
    creado_en,
    actualizado_en
  )
  values (
    v_asesor_id,
    v_estudiante_id,
    null,
    'pendiente',
    now(),
    now()
  )
  returning id, estado
  into v_relacion_id, v_estado;

  return query
  select
    true,
    v_relacion_id,
    v_asesor_id,
    v_estudiante_id,
    v_estado,
    'Solicitud de vinculación creada correctamente'::text;
end;
$$;


--
-- Name: actividad_log; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".actividad_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid,
    accion character varying(150) NOT NULL,
    tabla_afectada character varying(150),
    registro_id uuid,
    metadata jsonb,
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: ajustes_adicionales_tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".ajustes_adicionales_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    tipo_ajuste character varying NOT NULL,
    valor numeric,
    signo character varying DEFAULT '+'::character varying NOT NULL,
    automatico boolean DEFAULT false,
    requiere_evaluacion boolean DEFAULT false,
    descripcion text,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: ajustes_nivel_academico; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".ajustes_nivel_academico (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nivel_academico character varying NOT NULL,
    tipo_ajuste character varying DEFAULT 'porcentaje'::character varying NOT NULL,
    valor numeric NOT NULL,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: asesores_tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".asesores_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asesor_id uuid NOT NULL,
    tesis_id uuid NOT NULL,
    activo boolean DEFAULT true,
    rol character varying(20),
    creado_en timestamp with time zone DEFAULT now(),
    relacion_id uuid NOT NULL,
    CONSTRAINT asesores_tesis_rol_check CHECK (((rol)::text = ANY ((ARRAY['principal'::character varying, 'coasesor'::character varying])::text[])))
);


--
-- Name: beneficios_plan_catalogo; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".beneficios_plan_catalogo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    descripcion text,
    tipo_control character varying NOT NULL,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: chatbot_sesiones; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".chatbot_sesiones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    telefono character varying,
    session_key character varying NOT NULL,
    estado_actual character varying DEFAULT 'inicio'::character varying NOT NULL,
    datos jsonb DEFAULT '{}'::jsonb,
    lead_id uuid,
    activa boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: codigos_publicos_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".codigos_publicos_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asesor_id uuid NOT NULL,
    codigo_publico character varying(20) NOT NULL,
    activo boolean DEFAULT true,
    expira_en timestamp with time zone,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: cola_google_meet; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".cola_google_meet (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    reunion_id uuid NOT NULL,
    pago_id uuid NOT NULL,
    estado text DEFAULT 'pendiente'::text NOT NULL,
    intentos integer DEFAULT 0 NOT NULL,
    error text,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: cotizacion_detalle_ajustes; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".cotizacion_detalle_ajustes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    cotizacion_id uuid NOT NULL,
    ajuste_id uuid,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    monto numeric,
    tipo_ajuste character varying,
    aplicado_automaticamente boolean DEFAULT false,
    requiere_evaluacion boolean DEFAULT false,
    observacion text,
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: cotizaciones_tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".cotizaciones_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid,
    estudiante_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    tipo_investigacion character varying NOT NULL,
    nivel_academico character varying NOT NULL,
    precio_base numeric NOT NULL,
    ajuste_nivel numeric DEFAULT 0 NOT NULL,
    subtotal numeric NOT NULL,
    total_ajustes numeric DEFAULT 0 NOT NULL,
    total_final numeric NOT NULL,
    moneda character varying DEFAULT 'PEN'::character varying,
    estado character varying DEFAULT 'borrador'::character varying NOT NULL,
    metadata jsonb,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: datos_privados_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".datos_privados_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asesor_id uuid NOT NULL,
    nombres_encriptados text NOT NULL,
    apellidos_encriptados text NOT NULL,
    dni_encriptado text NOT NULL,
    telefono_encriptado text,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: datos_privados_estudiante; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".datos_privados_estudiante (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    estudiante_id uuid NOT NULL,
    dni_encriptado text NOT NULL,
    telefono_encriptado text,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: disponibilidad_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".disponibilidad_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asesor_id uuid NOT NULL,
    inicio timestamp with time zone NOT NULL,
    fin timestamp with time zone NOT NULL,
    usa_bloques boolean DEFAULT true,
    duracion_bloque_minutos integer DEFAULT 30,
    recurrente boolean DEFAULT false,
    dia_semana integer,
    fecha_inicio date,
    fecha_fin date,
    disponible boolean DEFAULT true,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT disponibilidad_asesor_check CHECK ((fin > inicio)),
    CONSTRAINT disponibilidad_asesor_check1 CHECK (((recurrente = false) OR (dia_semana IS NOT NULL))),
    CONSTRAINT disponibilidad_asesor_check2 CHECK (((fecha_fin IS NULL) OR (fecha_inicio IS NULL) OR (fecha_fin >= fecha_inicio))),
    CONSTRAINT disponibilidad_asesor_dia_semana_check CHECK (((dia_semana >= 0) AND (dia_semana <= 6))),
    CONSTRAINT disponibilidad_asesor_duracion_bloque_minutos_check CHECK ((duracion_bloque_minutos > 0))
);


--
-- Name: documentos_tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".documentos_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid NOT NULL,
    subido_por uuid,
    nombre_archivo character varying(255),
    url_archivo_drive text,
    documento_drive_id text,
    version integer DEFAULT 1,
    estado_revision character varying(20),
    comentario_revision text,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    ruta_storage text,
    tipo_mime character varying(100),
    tamano_bytes bigint,
    CONSTRAINT documentos_tesis_estado_revision_check CHECK (((estado_revision)::text = ANY ((ARRAY['pendiente'::character varying, 'aprobado'::character varying, 'rechazado'::character varying])::text[])))
);


--
-- Name: especialidades; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".especialidades (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre character varying(150) NOT NULL,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: eventos_validacion_sugerencia; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".eventos_validacion_sugerencia (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    validacion_sugerencia_id uuid NOT NULL,
    historial_sugerencia_id uuid NOT NULL,
    tesis_id uuid NOT NULL,
    documento_tesis_id uuid,
    usuario_id uuid,
    rol_usuario character varying(20),
    accion character varying(40) NOT NULL,
    estado_anterior character varying(30),
    estado_nuevo character varying(30),
    comentario text,
    metadata jsonb,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT eventos_validacion_sugerencia_accion_check CHECK (((accion)::text = ANY ((ARRAY['creada'::character varying, 'marcada_aplicada'::character varying, 'desmarcada'::character varying, 'enviada_revision'::character varying, 'verificada'::character varying, 'rechazada'::character varying, 'reabierta'::character varying, 'comentario_estudiante'::character varying, 'comentario_asesor'::character varying])::text[]))),
    CONSTRAINT eventos_validacion_sugerencia_estado_anterior_check CHECK (((estado_anterior)::text = ANY ((ARRAY['pendiente'::character varying, 'marcado_por_estudiante'::character varying, 'verificado'::character varying, 'rechazado'::character varying])::text[]))),
    CONSTRAINT eventos_validacion_sugerencia_estado_nuevo_check CHECK (((estado_nuevo)::text = ANY ((ARRAY['pendiente'::character varying, 'marcado_por_estudiante'::character varying, 'verificado'::character varying, 'rechazado'::character varying])::text[]))),
    CONSTRAINT eventos_validacion_sugerencia_rol_usuario_check CHECK (((rol_usuario)::text = ANY ((ARRAY['estudiante'::character varying, 'asesor'::character varying, 'sistema'::character varying])::text[])))
);


--
-- Name: historial_ia; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".historial_ia (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    usuario_id uuid NOT NULL,
    tesis_id uuid,
    prompt text NOT NULL,
    respuesta text,
    tokens_usados integer DEFAULT 0,
    modelo character varying(100),
    embedding public.vector(1536),
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: historial_sugerencias_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".historial_sugerencias_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid NOT NULL,
    asesor_id uuid NOT NULL,
    documento_tesis_id uuid,
    sugerencia text,
    aplicado boolean DEFAULT false,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    tipo_sugerencia_id uuid,
    detalle text,
    aplicado_por_estudiante boolean DEFAULT false,
    aplicado_en timestamp with time zone,
    aplicado_por uuid
);


--
-- Name: invitaciones_pendientes; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".invitaciones_pendientes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    nombre text,
    payload jsonb,
    estado character varying DEFAULT 'pendiente'::character varying NOT NULL,
    intentos integer DEFAULT 0 NOT NULL,
    ultimo_error text,
    enviado_en timestamp with time zone,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: leads_estudiantes; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".leads_estudiantes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    telefono character varying,
    nombre character varying,
    email character varying,
    nivel_academico character varying,
    tipo_tesis_codigo character varying,
    requiere_analisis_estadistico boolean,
    plan_recomendado_id uuid,
    precio_cotizado numeric(10,2),
    estado_lead character varying DEFAULT 'nuevo'::character varying,
    metadata jsonb DEFAULT '{}'::jsonb,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: mensajes; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".mensajes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid,
    remitente_id uuid NOT NULL,
    destinatario_id uuid,
    mensaje text NOT NULL,
    leido boolean DEFAULT false,
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: modificaciones_tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".modificaciones_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid NOT NULL,
    descripcion text NOT NULL,
    precio numeric(10,2) NOT NULL,
    estado character varying(20) NOT NULL,
    pago_id uuid,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    eliminado_en timestamp with time zone,
    CONSTRAINT modificaciones_tesis_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'pagado'::character varying, 'en_proceso'::character varying, 'completado'::character varying, 'cancelado'::character varying])::text[]))),
    CONSTRAINT modificaciones_tesis_precio_check CHECK ((precio >= (0)::numeric))
);


--
-- Name: modulos_lista; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".modulos_lista (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    universidad_id uuid,
    titulo text NOT NULL,
    detalle text,
    estructura jsonb NOT NULL,
    prioridad integer DEFAULT 1,
    estado character varying(20) DEFAULT 'activo'::character varying,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT modulos_lista_estado_check CHECK (((estado)::text = ANY ((ARRAY['activo'::character varying, 'inactivo'::character varying])::text[])))
);


--
-- Name: modulos_tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".modulos_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid NOT NULL,
    modulo_lista_id uuid NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    progreso integer DEFAULT 0,
    observacion text,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT modulos_tesis_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'en_progreso'::character varying, 'completado'::character varying])::text[]))),
    CONSTRAINT modulos_tesis_progreso_check CHECK (((progreso >= 0) AND (progreso <= 100)))
);


--
-- Name: notifications; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    title character varying(150) NOT NULL,
    message text NOT NULL,
    type character varying(50) NOT NULL,
    related_id uuid,
    status character varying(20) DEFAULT 'unread'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    read_at timestamp with time zone
);


--
-- Name: observaciones_tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".observaciones_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid NOT NULL,
    documento_tesis_id uuid,
    asesor_id uuid,
    texto text NOT NULL,
    creado_en timestamp with time zone DEFAULT now(),
    reunion_id uuid,
    validation_cita_id uuid,
    tipo_origen character varying(30),
    contenido_html text,
    contenido_delta jsonb,
    titulo text,
    pdf_url text,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pagos; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".pagos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pagador_id uuid NOT NULL,
    concepto character varying(200),
    monto numeric(10,2) NOT NULL,
    estado character varying(20) NOT NULL,
    codigo_operacion character varying(150),
    metadata jsonb,
    verificado_por uuid,
    verificado_en timestamp with time zone,
    nota_verificacion text,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    documento_drive_id text,
    url_archivo_drive text,
    nombre_archivo_voucher text,
    tipo_mime_voucher character varying,
    tamano_bytes_voucher bigint,
    subido_en timestamp with time zone,
    tesis_id uuid,
    CONSTRAINT pagos_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'voucher_subido'::character varying, 'validado'::character varying, 'rechazado'::character varying])::text[]))),
    CONSTRAINT pagos_monto_check CHECK ((monto >= (0)::numeric))
);


--
-- Name: pagos_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".pagos_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pago_id uuid NOT NULL,
    asesor_id uuid NOT NULL,
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: pagos_plan; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".pagos_plan (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pago_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    creado_en timestamp with time zone DEFAULT now()
);


--
-- Name: perfil_estudiante; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".perfil_estudiante (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    estudiante_id uuid NOT NULL,
    nombres character varying(150) NOT NULL,
    apellidos character varying(150) NOT NULL,
    universidad_id uuid,
    carrera character varying(150),
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: perfil_publico_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".perfil_publico_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asesor_id uuid NOT NULL,
    nombre_mostrar character varying(150) NOT NULL,
    universidad_id uuid,
    slug character varying(150) NOT NULL,
    email_publico character varying(150),
    biografia text,
    foto_url text,
    especialidad_id uuid,
    carrera character varying(200),
    nivel_academico character varying(30),
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT perfil_publico_asesor_nivel_academico_check CHECK (((nivel_academico IS NULL) OR ((nivel_academico)::text = ANY ((ARRAY['pregrado'::character varying, 'maestria'::character varying, 'doctorado'::character varying])::text[]))))
);


--
-- Name: planes; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".planes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre character varying(150) NOT NULL,
    precio numeric(10,2) NOT NULL,
    duracion_dias integer NOT NULL,
    caracteristicas jsonb,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT planes_duracion_dias_check CHECK ((duracion_dias > 0)),
    CONSTRAINT planes_precio_check CHECK ((precio >= (0)::numeric))
);


--
-- Name: planes_beneficios; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".planes_beneficios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id uuid NOT NULL,
    beneficio_id uuid NOT NULL,
    incluido boolean DEFAULT true,
    cantidad integer,
    metadata jsonb,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: planes_tipos_tesis_precios; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".planes_tipos_tesis_precios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    plan_id uuid NOT NULL,
    tipo_tesis_id uuid NOT NULL,
    precio_base numeric(10,2) NOT NULL,
    moneda character varying DEFAULT 'PEN'::character varying NOT NULL,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: programas; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".programas (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    universidad_id uuid,
    nivel character varying(30) NOT NULL,
    especialidad_id uuid,
    nombre character varying(200),
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT programas_nivel_check CHECK (((nivel)::text = ANY ((ARRAY['pregrado'::character varying, 'maestria'::character varying, 'doctorado'::character varying])::text[])))
);


--
-- Name: relaciones_asesor_estudiante; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".relaciones_asesor_estudiante (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asesor_id uuid NOT NULL,
    estudiante_id uuid NOT NULL,
    codigo_publico_id uuid,
    estado character varying(20) NOT NULL,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT relaciones_asesor_estudiante_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'activo'::character varying, 'cancelado'::character varying, 'completado'::character varying])::text[])))
);


--
-- Name: reuniones_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".reuniones_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    disponibilidad_id uuid,
    asesor_id uuid NOT NULL,
    estudiante_id uuid NOT NULL,
    tesis_id uuid,
    tarifa_id uuid,
    estado character varying(20) NOT NULL,
    pago_id uuid,
    motivo text,
    notas text,
    modalidad character varying(20),
    lugar text,
    enlace_reunion text,
    inicio timestamp with time zone NOT NULL,
    fin timestamp with time zone NOT NULL,
    duracion_minutos integer NOT NULL,
    costo_reunion numeric(10,2) NOT NULL,
    moneda character varying(10) DEFAULT 'PEN'::character varying,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    google_event_id text,
    meet_codigo text,
    meet_creado_en timestamp with time zone,
    meet_error text,
    origen_servicio character varying,
    suscripcion_id uuid,
    consume_cupo_plan boolean DEFAULT false,
    tipo_sesion character varying,
    beneficio_consumo_id uuid,
    cubierta_por_plan boolean DEFAULT false,
    tipo_reunion character varying DEFAULT 'asesoria'::character varying,
    CONSTRAINT reuniones_asesor_check CHECK ((fin > inicio)),
    CONSTRAINT reuniones_asesor_costo_reunion_check CHECK ((costo_reunion >= (0)::numeric)),
    CONSTRAINT reuniones_asesor_duracion_minutos_check CHECK ((duracion_minutos > 0)),
    CONSTRAINT reuniones_asesor_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'confirmado'::character varying, 'cancelado'::character varying, 'completado'::character varying])::text[]))),
    CONSTRAINT reuniones_asesor_modalidad_check CHECK (((modalidad)::text = ANY ((ARRAY['virtual'::character varying, 'presencial'::character varying])::text[])))
);


--
-- Name: suscripcion_beneficios_consumo; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".suscripcion_beneficios_consumo (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    suscripcion_id uuid NOT NULL,
    beneficio_id uuid NOT NULL,
    cantidad_total integer DEFAULT 0 NOT NULL,
    cantidad_usada integer DEFAULT 0 NOT NULL,
    cantidad_disponible integer GENERATED ALWAYS AS ((cantidad_total - cantidad_usada)) STORED,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: suscripciones_estudiante; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".suscripciones_estudiante (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    estudiante_id uuid NOT NULL,
    plan_id uuid NOT NULL,
    estado character varying(20) NOT NULL,
    iniciado_en timestamp with time zone DEFAULT now(),
    expira_en timestamp with time zone,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    asesorias_incluidas integer DEFAULT 0 NOT NULL,
    asesorias_usadas integer DEFAULT 0 NOT NULL,
    presustentaciones_incluidas integer DEFAULT 0 NOT NULL,
    presustentaciones_usadas integer DEFAULT 0 NOT NULL,
    CONSTRAINT suscripciones_estudiante_estado_check CHECK (((estado)::text = ANY ((ARRAY['activo'::character varying, 'expirado'::character varying, 'cancelado'::character varying])::text[])))
);


--
-- Name: tarifas_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".tarifas_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asesor_id uuid NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion text,
    duracion_minutos integer NOT NULL,
    precio numeric(10,2) NOT NULL,
    moneda character varying(10) DEFAULT 'PEN'::character varying,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT tarifas_asesor_duracion_minutos_check CHECK ((duracion_minutos > 0)),
    CONSTRAINT tarifas_asesor_precio_check CHECK ((precio >= (0)::numeric))
);


--
-- Name: tesis_ajustes_aplicados; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".tesis_ajustes_aplicados (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid NOT NULL,
    ajuste_id uuid NOT NULL,
    estado character varying DEFAULT 'pendiente'::character varying NOT NULL,
    base_calculo numeric(10,2),
    valor_configurado numeric(10,2),
    valor_aplicado numeric(10,2),
    signo character varying DEFAULT '+'::character varying NOT NULL,
    tipo_ajuste character varying NOT NULL,
    automatico boolean DEFAULT false,
    requiere_evaluacion boolean DEFAULT false,
    evaluado_por uuid,
    evaluado_en timestamp with time zone,
    observacion text,
    metadata jsonb,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: tipos_sugerencia_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".tipos_sugerencia_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo character varying(50) NOT NULL,
    nombre character varying(120) NOT NULL,
    descripcion text,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: tipos_tesis; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".tipos_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    codigo character varying NOT NULL,
    nombre character varying NOT NULL,
    descripcion text,
    activo boolean DEFAULT true,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: universidades; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".universidades (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    nombre character varying(200) NOT NULL,
    ubicacion character varying(200),
    pais character varying(100),
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);


--
-- Name: usuarios; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".usuarios (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    auth_usuario_id uuid NOT NULL,
    rol character varying(20) NOT NULL,
    verificado boolean DEFAULT false,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT usuarios_rol_check CHECK (((rol)::text = ANY ((ARRAY['admin'::character varying, 'asesor'::character varying, 'estudiante'::character varying])::text[])))
);


--
-- Name: validaciones_sugerencia_asesor; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".validaciones_sugerencia_asesor (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    historial_sugerencia_id uuid NOT NULL,
    tesis_id uuid NOT NULL,
    documento_tesis_id uuid,
    estudiante_id uuid NOT NULL,
    asesor_id uuid NOT NULL,
    marcado_aplicado boolean DEFAULT false NOT NULL,
    marcado_en timestamp with time zone,
    comentario_estudiante text,
    verificado_por_asesor boolean DEFAULT false NOT NULL,
    verificado_en timestamp with time zone,
    comentario_asesor text,
    estado character varying(30) DEFAULT 'pendiente'::character varying NOT NULL,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    actualizado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT validaciones_sugerencia_asesor_estado_check CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'marcado_por_estudiante'::character varying, 'verificado'::character varying, 'rechazado'::character varying])::text[])))
);


--
-- Name: validation_cita; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".validation_cita (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    advisor_id uuid NOT NULL,
    tesis_id uuid,
    disponibilidad_id uuid NOT NULL,
    status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    reservation_date date NOT NULL,
    start_at timestamp with time zone NOT NULL,
    end_at timestamp with time zone NOT NULL,
    duration_minutes integer NOT NULL,
    motivo text,
    modalidad character varying(50),
    lugar text,
    enlace_reunion text,
    notas text,
    payment_id uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    meeting_id uuid,
    validated_by uuid,
    validated_at timestamp with time zone,
    validation_notes text,
    rejection_reason text,
    tipo_servicio character varying
);


--
-- Name: vw_log_validacion_sugerencia; Type: VIEW; Schema: AT; Owner: -
--

CREATE VIEW "AT".vw_log_validacion_sugerencia AS
 SELECT e.id,
    e.validacion_sugerencia_id,
    e.historial_sugerencia_id,
    e.tesis_id,
    e.documento_tesis_id,
    e.usuario_id,
    e.rol_usuario,
    e.accion,
    e.estado_anterior,
    e.estado_nuevo,
    e.comentario,
    e.metadata,
    e.creado_en,
    COALESCE(h.detalle, h.sugerencia) AS sugerencia_detalle,
    ppa.nombre_mostrar AS asesor_nombre,
        CASE
            WHEN ((u.rol)::text = 'estudiante'::text) THEN TRIM(BOTH FROM (((COALESCE(pe.nombres, ''::character varying))::text || ' '::text) || (COALESCE(pe.apellidos, ''::character varying))::text))
            WHEN ((u.rol)::text = 'asesor'::text) THEN (COALESCE(ppa2.nombre_mostrar, 'Asesor'::character varying))::text
            ELSE 'Sistema'::text
        END AS usuario_nombre
   FROM ((((("AT".eventos_validacion_sugerencia e
     LEFT JOIN "AT".historial_sugerencias_asesor h ON ((h.id = e.historial_sugerencia_id)))
     LEFT JOIN "AT".perfil_publico_asesor ppa ON ((ppa.asesor_id = h.asesor_id)))
     LEFT JOIN "AT".usuarios u ON ((u.id = e.usuario_id)))
     LEFT JOIN "AT".perfil_estudiante pe ON ((pe.estudiante_id = e.usuario_id)))
     LEFT JOIN "AT".perfil_publico_asesor ppa2 ON ((ppa2.asesor_id = e.usuario_id)));


--
-- Name: actividad_log actividad_log_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".actividad_log
    ADD CONSTRAINT actividad_log_pkey PRIMARY KEY (id);


--
-- Name: ajustes_adicionales_tesis ajustes_adicionales_tesis_codigo_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".ajustes_adicionales_tesis
    ADD CONSTRAINT ajustes_adicionales_tesis_codigo_key UNIQUE (codigo);


--
-- Name: ajustes_adicionales_tesis ajustes_adicionales_tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".ajustes_adicionales_tesis
    ADD CONSTRAINT ajustes_adicionales_tesis_pkey PRIMARY KEY (id);


--
-- Name: ajustes_nivel_academico ajustes_nivel_academico_nivel_academico_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".ajustes_nivel_academico
    ADD CONSTRAINT ajustes_nivel_academico_nivel_academico_key UNIQUE (nivel_academico);


--
-- Name: ajustes_nivel_academico ajustes_nivel_academico_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".ajustes_nivel_academico
    ADD CONSTRAINT ajustes_nivel_academico_pkey PRIMARY KEY (id);


--
-- Name: asesores_tesis asesores_tesis_asesor_id_tesis_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".asesores_tesis
    ADD CONSTRAINT asesores_tesis_asesor_id_tesis_id_key UNIQUE (asesor_id, tesis_id);


--
-- Name: asesores_tesis asesores_tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".asesores_tesis
    ADD CONSTRAINT asesores_tesis_pkey PRIMARY KEY (id);


--
-- Name: beneficios_plan_catalogo beneficios_plan_catalogo_codigo_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".beneficios_plan_catalogo
    ADD CONSTRAINT beneficios_plan_catalogo_codigo_key UNIQUE (codigo);


--
-- Name: beneficios_plan_catalogo beneficios_plan_catalogo_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".beneficios_plan_catalogo
    ADD CONSTRAINT beneficios_plan_catalogo_pkey PRIMARY KEY (id);


--
-- Name: chatbot_sesiones chatbot_sesiones_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".chatbot_sesiones
    ADD CONSTRAINT chatbot_sesiones_pkey PRIMARY KEY (id);


--
-- Name: chatbot_sesiones chatbot_sesiones_session_key_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".chatbot_sesiones
    ADD CONSTRAINT chatbot_sesiones_session_key_key UNIQUE (session_key);


--
-- Name: codigos_publicos_asesor codigos_publicos_asesor_codigo_publico_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".codigos_publicos_asesor
    ADD CONSTRAINT codigos_publicos_asesor_codigo_publico_key UNIQUE (codigo_publico);


--
-- Name: codigos_publicos_asesor codigos_publicos_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".codigos_publicos_asesor
    ADD CONSTRAINT codigos_publicos_asesor_pkey PRIMARY KEY (id);


--
-- Name: cola_google_meet cola_google_meet_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cola_google_meet
    ADD CONSTRAINT cola_google_meet_pkey PRIMARY KEY (id);


--
-- Name: cola_google_meet cola_google_meet_reunion_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cola_google_meet
    ADD CONSTRAINT cola_google_meet_reunion_id_key UNIQUE (reunion_id);


--
-- Name: cotizacion_detalle_ajustes cotizacion_detalle_ajustes_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cotizacion_detalle_ajustes
    ADD CONSTRAINT cotizacion_detalle_ajustes_pkey PRIMARY KEY (id);


--
-- Name: cotizaciones_tesis cotizaciones_tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cotizaciones_tesis
    ADD CONSTRAINT cotizaciones_tesis_pkey PRIMARY KEY (id);


--
-- Name: datos_privados_asesor datos_privados_asesor_asesor_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".datos_privados_asesor
    ADD CONSTRAINT datos_privados_asesor_asesor_id_key UNIQUE (asesor_id);


--
-- Name: datos_privados_asesor datos_privados_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".datos_privados_asesor
    ADD CONSTRAINT datos_privados_asesor_pkey PRIMARY KEY (id);


--
-- Name: datos_privados_estudiante datos_privados_estudiante_estudiante_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".datos_privados_estudiante
    ADD CONSTRAINT datos_privados_estudiante_estudiante_id_key UNIQUE (estudiante_id);


--
-- Name: datos_privados_estudiante datos_privados_estudiante_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".datos_privados_estudiante
    ADD CONSTRAINT datos_privados_estudiante_pkey PRIMARY KEY (id);


--
-- Name: disponibilidad_asesor disponibilidad_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".disponibilidad_asesor
    ADD CONSTRAINT disponibilidad_asesor_pkey PRIMARY KEY (id);


--
-- Name: documentos_tesis documentos_tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".documentos_tesis
    ADD CONSTRAINT documentos_tesis_pkey PRIMARY KEY (id);


--
-- Name: especialidades especialidades_nombre_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".especialidades
    ADD CONSTRAINT especialidades_nombre_key UNIQUE (nombre);


--
-- Name: especialidades especialidades_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".especialidades
    ADD CONSTRAINT especialidades_pkey PRIMARY KEY (id);


--
-- Name: estudiante_documentos estudiante_documentos_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".estudiante_documentos
    ADD CONSTRAINT estudiante_documentos_pkey PRIMARY KEY (id);


--
-- Name: eventos_validacion_sugerencia eventos_validacion_sugerencia_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".eventos_validacion_sugerencia
    ADD CONSTRAINT eventos_validacion_sugerencia_pkey PRIMARY KEY (id);


--
-- Name: historial_ia historial_ia_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".historial_ia
    ADD CONSTRAINT historial_ia_pkey PRIMARY KEY (id);


--
-- Name: historial_sugerencias_asesor historial_sugerencias_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".historial_sugerencias_asesor
    ADD CONSTRAINT historial_sugerencias_asesor_pkey PRIMARY KEY (id);


--
-- Name: invitaciones_pendientes invitaciones_pendientes_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".invitaciones_pendientes
    ADD CONSTRAINT invitaciones_pendientes_pkey PRIMARY KEY (id);


--
-- Name: leads_estudiantes leads_estudiantes_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".leads_estudiantes
    ADD CONSTRAINT leads_estudiantes_pkey PRIMARY KEY (id);


--
-- Name: leads_estudiantes leads_estudiantes_telefono_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".leads_estudiantes
    ADD CONSTRAINT leads_estudiantes_telefono_key UNIQUE (telefono);


--
-- Name: mensajes mensajes_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".mensajes
    ADD CONSTRAINT mensajes_pkey PRIMARY KEY (id);


--
-- Name: modificaciones_tesis modificaciones_tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modificaciones_tesis
    ADD CONSTRAINT modificaciones_tesis_pkey PRIMARY KEY (id);


--
-- Name: modulos_lista modulos_lista_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modulos_lista
    ADD CONSTRAINT modulos_lista_pkey PRIMARY KEY (id);


--
-- Name: modulos_tesis modulos_tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modulos_tesis
    ADD CONSTRAINT modulos_tesis_pkey PRIMARY KEY (id);


--
-- Name: modulos_tesis modulos_tesis_tesis_id_modulo_lista_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modulos_tesis
    ADD CONSTRAINT modulos_tesis_tesis_id_modulo_lista_id_key UNIQUE (tesis_id, modulo_lista_id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: observaciones_tesis observaciones_tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".observaciones_tesis
    ADD CONSTRAINT observaciones_tesis_pkey PRIMARY KEY (id);


--
-- Name: pagos_asesor pagos_asesor_pago_id_asesor_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos_asesor
    ADD CONSTRAINT pagos_asesor_pago_id_asesor_id_key UNIQUE (pago_id, asesor_id);


--
-- Name: pagos_asesor pagos_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos_asesor
    ADD CONSTRAINT pagos_asesor_pkey PRIMARY KEY (id);


--
-- Name: pagos pagos_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id);


--
-- Name: pagos_plan pagos_plan_pago_id_plan_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos_plan
    ADD CONSTRAINT pagos_plan_pago_id_plan_id_key UNIQUE (pago_id, plan_id);


--
-- Name: pagos_plan pagos_plan_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos_plan
    ADD CONSTRAINT pagos_plan_pkey PRIMARY KEY (id);


--
-- Name: perfil_estudiante perfil_estudiante_estudiante_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_estudiante
    ADD CONSTRAINT perfil_estudiante_estudiante_id_key UNIQUE (estudiante_id);


--
-- Name: perfil_estudiante perfil_estudiante_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_estudiante
    ADD CONSTRAINT perfil_estudiante_pkey PRIMARY KEY (id);


--
-- Name: perfil_publico_asesor perfil_publico_asesor_asesor_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_publico_asesor
    ADD CONSTRAINT perfil_publico_asesor_asesor_id_key UNIQUE (asesor_id);


--
-- Name: perfil_publico_asesor perfil_publico_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_publico_asesor
    ADD CONSTRAINT perfil_publico_asesor_pkey PRIMARY KEY (id);


--
-- Name: perfil_publico_asesor perfil_publico_asesor_slug_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_publico_asesor
    ADD CONSTRAINT perfil_publico_asesor_slug_key UNIQUE (slug);


--
-- Name: planes_beneficios planes_beneficios_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes_beneficios
    ADD CONSTRAINT planes_beneficios_pkey PRIMARY KEY (id);


--
-- Name: planes_beneficios planes_beneficios_plan_id_beneficio_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes_beneficios
    ADD CONSTRAINT planes_beneficios_plan_id_beneficio_id_key UNIQUE (plan_id, beneficio_id);


--
-- Name: planes planes_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes
    ADD CONSTRAINT planes_pkey PRIMARY KEY (id);


--
-- Name: planes_tipos_tesis_precios planes_tipos_tesis_precios_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes_tipos_tesis_precios
    ADD CONSTRAINT planes_tipos_tesis_precios_pkey PRIMARY KEY (id);


--
-- Name: planes_tipos_tesis_precios planes_tipos_tesis_precios_plan_id_tipo_tesis_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes_tipos_tesis_precios
    ADD CONSTRAINT planes_tipos_tesis_precios_plan_id_tipo_tesis_id_key UNIQUE (plan_id, tipo_tesis_id);


--
-- Name: programas programas_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".programas
    ADD CONSTRAINT programas_pkey PRIMARY KEY (id);


--
-- Name: relaciones_asesor_estudiante relaciones_asesor_estudiante_asesor_id_estudiante_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".relaciones_asesor_estudiante
    ADD CONSTRAINT relaciones_asesor_estudiante_asesor_id_estudiante_id_key UNIQUE (asesor_id, estudiante_id);


--
-- Name: relaciones_asesor_estudiante relaciones_asesor_estudiante_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".relaciones_asesor_estudiante
    ADD CONSTRAINT relaciones_asesor_estudiante_pkey PRIMARY KEY (id);


--
-- Name: reuniones_asesor reuniones_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".reuniones_asesor
    ADD CONSTRAINT reuniones_asesor_pkey PRIMARY KEY (id);


--
-- Name: suscripcion_beneficios_consumo suscripcion_beneficios_consumo_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".suscripcion_beneficios_consumo
    ADD CONSTRAINT suscripcion_beneficios_consumo_pkey PRIMARY KEY (id);


--
-- Name: suscripcion_beneficios_consumo suscripcion_beneficios_consumo_suscripcion_id_beneficio_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".suscripcion_beneficios_consumo
    ADD CONSTRAINT suscripcion_beneficios_consumo_suscripcion_id_beneficio_id_key UNIQUE (suscripcion_id, beneficio_id);


--
-- Name: suscripciones_estudiante suscripciones_estudiante_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".suscripciones_estudiante
    ADD CONSTRAINT suscripciones_estudiante_pkey PRIMARY KEY (id);


--
-- Name: tarifas_asesor tarifas_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tarifas_asesor
    ADD CONSTRAINT tarifas_asesor_pkey PRIMARY KEY (id);


--
-- Name: tesis_ajustes_aplicados tesis_ajustes_aplicados_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis_ajustes_aplicados
    ADD CONSTRAINT tesis_ajustes_aplicados_pkey PRIMARY KEY (id);


--
-- Name: tesis tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis
    ADD CONSTRAINT tesis_pkey PRIMARY KEY (id);


--
-- Name: tipos_sugerencia_asesor tipos_sugerencia_asesor_codigo_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tipos_sugerencia_asesor
    ADD CONSTRAINT tipos_sugerencia_asesor_codigo_key UNIQUE (codigo);


--
-- Name: tipos_sugerencia_asesor tipos_sugerencia_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tipos_sugerencia_asesor
    ADD CONSTRAINT tipos_sugerencia_asesor_pkey PRIMARY KEY (id);


--
-- Name: tipos_tesis tipos_tesis_codigo_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tipos_tesis
    ADD CONSTRAINT tipos_tesis_codigo_key UNIQUE (codigo);


--
-- Name: tipos_tesis tipos_tesis_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tipos_tesis
    ADD CONSTRAINT tipos_tesis_pkey PRIMARY KEY (id);


--
-- Name: universidades universidades_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".universidades
    ADD CONSTRAINT universidades_pkey PRIMARY KEY (id);


--
-- Name: usuarios usuarios_auth_usuario_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".usuarios
    ADD CONSTRAINT usuarios_auth_usuario_id_key UNIQUE (auth_usuario_id);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: validaciones_sugerencia_asesor validaciones_sugerencia_asesor_historial_sugerencia_id_key; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validaciones_sugerencia_asesor
    ADD CONSTRAINT validaciones_sugerencia_asesor_historial_sugerencia_id_key UNIQUE (historial_sugerencia_id);


--
-- Name: validaciones_sugerencia_asesor validaciones_sugerencia_asesor_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validaciones_sugerencia_asesor
    ADD CONSTRAINT validaciones_sugerencia_asesor_pkey PRIMARY KEY (id);


--
-- Name: validation_cita validation_cita_pkey; Type: CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validation_cita
    ADD CONSTRAINT validation_cita_pkey PRIMARY KEY (id);


--
-- Name: estudiante_documentos_thesis_idx; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX estudiante_documentos_thesis_idx ON "AT".estudiante_documentos USING btree (thesis_id);


--
-- Name: idx_actividad_log_usuario; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_actividad_log_usuario ON "AT".actividad_log USING btree (usuario_id);


--
-- Name: idx_codigo_publico_asesor; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_codigo_publico_asesor ON "AT".codigos_publicos_asesor USING btree (codigo_publico);


--
-- Name: idx_documentos_tesis_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_documentos_tesis_tesis ON "AT".documentos_tesis USING btree (tesis_id);


--
-- Name: idx_estudiante_documentos_activo; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_estudiante_documentos_activo ON "AT".estudiante_documentos USING btree (activo);


--
-- Name: idx_estudiante_documentos_thesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_estudiante_documentos_thesis ON "AT".estudiante_documentos USING btree (thesis_id);


--
-- Name: idx_estudiante_documentos_tipo; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_estudiante_documentos_tipo ON "AT".estudiante_documentos USING btree (tipo);


--
-- Name: idx_eventos_validacion_sugerencia_creado_en; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_eventos_validacion_sugerencia_creado_en ON "AT".eventos_validacion_sugerencia USING btree (creado_en DESC);


--
-- Name: idx_eventos_validacion_sugerencia_historial; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_eventos_validacion_sugerencia_historial ON "AT".eventos_validacion_sugerencia USING btree (historial_sugerencia_id);


--
-- Name: idx_eventos_validacion_sugerencia_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_eventos_validacion_sugerencia_tesis ON "AT".eventos_validacion_sugerencia USING btree (tesis_id);


--
-- Name: idx_eventos_validacion_sugerencia_validacion; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_eventos_validacion_sugerencia_validacion ON "AT".eventos_validacion_sugerencia USING btree (validacion_sugerencia_id);


--
-- Name: idx_historial_ia_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_historial_ia_tesis ON "AT".historial_ia USING btree (tesis_id);


--
-- Name: idx_historial_ia_usuario; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_historial_ia_usuario ON "AT".historial_ia USING btree (usuario_id);


--
-- Name: idx_historial_sugerencias_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_historial_sugerencias_tesis ON "AT".historial_sugerencias_asesor USING btree (tesis_id);


--
-- Name: idx_mensajes_remitente; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_mensajes_remitente ON "AT".mensajes USING btree (remitente_id);


--
-- Name: idx_mensajes_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_mensajes_tesis ON "AT".mensajes USING btree (tesis_id);


--
-- Name: idx_modificaciones_tesis_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_modificaciones_tesis_tesis ON "AT".modificaciones_tesis USING btree (tesis_id);


--
-- Name: idx_modulos_lista_universidad; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_modulos_lista_universidad ON "AT".modulos_lista USING btree (universidad_id);


--
-- Name: idx_modulos_tesis_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_modulos_tesis_tesis ON "AT".modulos_tesis USING btree (tesis_id);


--
-- Name: idx_notifications_status; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_notifications_status ON "AT".notifications USING btree (status);


--
-- Name: idx_notifications_user_id; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_notifications_user_id ON "AT".notifications USING btree (user_id);


--
-- Name: idx_observaciones_tesis_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_observaciones_tesis_tesis ON "AT".observaciones_tesis USING btree (tesis_id);


--
-- Name: idx_pagos_pagador; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_pagos_pagador ON "AT".pagos USING btree (pagador_id);


--
-- Name: idx_relacion_asesor; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_relacion_asesor ON "AT".relaciones_asesor_estudiante USING btree (asesor_id);


--
-- Name: idx_relacion_estudiante; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_relacion_estudiante ON "AT".relaciones_asesor_estudiante USING btree (estudiante_id);


--
-- Name: idx_reuniones_asesor_asesor; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_reuniones_asesor_asesor ON "AT".reuniones_asesor USING btree (asesor_id);


--
-- Name: idx_reuniones_asesor_estudiante; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_reuniones_asesor_estudiante ON "AT".reuniones_asesor USING btree (estudiante_id);


--
-- Name: idx_reuniones_asesor_tesis; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_reuniones_asesor_tesis ON "AT".reuniones_asesor USING btree (tesis_id);


--
-- Name: idx_suscripciones_estudiante_estudiante; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_suscripciones_estudiante_estudiante ON "AT".suscripciones_estudiante USING btree (estudiante_id);


--
-- Name: idx_tarifas_asesor_asesor; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_tarifas_asesor_asesor ON "AT".tarifas_asesor USING btree (asesor_id);


--
-- Name: idx_tesis_estudiante; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_tesis_estudiante ON "AT".tesis USING btree (estudiante_id);


--
-- Name: idx_usuarios_rol; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_usuarios_rol ON "AT".usuarios USING btree (rol);


--
-- Name: idx_validation_cita_advisor_id; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_validation_cita_advisor_id ON "AT".validation_cita USING btree (advisor_id);


--
-- Name: idx_validation_cita_disponibilidad_id; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_validation_cita_disponibilidad_id ON "AT".validation_cita USING btree (disponibilidad_id);


--
-- Name: idx_validation_cita_start_at; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_validation_cita_start_at ON "AT".validation_cita USING btree (start_at);


--
-- Name: idx_validation_cita_status; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_validation_cita_status ON "AT".validation_cita USING btree (status);


--
-- Name: idx_validation_cita_user_id; Type: INDEX; Schema: AT; Owner: -
--

CREATE INDEX idx_validation_cita_user_id ON "AT".validation_cita USING btree (user_id);


--
-- Name: ux_suscripcion_activa_estudiante_plan; Type: INDEX; Schema: AT; Owner: -
--

CREATE UNIQUE INDEX ux_suscripcion_activa_estudiante_plan ON "AT".suscripciones_estudiante USING btree (estudiante_id, plan_id) WHERE ((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'activa'::character varying])::text[]));


--
-- Name: ux_suscripciones_estudiante_estudiante_plan; Type: INDEX; Schema: AT; Owner: -
--

CREATE UNIQUE INDEX ux_suscripciones_estudiante_estudiante_plan ON "AT".suscripciones_estudiante USING btree (estudiante_id, plan_id);


--
-- Name: tesis after_insert_tesis_create_folder; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER after_insert_tesis_create_folder AFTER INSERT ON "AT".tesis FOR EACH ROW EXECUTE FUNCTION "AT".trigger_create_drive_folder();


--
-- Name: codigos_publicos_asesor trg_codigos_publicos_asesor_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_codigos_publicos_asesor_actualizado_en BEFORE UPDATE ON "AT".codigos_publicos_asesor FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: datos_privados_asesor trg_datos_privados_asesor_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_datos_privados_asesor_actualizado_en BEFORE UPDATE ON "AT".datos_privados_asesor FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: datos_privados_estudiante trg_datos_privados_estudiante_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_datos_privados_estudiante_actualizado_en BEFORE UPDATE ON "AT".datos_privados_estudiante FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: disponibilidad_asesor trg_disponibilidad_asesor_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_disponibilidad_asesor_actualizado_en BEFORE UPDATE ON "AT".disponibilidad_asesor FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: documentos_tesis trg_documentos_tesis_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_documentos_tesis_actualizado_en BEFORE UPDATE ON "AT".documentos_tesis FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: pagos trg_encolar_google_meet_on_pago; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_encolar_google_meet_on_pago AFTER UPDATE OF estado ON "AT".pagos FOR EACH ROW EXECUTE FUNCTION "AT".encolar_creacion_google_meet();


--
-- Name: especialidades trg_especialidades_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_especialidades_actualizado_en BEFORE UPDATE ON "AT".especialidades FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: suscripciones_estudiante trg_generar_pago_por_suscripcion; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_generar_pago_por_suscripcion AFTER INSERT ON "AT".suscripciones_estudiante FOR EACH ROW EXECUTE FUNCTION "AT".fn_generar_pago_por_suscripcion();


--
-- Name: historial_sugerencias_asesor trg_historial_sugerencias_asesor_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_historial_sugerencias_asesor_actualizado_en BEFORE UPDATE ON "AT".historial_sugerencias_asesor FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: modificaciones_tesis trg_modificaciones_tesis_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_modificaciones_tesis_actualizado_en BEFORE UPDATE ON "AT".modificaciones_tesis FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: modulos_lista trg_modulos_lista_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_modulos_lista_actualizado_en BEFORE UPDATE ON "AT".modulos_lista FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: modulos_tesis trg_modulos_tesis_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_modulos_tesis_actualizado_en BEFORE UPDATE ON "AT".modulos_tesis FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: pagos trg_pago_defaults; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_pago_defaults BEFORE INSERT ON "AT".pagos FOR EACH ROW EXECUTE FUNCTION "AT".fn_on_pago_before_insert_defaults();


--
-- Name: pagos trg_pago_reunion_pagado; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_pago_reunion_pagado AFTER UPDATE OF estado ON "AT".pagos FOR EACH ROW WHEN ((((old.estado)::text IS DISTINCT FROM (new.estado)::text) AND ((new.estado)::text = 'pagado'::text))) EXECUTE FUNCTION "AT".fn_on_pago_reunion_pagado();


--
-- Name: pagos trg_pagos_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_pagos_actualizado_en BEFORE UPDATE ON "AT".pagos FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: perfil_estudiante trg_perfil_estudiante_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_perfil_estudiante_actualizado_en BEFORE UPDATE ON "AT".perfil_estudiante FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: perfil_publico_asesor trg_perfil_publico_asesor_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_perfil_publico_asesor_actualizado_en BEFORE UPDATE ON "AT".perfil_publico_asesor FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: planes trg_planes_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_planes_actualizado_en BEFORE UPDATE ON "AT".planes FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: programas trg_programas_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_programas_actualizado_en BEFORE UPDATE ON "AT".programas FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: relaciones_asesor_estudiante trg_relaciones_asesor_estudiante_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_relaciones_asesor_estudiante_actualizado_en BEFORE UPDATE ON "AT".relaciones_asesor_estudiante FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: reuniones_asesor trg_reunion_set_costo; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_reunion_set_costo BEFORE INSERT ON "AT".reuniones_asesor FOR EACH ROW EXECUTE FUNCTION "AT".fn_on_reunion_insert_set_costo();


--
-- Name: reuniones_asesor trg_reuniones_asesor_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_reuniones_asesor_actualizado_en BEFORE UPDATE ON "AT".reuniones_asesor FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: reuniones_asesor trg_reuniones_asesor_set_defaults; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_reuniones_asesor_set_defaults BEFORE INSERT ON "AT".reuniones_asesor FOR EACH ROW EXECUTE FUNCTION "AT".trg_reunion_set_defaults();


--
-- Name: suscripciones_estudiante trg_suscripciones_estudiante_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_suscripciones_estudiante_actualizado_en BEFORE UPDATE ON "AT".suscripciones_estudiante FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: tarifas_asesor trg_tarifas_asesor_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_tarifas_asesor_actualizado_en BEFORE UPDATE ON "AT".tarifas_asesor FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: tesis trg_tesis_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_tesis_actualizado_en BEFORE UPDATE ON "AT".tesis FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: universidades trg_universidades_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_universidades_actualizado_en BEFORE UPDATE ON "AT".universidades FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: usuarios trg_usuarios_actualizado_en; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_usuarios_actualizado_en BEFORE UPDATE ON "AT".usuarios FOR EACH ROW EXECUTE FUNCTION "AT".actualizar_fecha_modificacion();


--
-- Name: validaciones_sugerencia_asesor trg_validaciones_sugerencia_sync; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_validaciones_sugerencia_sync AFTER INSERT OR UPDATE ON "AT".validaciones_sugerencia_asesor FOR EACH ROW EXECUTE FUNCTION "AT".trg_sync_validacion_sugerencia();


--
-- Name: validation_cita trg_validation_cita_updated_at; Type: TRIGGER; Schema: AT; Owner: -
--

CREATE TRIGGER trg_validation_cita_updated_at BEFORE UPDATE ON "AT".validation_cita FOR EACH ROW EXECUTE FUNCTION "AT".set_updated_at();


--
-- Name: actividad_log actividad_log_usuario_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".actividad_log
    ADD CONSTRAINT actividad_log_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES "AT".usuarios(id) ON DELETE SET NULL;


--
-- Name: asesores_tesis asesores_tesis_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".asesores_tesis
    ADD CONSTRAINT asesores_tesis_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: asesores_tesis asesores_tesis_relacion_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".asesores_tesis
    ADD CONSTRAINT asesores_tesis_relacion_id_fkey FOREIGN KEY (relacion_id) REFERENCES "AT".relaciones_asesor_estudiante(id) ON DELETE CASCADE;


--
-- Name: asesores_tesis asesores_tesis_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".asesores_tesis
    ADD CONSTRAINT asesores_tesis_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: codigos_publicos_asesor codigos_publicos_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".codigos_publicos_asesor
    ADD CONSTRAINT codigos_publicos_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: cola_google_meet cola_google_meet_pago_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cola_google_meet
    ADD CONSTRAINT cola_google_meet_pago_id_fkey FOREIGN KEY (pago_id) REFERENCES "AT".pagos(id) ON DELETE CASCADE;


--
-- Name: cola_google_meet cola_google_meet_reunion_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cola_google_meet
    ADD CONSTRAINT cola_google_meet_reunion_id_fkey FOREIGN KEY (reunion_id) REFERENCES "AT".reuniones_asesor(id) ON DELETE CASCADE;


--
-- Name: cotizacion_detalle_ajustes cotizacion_detalle_ajustes_ajuste_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cotizacion_detalle_ajustes
    ADD CONSTRAINT cotizacion_detalle_ajustes_ajuste_id_fkey FOREIGN KEY (ajuste_id) REFERENCES "AT".ajustes_adicionales_tesis(id);


--
-- Name: cotizacion_detalle_ajustes cotizacion_detalle_ajustes_cotizacion_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cotizacion_detalle_ajustes
    ADD CONSTRAINT cotizacion_detalle_ajustes_cotizacion_id_fkey FOREIGN KEY (cotizacion_id) REFERENCES "AT".cotizaciones_tesis(id);


--
-- Name: cotizaciones_tesis cotizaciones_tesis_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cotizaciones_tesis
    ADD CONSTRAINT cotizaciones_tesis_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES "AT".usuarios(id);


--
-- Name: cotizaciones_tesis cotizaciones_tesis_plan_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cotizaciones_tesis
    ADD CONSTRAINT cotizaciones_tesis_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES "AT".planes(id);


--
-- Name: cotizaciones_tesis cotizaciones_tesis_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".cotizaciones_tesis
    ADD CONSTRAINT cotizaciones_tesis_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id);


--
-- Name: datos_privados_asesor datos_privados_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".datos_privados_asesor
    ADD CONSTRAINT datos_privados_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: datos_privados_estudiante datos_privados_estudiante_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".datos_privados_estudiante
    ADD CONSTRAINT datos_privados_estudiante_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: disponibilidad_asesor disponibilidad_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".disponibilidad_asesor
    ADD CONSTRAINT disponibilidad_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: documentos_tesis documentos_tesis_subido_por_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".documentos_tesis
    ADD CONSTRAINT documentos_tesis_subido_por_fkey FOREIGN KEY (subido_por) REFERENCES "AT".usuarios(id) ON DELETE SET NULL;


--
-- Name: documentos_tesis documentos_tesis_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".documentos_tesis
    ADD CONSTRAINT documentos_tesis_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: estudiante_documentos estudiante_documentos_creado_por_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".estudiante_documentos
    ADD CONSTRAINT estudiante_documentos_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES "AT".usuarios(id);


--
-- Name: estudiante_documentos estudiante_documentos_thesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".estudiante_documentos
    ADD CONSTRAINT estudiante_documentos_thesis_id_fkey FOREIGN KEY (thesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: eventos_validacion_sugerencia eventos_validacion_sugerencia_documento_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".eventos_validacion_sugerencia
    ADD CONSTRAINT eventos_validacion_sugerencia_documento_tesis_id_fkey FOREIGN KEY (documento_tesis_id) REFERENCES "AT".documentos_tesis(id) ON DELETE SET NULL;


--
-- Name: eventos_validacion_sugerencia eventos_validacion_sugerencia_historial_sugerencia_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".eventos_validacion_sugerencia
    ADD CONSTRAINT eventos_validacion_sugerencia_historial_sugerencia_id_fkey FOREIGN KEY (historial_sugerencia_id) REFERENCES "AT".historial_sugerencias_asesor(id) ON DELETE CASCADE;


--
-- Name: eventos_validacion_sugerencia eventos_validacion_sugerencia_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".eventos_validacion_sugerencia
    ADD CONSTRAINT eventos_validacion_sugerencia_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: eventos_validacion_sugerencia eventos_validacion_sugerencia_usuario_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".eventos_validacion_sugerencia
    ADD CONSTRAINT eventos_validacion_sugerencia_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES "AT".usuarios(id) ON DELETE SET NULL;


--
-- Name: eventos_validacion_sugerencia eventos_validacion_sugerencia_validacion_sugerencia_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".eventos_validacion_sugerencia
    ADD CONSTRAINT eventos_validacion_sugerencia_validacion_sugerencia_id_fkey FOREIGN KEY (validacion_sugerencia_id) REFERENCES "AT".validaciones_sugerencia_asesor(id) ON DELETE CASCADE;


--
-- Name: historial_sugerencias_asesor fk_historial_sugerencia_tipo; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".historial_sugerencias_asesor
    ADD CONSTRAINT fk_historial_sugerencia_tipo FOREIGN KEY (tipo_sugerencia_id) REFERENCES "AT".tipos_sugerencia_asesor(id);


--
-- Name: historial_ia historial_ia_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".historial_ia
    ADD CONSTRAINT historial_ia_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: historial_ia historial_ia_usuario_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".historial_ia
    ADD CONSTRAINT historial_ia_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: historial_sugerencias_asesor historial_sugerencias_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".historial_sugerencias_asesor
    ADD CONSTRAINT historial_sugerencias_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: historial_sugerencias_asesor historial_sugerencias_asesor_documento_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".historial_sugerencias_asesor
    ADD CONSTRAINT historial_sugerencias_asesor_documento_tesis_id_fkey FOREIGN KEY (documento_tesis_id) REFERENCES "AT".documentos_tesis(id) ON DELETE SET NULL;


--
-- Name: historial_sugerencias_asesor historial_sugerencias_asesor_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".historial_sugerencias_asesor
    ADD CONSTRAINT historial_sugerencias_asesor_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: leads_estudiantes leads_estudiantes_plan_recomendado_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".leads_estudiantes
    ADD CONSTRAINT leads_estudiantes_plan_recomendado_id_fkey FOREIGN KEY (plan_recomendado_id) REFERENCES "AT".planes(id);


--
-- Name: mensajes mensajes_destinatario_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".mensajes
    ADD CONSTRAINT mensajes_destinatario_id_fkey FOREIGN KEY (destinatario_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: mensajes mensajes_remitente_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".mensajes
    ADD CONSTRAINT mensajes_remitente_id_fkey FOREIGN KEY (remitente_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: mensajes mensajes_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".mensajes
    ADD CONSTRAINT mensajes_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: modificaciones_tesis modificaciones_tesis_pago_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modificaciones_tesis
    ADD CONSTRAINT modificaciones_tesis_pago_id_fkey FOREIGN KEY (pago_id) REFERENCES "AT".pagos(id) ON DELETE SET NULL;


--
-- Name: modificaciones_tesis modificaciones_tesis_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modificaciones_tesis
    ADD CONSTRAINT modificaciones_tesis_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: modulos_lista modulos_lista_universidad_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modulos_lista
    ADD CONSTRAINT modulos_lista_universidad_id_fkey FOREIGN KEY (universidad_id) REFERENCES "AT".universidades(id) ON DELETE CASCADE;


--
-- Name: modulos_tesis modulos_tesis_modulo_lista_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modulos_tesis
    ADD CONSTRAINT modulos_tesis_modulo_lista_id_fkey FOREIGN KEY (modulo_lista_id) REFERENCES "AT".modulos_lista(id) ON DELETE CASCADE;


--
-- Name: modulos_tesis modulos_tesis_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".modulos_tesis
    ADD CONSTRAINT modulos_tesis_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: observaciones_tesis observaciones_tesis_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".observaciones_tesis
    ADD CONSTRAINT observaciones_tesis_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE SET NULL;


--
-- Name: observaciones_tesis observaciones_tesis_documento_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".observaciones_tesis
    ADD CONSTRAINT observaciones_tesis_documento_tesis_id_fkey FOREIGN KEY (documento_tesis_id) REFERENCES "AT".documentos_tesis(id) ON DELETE SET NULL;


--
-- Name: observaciones_tesis observaciones_tesis_reunion_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".observaciones_tesis
    ADD CONSTRAINT observaciones_tesis_reunion_id_fkey FOREIGN KEY (reunion_id) REFERENCES "AT".reuniones_asesor(id) ON DELETE SET NULL;


--
-- Name: observaciones_tesis observaciones_tesis_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".observaciones_tesis
    ADD CONSTRAINT observaciones_tesis_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: observaciones_tesis observaciones_tesis_validation_cita_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".observaciones_tesis
    ADD CONSTRAINT observaciones_tesis_validation_cita_id_fkey FOREIGN KEY (validation_cita_id) REFERENCES "AT".validation_cita(id) ON DELETE SET NULL;


--
-- Name: pagos_asesor pagos_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos_asesor
    ADD CONSTRAINT pagos_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: pagos_asesor pagos_asesor_pago_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos_asesor
    ADD CONSTRAINT pagos_asesor_pago_id_fkey FOREIGN KEY (pago_id) REFERENCES "AT".pagos(id) ON DELETE CASCADE;


--
-- Name: pagos pagos_pagador_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos
    ADD CONSTRAINT pagos_pagador_id_fkey FOREIGN KEY (pagador_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: pagos_plan pagos_plan_pago_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos_plan
    ADD CONSTRAINT pagos_plan_pago_id_fkey FOREIGN KEY (pago_id) REFERENCES "AT".pagos(id) ON DELETE CASCADE;


--
-- Name: pagos_plan pagos_plan_plan_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos_plan
    ADD CONSTRAINT pagos_plan_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES "AT".planes(id) ON DELETE CASCADE;


--
-- Name: pagos pagos_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos
    ADD CONSTRAINT pagos_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id);


--
-- Name: pagos pagos_verificado_por_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".pagos
    ADD CONSTRAINT pagos_verificado_por_fkey FOREIGN KEY (verificado_por) REFERENCES "AT".usuarios(id) ON DELETE SET NULL;


--
-- Name: perfil_estudiante perfil_estudiante_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_estudiante
    ADD CONSTRAINT perfil_estudiante_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: perfil_estudiante perfil_estudiante_universidad_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_estudiante
    ADD CONSTRAINT perfil_estudiante_universidad_id_fkey FOREIGN KEY (universidad_id) REFERENCES "AT".universidades(id) ON DELETE SET NULL;


--
-- Name: perfil_publico_asesor perfil_publico_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_publico_asesor
    ADD CONSTRAINT perfil_publico_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: perfil_publico_asesor perfil_publico_asesor_especialidad_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_publico_asesor
    ADD CONSTRAINT perfil_publico_asesor_especialidad_id_fkey FOREIGN KEY (especialidad_id) REFERENCES "AT".especialidades(id) ON DELETE SET NULL;


--
-- Name: perfil_publico_asesor perfil_publico_asesor_universidad_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".perfil_publico_asesor
    ADD CONSTRAINT perfil_publico_asesor_universidad_id_fkey FOREIGN KEY (universidad_id) REFERENCES "AT".universidades(id) ON DELETE SET NULL;


--
-- Name: planes_beneficios planes_beneficios_beneficio_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes_beneficios
    ADD CONSTRAINT planes_beneficios_beneficio_id_fkey FOREIGN KEY (beneficio_id) REFERENCES "AT".beneficios_plan_catalogo(id);


--
-- Name: planes_beneficios planes_beneficios_plan_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes_beneficios
    ADD CONSTRAINT planes_beneficios_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES "AT".planes(id);


--
-- Name: planes_tipos_tesis_precios planes_tipos_tesis_precios_plan_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes_tipos_tesis_precios
    ADD CONSTRAINT planes_tipos_tesis_precios_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES "AT".planes(id);


--
-- Name: planes_tipos_tesis_precios planes_tipos_tesis_precios_tipo_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".planes_tipos_tesis_precios
    ADD CONSTRAINT planes_tipos_tesis_precios_tipo_tesis_id_fkey FOREIGN KEY (tipo_tesis_id) REFERENCES "AT".tipos_tesis(id);


--
-- Name: programas programas_especialidad_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".programas
    ADD CONSTRAINT programas_especialidad_id_fkey FOREIGN KEY (especialidad_id) REFERENCES "AT".especialidades(id) ON DELETE SET NULL;


--
-- Name: programas programas_universidad_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".programas
    ADD CONSTRAINT programas_universidad_id_fkey FOREIGN KEY (universidad_id) REFERENCES "AT".universidades(id) ON DELETE CASCADE;


--
-- Name: relaciones_asesor_estudiante relaciones_asesor_estudiante_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".relaciones_asesor_estudiante
    ADD CONSTRAINT relaciones_asesor_estudiante_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: relaciones_asesor_estudiante relaciones_asesor_estudiante_codigo_publico_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".relaciones_asesor_estudiante
    ADD CONSTRAINT relaciones_asesor_estudiante_codigo_publico_id_fkey FOREIGN KEY (codigo_publico_id) REFERENCES "AT".codigos_publicos_asesor(id) ON DELETE SET NULL;


--
-- Name: relaciones_asesor_estudiante relaciones_asesor_estudiante_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".relaciones_asesor_estudiante
    ADD CONSTRAINT relaciones_asesor_estudiante_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: reuniones_asesor reuniones_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".reuniones_asesor
    ADD CONSTRAINT reuniones_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: reuniones_asesor reuniones_asesor_beneficio_consumo_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".reuniones_asesor
    ADD CONSTRAINT reuniones_asesor_beneficio_consumo_id_fkey FOREIGN KEY (beneficio_consumo_id) REFERENCES "AT".suscripcion_beneficios_consumo(id);


--
-- Name: reuniones_asesor reuniones_asesor_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".reuniones_asesor
    ADD CONSTRAINT reuniones_asesor_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: reuniones_asesor reuniones_asesor_pago_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".reuniones_asesor
    ADD CONSTRAINT reuniones_asesor_pago_id_fkey FOREIGN KEY (pago_id) REFERENCES "AT".pagos(id) ON DELETE SET NULL;


--
-- Name: reuniones_asesor reuniones_asesor_tarifa_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".reuniones_asesor
    ADD CONSTRAINT reuniones_asesor_tarifa_id_fkey FOREIGN KEY (tarifa_id) REFERENCES "AT".tarifas_asesor(id) ON DELETE SET NULL;


--
-- Name: reuniones_asesor reuniones_asesor_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".reuniones_asesor
    ADD CONSTRAINT reuniones_asesor_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE SET NULL;


--
-- Name: suscripcion_beneficios_consumo suscripcion_beneficios_consumo_beneficio_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".suscripcion_beneficios_consumo
    ADD CONSTRAINT suscripcion_beneficios_consumo_beneficio_id_fkey FOREIGN KEY (beneficio_id) REFERENCES "AT".beneficios_plan_catalogo(id);


--
-- Name: suscripcion_beneficios_consumo suscripcion_beneficios_consumo_suscripcion_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".suscripcion_beneficios_consumo
    ADD CONSTRAINT suscripcion_beneficios_consumo_suscripcion_id_fkey FOREIGN KEY (suscripcion_id) REFERENCES "AT".suscripciones_estudiante(id);


--
-- Name: suscripciones_estudiante suscripciones_estudiante_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".suscripciones_estudiante
    ADD CONSTRAINT suscripciones_estudiante_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: suscripciones_estudiante suscripciones_estudiante_plan_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".suscripciones_estudiante
    ADD CONSTRAINT suscripciones_estudiante_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES "AT".planes(id) ON DELETE RESTRICT;


--
-- Name: tarifas_asesor tarifas_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tarifas_asesor
    ADD CONSTRAINT tarifas_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: tesis_ajustes_aplicados tesis_ajustes_aplicados_ajuste_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis_ajustes_aplicados
    ADD CONSTRAINT tesis_ajustes_aplicados_ajuste_id_fkey FOREIGN KEY (ajuste_id) REFERENCES "AT".ajustes_adicionales_tesis(id);


--
-- Name: tesis_ajustes_aplicados tesis_ajustes_aplicados_evaluado_por_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis_ajustes_aplicados
    ADD CONSTRAINT tesis_ajustes_aplicados_evaluado_por_fkey FOREIGN KEY (evaluado_por) REFERENCES "AT".usuarios(id);


--
-- Name: tesis_ajustes_aplicados tesis_ajustes_aplicados_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis_ajustes_aplicados
    ADD CONSTRAINT tesis_ajustes_aplicados_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id);


--
-- Name: tesis tesis_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis
    ADD CONSTRAINT tesis_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: tesis tesis_plan_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis
    ADD CONSTRAINT tesis_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES "AT".planes(id);


--
-- Name: tesis tesis_programa_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis
    ADD CONSTRAINT tesis_programa_id_fkey FOREIGN KEY (programa_id) REFERENCES "AT".programas(id);


--
-- Name: tesis tesis_tipo_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis
    ADD CONSTRAINT tesis_tipo_tesis_id_fkey FOREIGN KEY (tipo_tesis_id) REFERENCES "AT".tipos_tesis(id);


--
-- Name: tesis tesis_universidad_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".tesis
    ADD CONSTRAINT tesis_universidad_id_fkey FOREIGN KEY (universidad_id) REFERENCES "AT".universidades(id) ON DELETE SET NULL;


--
-- Name: validaciones_sugerencia_asesor validaciones_sugerencia_asesor_asesor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validaciones_sugerencia_asesor
    ADD CONSTRAINT validaciones_sugerencia_asesor_asesor_id_fkey FOREIGN KEY (asesor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: validaciones_sugerencia_asesor validaciones_sugerencia_asesor_documento_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validaciones_sugerencia_asesor
    ADD CONSTRAINT validaciones_sugerencia_asesor_documento_tesis_id_fkey FOREIGN KEY (documento_tesis_id) REFERENCES "AT".documentos_tesis(id) ON DELETE SET NULL;


--
-- Name: validaciones_sugerencia_asesor validaciones_sugerencia_asesor_estudiante_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validaciones_sugerencia_asesor
    ADD CONSTRAINT validaciones_sugerencia_asesor_estudiante_id_fkey FOREIGN KEY (estudiante_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: validaciones_sugerencia_asesor validaciones_sugerencia_asesor_historial_sugerencia_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validaciones_sugerencia_asesor
    ADD CONSTRAINT validaciones_sugerencia_asesor_historial_sugerencia_id_fkey FOREIGN KEY (historial_sugerencia_id) REFERENCES "AT".historial_sugerencias_asesor(id) ON DELETE CASCADE;


--
-- Name: validaciones_sugerencia_asesor validaciones_sugerencia_asesor_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validaciones_sugerencia_asesor
    ADD CONSTRAINT validaciones_sugerencia_asesor_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE CASCADE;


--
-- Name: validation_cita validation_cita_advisor_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validation_cita
    ADD CONSTRAINT validation_cita_advisor_id_fkey FOREIGN KEY (advisor_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: validation_cita validation_cita_disponibilidad_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validation_cita
    ADD CONSTRAINT validation_cita_disponibilidad_id_fkey FOREIGN KEY (disponibilidad_id) REFERENCES "AT".disponibilidad_asesor(id) ON DELETE RESTRICT;


--
-- Name: validation_cita validation_cita_meeting_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validation_cita
    ADD CONSTRAINT validation_cita_meeting_id_fkey FOREIGN KEY (meeting_id) REFERENCES "AT".reuniones_asesor(id) ON DELETE SET NULL;


--
-- Name: validation_cita validation_cita_payment_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validation_cita
    ADD CONSTRAINT validation_cita_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES "AT".pagos(id) ON DELETE SET NULL;


--
-- Name: validation_cita validation_cita_tesis_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validation_cita
    ADD CONSTRAINT validation_cita_tesis_id_fkey FOREIGN KEY (tesis_id) REFERENCES "AT".tesis(id) ON DELETE SET NULL;


--
-- Name: validation_cita validation_cita_user_id_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validation_cita
    ADD CONSTRAINT validation_cita_user_id_fkey FOREIGN KEY (user_id) REFERENCES "AT".usuarios(id) ON DELETE CASCADE;


--
-- Name: validation_cita validation_cita_validated_by_fkey; Type: FK CONSTRAINT; Schema: AT; Owner: -
--

ALTER TABLE ONLY "AT".validation_cita
    ADD CONSTRAINT validation_cita_validated_by_fkey FOREIGN KEY (validated_by) REFERENCES "AT".usuarios(id) ON DELETE SET NULL;


--
-- Name: planes Allow select for all; Type: POLICY; Schema: AT; Owner: -
--

CREATE POLICY "Allow select for all" ON "AT".planes FOR SELECT USING (true);


--
-- Name: estudiante_documentos Estudiante puede ver sus documentos; Type: POLICY; Schema: AT; Owner: -
--

CREATE POLICY "Estudiante puede ver sus documentos" ON "AT".estudiante_documentos FOR SELECT USING ((creado_por = auth.uid()));


--
-- Name: suscripciones_estudiante debug_insert_suscripciones; Type: POLICY; Schema: AT; Owner: -
--

CREATE POLICY debug_insert_suscripciones ON "AT".suscripciones_estudiante FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: suscripciones_estudiante debug_select_suscripciones; Type: POLICY; Schema: AT; Owner: -
--

CREATE POLICY debug_select_suscripciones ON "AT".suscripciones_estudiante FOR SELECT TO authenticated USING (true);


--
-- Name: estudiante_documentos; Type: ROW SECURITY; Schema: AT; Owner: -
--

ALTER TABLE "AT".estudiante_documentos ENABLE ROW LEVEL SECURITY;

--
-- Name: suscripciones_estudiante; Type: ROW SECURITY; Schema: AT; Owner: -
--

ALTER TABLE "AT".suscripciones_estudiante ENABLE ROW LEVEL SECURITY;

--
-- Name: suscripciones_estudiante suscripciones_insert_propias; Type: POLICY; Schema: AT; Owner: -
--

CREATE POLICY suscripciones_insert_propias ON "AT".suscripciones_estudiante FOR INSERT TO authenticated WITH CHECK ((estudiante_id IN ( SELECT u.id
   FROM "AT".usuarios u
  WHERE (u.auth_usuario_id = auth.uid()))));


--
-- Name: suscripciones_estudiante suscripciones_select_propias; Type: POLICY; Schema: AT; Owner: -
--

CREATE POLICY suscripciones_select_propias ON "AT".suscripciones_estudiante FOR SELECT TO authenticated USING ((estudiante_id IN ( SELECT u.id
   FROM "AT".usuarios u
  WHERE (u.auth_usuario_id = auth.uid()))));


--
-- Name: tesis; Type: ROW SECURITY; Schema: AT; Owner: -
--

ALTER TABLE "AT".tesis ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict X8cd7gZ7Qvpp2sdg9v74dGE01BS8H5wPebSj0yormQzXvn59guffjHYjksyTMiz

