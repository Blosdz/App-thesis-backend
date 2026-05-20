CREATE SCHEMA IF NOT EXISTS "AT";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS "AT".ai_conversations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tesis_id uuid NOT NULL,
    usuario_id uuid NOT NULL,
    documento_tesis_id uuid,
    user_message text NOT NULL,
    assistant_message text NOT NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_tesis_usuario_created
    ON "AT".ai_conversations (tesis_id, usuario_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_documento_created
    ON "AT".ai_conversations (documento_tesis_id, created_at DESC)
    WHERE documento_tesis_id IS NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'tesis_pkey'
          AND conrelid = '"AT".tesis'::regclass
    ) THEN
        ALTER TABLE "AT".tesis
            ADD CONSTRAINT tesis_pkey PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'usuarios_pkey'
          AND conrelid = '"AT".usuarios'::regclass
    ) THEN
        ALTER TABLE "AT".usuarios
            ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'documentos_tesis_pkey'
          AND conrelid = '"AT".documentos_tesis'::regclass
    ) THEN
        ALTER TABLE "AT".documentos_tesis
            ADD CONSTRAINT documentos_tesis_pkey PRIMARY KEY (id);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ai_conversations_tesis_id_fkey'
          AND conrelid = '"AT".ai_conversations'::regclass
    ) THEN
        ALTER TABLE "AT".ai_conversations
            ADD CONSTRAINT ai_conversations_tesis_id_fkey
            FOREIGN KEY (tesis_id)
            REFERENCES "AT".tesis(id)
            ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ai_conversations_usuario_id_fkey'
          AND conrelid = '"AT".ai_conversations'::regclass
    ) THEN
        ALTER TABLE "AT".ai_conversations
            ADD CONSTRAINT ai_conversations_usuario_id_fkey
            FOREIGN KEY (usuario_id)
            REFERENCES "AT".usuarios(id)
            ON DELETE CASCADE;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'ai_conversations_documento_tesis_id_fkey'
          AND conrelid = '"AT".ai_conversations'::regclass
    ) THEN
        ALTER TABLE "AT".ai_conversations
            ADD CONSTRAINT ai_conversations_documento_tesis_id_fkey
            FOREIGN KEY (documento_tesis_id)
            REFERENCES "AT".documentos_tesis(id)
            ON DELETE SET NULL;
    END IF;
END $$;
