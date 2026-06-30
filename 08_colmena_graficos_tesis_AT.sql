-- Tabla para persistir gráficos importados desde COLMENA (sub-app/tenant) y
-- asociarlos a una tesis, de modo que AppThesis pueda exportarlos en el Word.
-- Aplicar manualmente como el resto de scripts numerados.

CREATE TABLE IF NOT EXISTS "AT".colmena_graficos_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid NOT NULL,
    colmena_form_id character varying(64) NOT NULL,
    colmena_artifact_id character varying(64) NOT NULL,
    titulo character varying(255),
    mime_type character varying(100),
    data_base64 text NOT NULL,
    metadata jsonb,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT colmena_graficos_tesis_pkey PRIMARY KEY (id),
    CONSTRAINT colmena_graficos_tesis_tesis_id_fkey
        FOREIGN KEY (tesis_id) REFERENCES "AT".tesis (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_colmena_graficos_tesis_tesis_id
    ON "AT".colmena_graficos_tesis (tesis_id);

CREATE INDEX IF NOT EXISTS idx_colmena_graficos_tesis_artifact
    ON "AT".colmena_graficos_tesis (colmena_form_id, colmena_artifact_id);
