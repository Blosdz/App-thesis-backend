-- =============================================================================
-- Migration 08: tesis_sections — adjacency list hierarchy
-- =============================================================================
-- Replaces the tesis_contents JSON-blob pattern with a proper relational table.
-- Each section is a row; parent-child relationships are expressed via parent_id
-- (self-referential FK), enabling queries like CTEs / recursive tree traversal.
--
-- Existing tesis_contents rows are migrated:
--   - Each top-level blob becomes a level-1 row with parent_id = NULL
--   - Each embedded subsection becomes a level-2 row with parent_id pointing
--     to its parent tesis_sections row
--
-- tesis_contents is NOT dropped — it remains for the transition period.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Create table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "AT".tesis_sections (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    tesis_id    uuid        NOT NULL REFERENCES "AT".tesis(id) ON DELETE CASCADE,
    parent_id   uuid        NULL     REFERENCES "AT".tesis_sections(id) ON DELETE CASCADE,
    title       text        NOT NULL,
    content     text        NOT NULL DEFAULT '',
    level       int         NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 6),
    order_index int         NOT NULL DEFAULT 0,
    version     int         NOT NULL DEFAULT 1,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),
    deleted_at  timestamptz NULL
);

-- -----------------------------------------------------------------------------
-- 2. Indexes
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS tesis_sections_tesis_id_idx
    ON "AT".tesis_sections (tesis_id, deleted_at);

CREATE INDEX IF NOT EXISTS tesis_sections_parent_id_idx
    ON "AT".tesis_sections (parent_id);

-- -----------------------------------------------------------------------------
-- 3. Auto-update updated_at on every row change
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "AT".tesis_sections_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tesis_sections_updated_at ON "AT".tesis_sections;
CREATE TRIGGER trg_tesis_sections_updated_at
    BEFORE UPDATE ON "AT".tesis_sections
    FOR EACH ROW EXECUTE FUNCTION "AT".tesis_sections_set_updated_at();

-- -----------------------------------------------------------------------------
-- 4. Migrate existing tesis_contents rows
-- -----------------------------------------------------------------------------

-- 4a. Root sections (level 1) — one row per tesis_contents blob
INSERT INTO "AT".tesis_sections
    (tesis_id, parent_id, title, content, level, order_index, created_at, updated_at)
SELECT
    tesis_id,
    NULL,
    data->>'title',
    COALESCE(data->>'content', ''),
    COALESCE((data->>'level')::int, 1),
    COALESCE((data->>'order')::int, 0),
    created_at,
    updated_at
FROM "AT".tesis_contents
WHERE deleted_at IS NULL
  AND data->>'title' IS NOT NULL
ON CONFLICT DO NOTHING;

-- 4b. Embedded subsections (level 2) — each subsections[] element becomes a row
INSERT INTO "AT".tesis_sections
    (tesis_id, parent_id, title, content, level, order_index, created_at, updated_at)
SELECT
    tc.tesis_id,
    ts.id                            AS parent_id,
    sub->>'title'                    AS title,
    COALESCE(sub->>'content', '')    AS content,
    2                                AS level,
    (idx - 1)::int                   AS order_index,
    tc.created_at,
    tc.updated_at
FROM "AT".tesis_contents tc
JOIN "AT".tesis_sections ts
    ON  ts.tesis_id    = tc.tesis_id
    AND ts.title       = tc.data->>'title'
    AND ts.parent_id   IS NULL
    AND ts.deleted_at  IS NULL
CROSS JOIN LATERAL
    jsonb_array_elements(
        COALESCE(tc.data->'subsections', '[]'::jsonb)
    ) WITH ORDINALITY AS t(sub, idx)
WHERE tc.deleted_at IS NULL
  AND tc.data->>'title' IS NOT NULL
  AND (sub->>'title') IS NOT NULL
ON CONFLICT DO NOTHING;
