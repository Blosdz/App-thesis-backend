--
-- PostgreSQL database dump
--

\restrict 5gJFp3D00Q4yJbB0brgAhl4cfUG6nevYxScv0hLzbbIPN0el6gruUiffS33feb3

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

SET default_tablespace = '';

SET default_table_access_method = heap;

-- Prerrequisitos para el esquema y funciones usadas por el backend.
CREATE SCHEMA IF NOT EXISTS "AT";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

--
-- Name: estudiante_documentos; Type: TABLE; Schema: AT; Owner: -
--

CREATE TABLE "AT".auth_usuarios (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email varchar(255) NOT NULL UNIQUE,
    contrasena_hash text NOT NULL,
    activo boolean DEFAULT true,
    email_verificado boolean DEFAULT false,
    ultimo_login_en timestamptz NULL,
    creado_en timestamptz DEFAULT now(),
    actualizado_en timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS "AT".email_verification_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_usuario_id uuid NOT NULL REFERENCES "AT".auth_usuarios(id) ON DELETE CASCADE,
    token_hash text NOT NULL,
    expira_en timestamptz NOT NULL,
    usado_en timestamptz,
    creado_en timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_hash
ON "AT".email_verification_tokens(token_hash);

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
    CONSTRAINT tesis_pkey PRIMARY KEY (id),
    CONSTRAINT tesis_estado_check CHECK (((estado)::text = ANY ((ARRAY['borrador'::character varying, 'pendiente_pago'::character varying, 'en_progreso'::character varying, 'revision'::character varying, 'completado'::character varying, 'cancelado'::character varying])::text[])))
);


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
    CONSTRAINT documentos_tesis_pkey PRIMARY KEY (id),
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
    foto_url text,
    creado_en timestamp with time zone DEFAULT now(),
    actualizado_en timestamp with time zone DEFAULT now()
);

ALTER TABLE "AT".perfil_estudiante ADD COLUMN IF NOT EXISTS foto_url text;


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
    CONSTRAINT planes_pkey PRIMARY KEY (id),
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
    actualizado_en timestamp with time zone DEFAULT now(),
    CONSTRAINT planes_tipos_tesis_precios_pkey PRIMARY KEY (id)
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
    CONSTRAINT usuarios_pkey PRIMARY KEY (id),
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
-- PostgreSQL database dump complete
--

\unrestrict 5gJFp3D00Q4yJbB0brgAhl4cfUG6nevYxScv0hLzbbIPN0el6gruUiffS33feb3


create table if not exists "AT".tesis_references (
    id uuid primary key default gen_random_uuid(),

    tesis_id uuid not null references "AT".tesis(id) on delete cascade,

    data jsonb not null,

    version integer not null default 1,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz null
);
create table if not exists "AT".tesis_contents (
    id uuid primary key default gen_random_uuid(),

    tesis_id uuid not null references "AT".tesis(id) on delete cascade,

    data jsonb not null,

    version integer not null default 1,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz null
);

create index if not exists idx_tesis_references_tesis_active
on "AT".tesis_references (tesis_id)
where deleted_at is null;

create index if not exists idx_tesis_contents_tesis_active
on "AT".tesis_contents (tesis_id)
where deleted_at is null;
