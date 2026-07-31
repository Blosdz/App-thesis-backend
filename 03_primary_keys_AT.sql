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

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'planes_pkey'
          AND conrelid = '"AT".planes'::regclass
    ) THEN
        ALTER TABLE "AT".planes
            ADD CONSTRAINT planes_pkey PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'planes_tipos_tesis_precios_pkey'
          AND conrelid = '"AT".planes_tipos_tesis_precios'::regclass
    ) THEN
        ALTER TABLE "AT".planes_tipos_tesis_precios
            ADD CONSTRAINT planes_tipos_tesis_precios_pkey PRIMARY KEY (id);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'pagos_pkey'
          AND conrelid = '"AT".pagos'::regclass
    ) THEN
        ALTER TABLE "AT".pagos
            ADD CONSTRAINT pagos_pkey PRIMARY KEY (id);
    END IF;
END $$;
