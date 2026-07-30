-- Tabla para persistir baremos (escalas de puntuación) importados desde
-- COLMENA y asociarlos a una tesis, análoga a colmena_graficos_tesis.
-- Aplicar manualmente como el resto de scripts numerados.

CREATE TABLE IF NOT EXISTS "AT".colmena_baremos_tesis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tesis_id uuid NOT NULL,
    colmena_form_id character varying(64) NOT NULL,
    colmena_scoring_config_id character varying(64) NOT NULL,
    titulo character varying(255),
    config_name character varying(255),
    variable_label character varying(255),
    scoring_level character varying(64),
    levels jsonb NOT NULL DEFAULT '[]'::jsonb,
    metadata jsonb,
    creado_en timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT colmena_baremos_tesis_pkey PRIMARY KEY (id),
    CONSTRAINT colmena_baremos_tesis_tesis_id_fkey
        FOREIGN KEY (tesis_id) REFERENCES "AT".tesis (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_colmena_baremos_tesis_tesis_id
    ON "AT".colmena_baremos_tesis (tesis_id);

CREATE INDEX IF NOT EXISTS idx_colmena_baremos_tesis_config
    ON "AT".colmena_baremos_tesis (colmena_form_id, colmena_scoring_config_id);
