BEGIN;
CREATE TABLE IF NOT EXISTS "AT".bibliography_settings (
 tesis_id uuid PRIMARY KEY REFERENCES "AT".tesis(id),
 style text NOT NULL DEFAULT 'APA7' CHECK(style IN ('APA7','IEEE','VANCOUVER','ISO690','MLA'))
);
CREATE TABLE IF NOT EXISTS "AT".bibliography_document_state (
 document_id uuid PRIMARY KEY REFERENCES "AT".documentos_tesis(id),
 revision text NOT NULL, library_fingerprint text NOT NULL, style text NOT NULL,
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS "AT".bibliography_links (
 document_id uuid NOT NULL REFERENCES "AT".documentos_tesis(id),
 reference_id uuid NOT NULL REFERENCES "AT".tesis_references(id),
 tag text NOT NULL, citation_count integer NOT NULL DEFAULT 0,
 PRIMARY KEY(document_id, tag)
);
CREATE INDEX IF NOT EXISTS bibliography_links_reference ON "AT".bibliography_links(reference_id);
CREATE TABLE IF NOT EXISTS "AT".bibliography_operations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), tesis_id uuid NOT NULL REFERENCES "AT".tesis(id),
 kind text NOT NULL, status text NOT NULL DEFAULT 'queued' CHECK(status IN ('queued','running','succeeded','partial','failed')),
 stage text NOT NULL DEFAULT 'En cola', payload jsonb NOT NULL DEFAULT '{}', result jsonb NOT NULL DEFAULT '{}',
 error text, warnings jsonb NOT NULL DEFAULT '[]', created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS bibliography_operations_queue ON "AT".bibliography_operations(created_at) WHERE status='queued';
CREATE TABLE IF NOT EXISTS "AT".bibliography_imports (
 id uuid PRIMARY KEY REFERENCES "AT".bibliography_operations(id), tesis_id uuid NOT NULL REFERENCES "AT".tesis(id),
 original_name text NOT NULL, source_path text NOT NULL, output_path text, created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE "AT".documentos_tesis_referencias ADD COLUMN IF NOT EXISTS canonical_reference_id uuid REFERENCES "AT".tesis_references(id);
-- Preserve existing UUIDs/versions. Only unambiguous normalized DOI matches or
-- exact title+authors+year matches are linked; files are never touched here.
WITH candidates AS (
 SELECT d.id, r.id AS canonical_id, count(*) OVER (PARTITION BY d.id) AS matches
 FROM "AT".documentos_tesis_referencias d
 JOIN "AT".documentos_tesis doc ON doc.id=d.documento_tesis_id
 JOIN "AT".tesis_references r ON r.tesis_id=doc.tesis_id AND r.deleted_at IS NULL
 WHERE d.deleted_at IS NULL AND lower(trim(d.title))=lower(trim(r.data->>'title'))
 AND coalesce(d.year::text,'')=coalesce(r.data->>'year','')
 AND d.authors::jsonb=r.data->'authors'
)
UPDATE "AT".documentos_tesis_referencias d SET canonical_reference_id=c.canonical_id
FROM candidates c WHERE d.id=c.id AND c.matches=1 AND d.canonical_reference_id IS NULL;
COMMIT;
