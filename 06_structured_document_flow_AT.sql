ALTER TABLE "AT".documentos_tesis
    ADD COLUMN IF NOT EXISTS raw_data_json jsonb,
    ADD COLUMN IF NOT EXISTS processing_status varchar(20) NOT NULL DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS processed_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS processing_error text NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'documentos_tesis_processing_status_check'
    ) THEN
        ALTER TABLE "AT".documentos_tesis
        ADD CONSTRAINT documentos_tesis_processing_status_check
        CHECK (processing_status IN ('pending', 'processing', 'processed', 'error', 'manual'));
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS "AT".documentos_tesis_secciones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    documento_tesis_id uuid NOT NULL REFERENCES "AT".documentos_tesis(id) ON DELETE CASCADE,
    heading text NOT NULL,
    level integer NOT NULL,
    content text NOT NULL DEFAULT '',
    order_index integer NOT NULL DEFAULT 0,
    parent_section_id uuid NULL REFERENCES "AT".documentos_tesis_secciones(id) ON DELETE SET NULL,
    source_paragraphs jsonb NOT NULL DEFAULT '[]'::jsonb,
    manual_override boolean NOT NULL DEFAULT false,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz NULL,
    CONSTRAINT documentos_tesis_secciones_level_check CHECK (level >= 1 AND level <= 6),
    CONSTRAINT documentos_tesis_secciones_order_check CHECK (order_index >= 0)
);

CREATE TABLE IF NOT EXISTS "AT".documentos_tesis_referencias (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    documento_tesis_id uuid NOT NULL REFERENCES "AT".documentos_tesis(id) ON DELETE CASCADE,
    type text NOT NULL,
    authors jsonb NOT NULL DEFAULT '[]'::jsonb,
    year integer NULL,
    title text NOT NULL,
    raw_text text NOT NULL DEFAULT '',
    style text NULL,
    source text NOT NULL DEFAULT 'text',
    confidence numeric(4,3) NOT NULL DEFAULT 0.500,
    version integer NOT NULL DEFAULT 1,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz NULL
);

CREATE INDEX IF NOT EXISTS idx_documentos_tesis_secciones_documento_active
    ON "AT".documentos_tesis_secciones (documento_tesis_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_documentos_tesis_referencias_documento_active
    ON "AT".documentos_tesis_referencias (documento_tesis_id)
    WHERE deleted_at IS NULL;
