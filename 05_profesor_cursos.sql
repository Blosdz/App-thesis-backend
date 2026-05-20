-- ============================================================
-- 1. Cursos publicados por asesores
-- ============================================================

CREATE TABLE IF NOT EXISTS "AT".profesor_cursos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    asesor_id uuid NOT NULL,

    titulo text NOT NULL,
    descripcion text,

    precio numeric(10,2) NOT NULL DEFAULT 0,
    moneda varchar(10) NOT NULL DEFAULT 'PEN',

    portada_drive_id text,
    portada_url_drive text,

    estado varchar(20) NOT NULL DEFAULT 'borrador',
    activo boolean NOT NULL DEFAULT true,

    metadata jsonb DEFAULT '{}'::jsonb,

    creado_en timestamptz NOT NULL DEFAULT now(),
    actualizado_en timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT profesor_cursos_precio_check CHECK (precio >= 0),

    CONSTRAINT profesor_cursos_estado_check CHECK (
        estado IN ('borrador', 'publicado', 'pausado', 'archivado')
    ),

    CONSTRAINT profesor_cursos_asesor_fk
        FOREIGN KEY (asesor_id)
        REFERENCES "AT".usuarios(id)
        ON DELETE RESTRICT
);

-- ============================================================
-- 2. Materiales del curso
-- Pueden ser videos, documentos, enlaces, plantillas, archivos, etc.
-- ============================================================

CREATE TABLE IF NOT EXISTS "AT".profesor_curso_materiales (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    curso_id uuid NOT NULL,

    titulo text NOT NULL,
    descripcion text,

    tipo varchar(30) NOT NULL DEFAULT 'documento',

    -- Compatibilidad con integraciones anteriores
    drive_file_id text,
    drive_folder_id text,
    url_drive text,

    -- Storage local del backend
    ruta_storage text,
    url_storage text,

    nombre_archivo text,
    tipo_mime varchar(150),
    tamano_bytes bigint,

    -- Para videos externos o recursos que no sean archivo directo
    url_externa text,

    -- Orden visible dentro del curso: 1, 2, 3...
    orden integer NOT NULL DEFAULT 1,

    es_vista_previa boolean NOT NULL DEFAULT false,
    activo boolean NOT NULL DEFAULT true,

    metadata jsonb DEFAULT '{}'::jsonb,

    creado_en timestamptz NOT NULL DEFAULT now(),
    actualizado_en timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT profesor_curso_materiales_orden_check CHECK (orden > 0),

    CONSTRAINT profesor_curso_materiales_tipo_check CHECK (
        tipo IN ('documento', 'video', 'link', 'plantilla', 'imagen', 'zip', 'otro')
    ),

    CONSTRAINT profesor_curso_materiales_curso_fk
        FOREIGN KEY (curso_id)
        REFERENCES "AT".profesor_cursos(id)
        ON DELETE CASCADE
);


-- ============================================================
-- 3. Cursos comprados por estudiantes
-- ============================================================

CREATE TABLE IF NOT EXISTS "AT".estudiante_cursos (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    estudiante_id uuid NOT NULL,
    curso_id uuid NOT NULL,

    pago_id uuid,

    estado varchar(20) NOT NULL DEFAULT 'pendiente_pago',

    precio_pagado numeric(10,2),
    moneda varchar(10) NOT NULL DEFAULT 'PEN',

    comprado_en timestamptz,
    acceso_habilitado_en timestamptz,
    expira_en timestamptz,

    activo boolean NOT NULL DEFAULT true,

    metadata jsonb DEFAULT '{}'::jsonb,

    creado_en timestamptz NOT NULL DEFAULT now(),
    actualizado_en timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT estudiante_cursos_estado_check CHECK (
        estado IN ('pendiente_pago', 'activo', 'vencido', 'cancelado', 'reembolsado')
    ),

    CONSTRAINT estudiante_cursos_estudiante_fk
        FOREIGN KEY (estudiante_id)
        REFERENCES "AT".usuarios(id)
        ON DELETE RESTRICT,

    CONSTRAINT estudiante_cursos_curso_fk
        FOREIGN KEY (curso_id)
        REFERENCES "AT".profesor_cursos(id)
        ON DELETE RESTRICT,

    CONSTRAINT estudiante_cursos_pago_fk
        FOREIGN KEY (pago_id)
        REFERENCES "AT".pagos(id)
        ON DELETE SET NULL,

    CONSTRAINT estudiante_cursos_unico UNIQUE (estudiante_id, curso_id)
);

CREATE INDEX IF NOT EXISTS idx_profesor_cursos_asesor_id
ON "AT".profesor_cursos(asesor_id);

CREATE INDEX IF NOT EXISTS idx_profesor_cursos_estado
ON "AT".profesor_cursos(estado);

CREATE INDEX IF NOT EXISTS idx_profesor_curso_materiales_curso_id
ON "AT".profesor_curso_materiales(curso_id);

CREATE INDEX IF NOT EXISTS idx_profesor_curso_materiales_orden
ON "AT".profesor_curso_materiales(curso_id, orden);

ALTER TABLE "AT".profesor_curso_materiales ADD COLUMN IF NOT EXISTS ruta_storage text;
ALTER TABLE "AT".profesor_curso_materiales ADD COLUMN IF NOT EXISTS url_storage text;

CREATE INDEX IF NOT EXISTS idx_estudiante_cursos_estudiante_id
ON "AT".estudiante_cursos(estudiante_id);

CREATE INDEX IF NOT EXISTS idx_estudiante_cursos_curso_id
ON "AT".estudiante_cursos(curso_id);

CREATE INDEX IF NOT EXISTS idx_estudiante_cursos_pago_id
ON "AT".estudiante_cursos(pago_id);

CREATE OR REPLACE VIEW "AT".vw_profesor_cursos_publicos AS
SELECT
    pc.id,
    pc.asesor_id,
    ppa.nombre_mostrar AS asesor_nombre,
    ppa.foto_url AS asesor_foto_url,
    ppa.slug AS asesor_slug,
    pc.titulo,
    pc.descripcion,
    pc.precio,
    pc.moneda,
    pc.portada_url_drive,
    pc.estado,
    pc.activo,
    pc.creado_en,
    COUNT(pm.id) AS total_materiales
FROM "AT".profesor_cursos pc
LEFT JOIN "AT".perfil_publico_asesor ppa
    ON ppa.asesor_id = pc.asesor_id
LEFT JOIN "AT".profesor_curso_materiales pm
    ON pm.curso_id = pc.id
   AND pm.activo = true
WHERE pc.estado = 'publicado'
  AND pc.activo = true
GROUP BY
    pc.id,
    pc.asesor_id,
    ppa.nombre_mostrar,
    ppa.foto_url,
    ppa.slug,
    pc.titulo,
    pc.descripcion,
    pc.precio,
    pc.moneda,
    pc.portada_url_drive,
    pc.estado,
    pc.activo,
    pc.creado_en;

CREATE OR REPLACE VIEW "AT".vw_estudiante_cursos_activos AS
SELECT
    ec.id AS estudiante_curso_id,
    ec.estudiante_id,
    ec.curso_id,
    pc.asesor_id,
    pc.titulo,
    pc.descripcion,
    pc.precio,
    pc.moneda,
    ec.estado,
    ec.comprado_en,
    ec.expira_en,
    ec.activo
FROM "AT".estudiante_cursos ec
INNER JOIN "AT".profesor_cursos pc
    ON pc.id = ec.curso_id
WHERE ec.estado = 'activo'
  AND ec.activo = true
  AND pc.activo = true
  AND pc.estado = 'publicado'
  AND (
        ec.expira_en IS NULL
        OR ec.expira_en > now()
  );
