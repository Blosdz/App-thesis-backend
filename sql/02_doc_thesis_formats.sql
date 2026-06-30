CREATE SCHEMA IF NOT EXISTS "AT";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS "AT".doc_thesis_formats (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(120) NOT NULL,
    uname varchar(60) NOT NULL UNIQUE,
    citation_type varchar(40) NOT NULL,
    skeleton_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    word_settings_json jsonb NOT NULL DEFAULT '{}'::jsonb,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT doc_thesis_formats_uname_check
        CHECK (uname ~ '^[a-z0-9][a-z0-9_-]*$')
);

COMMENT ON TABLE "AT".doc_thesis_formats IS
'Catalogo de formatos de tesis/citacion usados por el editor y el generador DOCX.';

COMMENT ON COLUMN "AT".doc_thesis_formats.uname IS
'Nombre unico estable para integraciones: apa7, vancouver, ieee, iso690, mla.';

COMMENT ON COLUMN "AT".doc_thesis_formats.skeleton_json IS
'Reglas para construir citas en texto y bibliografia por tipo de referencia.';

COMMENT ON COLUMN "AT".doc_thesis_formats.word_settings_json IS
'Reglas de estructura Word/DOCX: headings, bibliografia, campos, locale y estilos.';

INSERT INTO "AT".doc_thesis_formats (
    name,
    uname,
    citation_type,
    skeleton_json,
    word_settings_json
)
VALUES
(
    'APA 7',
    'apa7',
    'author_year',
    '{
        "inline_citation": {
            "mode": "author_year",
            "templates": {
                "one_author": "({author_last}, {year})",
                "two_authors": "({author_last_1} & {author_last_2}, {year})",
                "three_or_more_authors": "({author_last_1} et al., {year})",
                "no_author": "({title}, {year})",
                "no_year": "({author_text}, s. f.)"
            }
        },
        "bibliography": {
            "sort": ["author", "year", "title"],
            "hanging_indent": true,
            "templates": {
                "book": "{authors}. ({year}). {title}. {publisher}.",
                "article": "{authors}. ({year}). {title}. {journal}. {doi_or_url}",
                "web": "{authors}. ({year}). {title}. {url}"
            }
        },
        "reference_fields": {
            "required": ["authors", "title", "type"],
            "book": ["publisher"],
            "article": ["journal"],
            "web": ["url_or_doi"]
        }
    }'::jsonb,
    '{
        "document": {
            "locale": "10250",
            "font": "Times New Roman",
            "font_size_pt": 12,
            "line_spacing": "double",
            "paragraph_alignment": "left"
        },
        "headings": {
            "main_levels": [1, 2, 3],
            "subtitle_level_offset": 1,
            "numbering": "decimal"
        },
        "toc": {
            "field": "TOC \\\\o \"1-3\" \\\\h \\\\z \\\\u",
            "render_before_export": true
        },
        "citations": {
            "native_word_field": true,
            "field_instruction": "CITATION {tag} \\\\m {tag}",
            "visible_result": "inline_citation"
        },
        "bibliography": {
            "heading": "Referencias",
            "field_instruction": "BIBLIOGRAPHY \\\\l 10250",
            "word_style": "APA",
            "selected_style": "/APA.XSL"
        }
    }'::jsonb
),
(
    'Vancouver',
    'vancouver',
    'numeric',
    '{
        "inline_citation": {
            "mode": "numeric",
            "templates": {
                "single": "({number})",
                "range": "({first_number}-{last_number})",
                "list": "({numbers})"
            }
        },
        "bibliography": {
            "sort": ["first_appearance"],
            "numbered": true,
            "templates": {
                "book": "{number}. {authors}. {title}. {publisher}; {year}.",
                "article": "{number}. {authors}. {title}. {journal}. {year};{volume}({issue}):{pages}. {doi_or_url}",
                "web": "{number}. {authors}. {title} [Internet]. {year} [cited {accessed_at}]. Available from: {url}"
            }
        },
        "reference_fields": {
            "required": ["authors", "title", "type"],
            "book": ["publisher", "year"],
            "article": ["journal", "year"],
            "web": ["url"]
        }
    }'::jsonb,
    '{
        "document": {
            "locale": "10250",
            "font": "Times New Roman",
            "font_size_pt": 12,
            "line_spacing": "double",
            "paragraph_alignment": "left"
        },
        "headings": {
            "main_levels": [1, 2, 3],
            "subtitle_level_offset": 1,
            "numbering": "decimal"
        },
        "toc": {
            "field": "TOC \\\\o \"1-3\" \\\\h \\\\z \\\\u",
            "render_before_export": true
        },
        "citations": {
            "native_word_field": true,
            "field_instruction": "CITATION {tag} \\\\m {tag}",
            "visible_result": "inline_citation"
        },
        "bibliography": {
            "heading": "Referencias",
            "field_instruction": "BIBLIOGRAPHY \\\\l 10250",
            "word_style": "Vancouver",
            "selected_style": "/Vancouver.XSL"
        }
    }'::jsonb
),
(
    'IEEE',
    'ieee',
    'numeric',
    '{
        "inline_citation": {
            "mode": "numeric",
            "templates": {
                "single": "[{number}]",
                "range": "[{first_number}]-[{last_number}]",
                "list": "[{numbers}]"
            }
        },
        "bibliography": {
            "sort": ["first_appearance"],
            "numbered": true,
            "templates": {
                "book": "[{number}] {authors}, {title}. {publisher}, {year}.",
                "article": "[{number}] {authors}, \"{title},\" {journal}, {year}. {doi_or_url}",
                "web": "[{number}] {authors}, \"{title}.\" {url}"
            }
        },
        "reference_fields": {
            "required": ["authors", "title", "type"],
            "book": ["publisher", "year"],
            "article": ["journal", "year"],
            "web": ["url_or_doi"]
        }
    }'::jsonb,
    '{
        "document": {
            "locale": "10250",
            "font": "Times New Roman",
            "font_size_pt": 12,
            "line_spacing": "double",
            "paragraph_alignment": "left"
        },
        "headings": {
            "main_levels": [1, 2, 3],
            "subtitle_level_offset": 1,
            "numbering": "decimal"
        },
        "toc": {
            "field": "TOC \\\\o \"1-3\" \\\\h \\\\z \\\\u",
            "render_before_export": true
        },
        "citations": {
            "native_word_field": true,
            "field_instruction": "CITATION {tag} \\\\m {tag}",
            "visible_result": "inline_citation"
        },
        "bibliography": {
            "heading": "Referencias",
            "field_instruction": "BIBLIOGRAPHY \\\\l 10250",
            "word_style": "IEEE",
            "selected_style": "/IEEE.XSL"
        }
    }'::jsonb
),
(
    'ISO 690',
    'iso690',
    'author_year',
    '{
        "inline_citation": {
            "mode": "author_year_upper",
            "templates": {
                "one_author": "({author_last_upper}, {year})",
                "two_authors": "({author_last_1_upper} y {author_last_2_upper}, {year})",
                "three_or_more_authors": "({author_last_1_upper} et al., {year})",
                "no_author": "({title}, {year})",
                "no_year": "({author_text_upper}, s. f.)"
            }
        },
        "bibliography": {
            "sort": ["author", "year", "title"],
            "templates": {
                "book": "{authors_upper}. {title}. {publisher}, {year}.",
                "article": "{authors_upper}. {title}. {journal}, {year}. {doi_or_url}",
                "web": "{authors_upper}. {title} [en linea]. {year} [consulta: {accessed_at}]. Disponible en: {url}"
            }
        },
        "reference_fields": {
            "required": ["authors", "title", "type"],
            "book": ["publisher"],
            "article": ["journal"],
            "web": ["url"]
        }
    }'::jsonb,
    '{
        "document": {
            "locale": "10250",
            "font": "Times New Roman",
            "font_size_pt": 12,
            "line_spacing": "double",
            "paragraph_alignment": "left"
        },
        "headings": {
            "main_levels": [1, 2, 3],
            "subtitle_level_offset": 1,
            "numbering": "decimal"
        },
        "toc": {
            "field": "TOC \\\\o \"1-3\" \\\\h \\\\z \\\\u",
            "render_before_export": true
        },
        "citations": {
            "native_word_field": true,
            "field_instruction": "CITATION {tag} \\\\m {tag}",
            "visible_result": "inline_citation"
        },
        "bibliography": {
            "heading": "Referencias",
            "field_instruction": "BIBLIOGRAPHY \\\\l 10250",
            "word_style": "ISO 690",
            "selected_style": "/ISO690.XSL"
        }
    }'::jsonb
),
(
    'MLA',
    'mla',
    'author_year',
    '{
        "inline_citation": {
            "mode": "author_year",
            "templates": {
                "one_author": "({author_last})",
                "two_authors": "({author_last_1} and {author_last_2})",
                "three_or_more_authors": "({author_last_1} et al.)",
                "no_author": "({title})",
                "no_year": "({author_last})"
            }
        },
        "bibliography": {
            "sort": ["author", "year", "title"],
            "hanging_indent": true,
            "templates": {
                "book": "{authors}. {title}. {publisher}, {year}.",
                "article": "{authors}. \"{title}.\" {journal}, vol. {volume}, no. {issue}, {year}, pp. {pages}. {doi_or_url}",
                "web": "{authors}. \"{title}.\" {year}, {url}. Accessed {accessed_at}."
            }
        },
        "reference_fields": {
            "required": ["authors", "title", "type"],
            "book": ["publisher"],
            "article": ["journal"],
            "web": ["url_or_doi"]
        }
    }'::jsonb,
    '{
        "document": {
            "locale": "10250",
            "font": "Times New Roman",
            "font_size_pt": 12,
            "line_spacing": "double",
            "paragraph_alignment": "left"
        },
        "headings": {
            "main_levels": [1, 2, 3],
            "subtitle_level_offset": 1,
            "numbering": "decimal"
        },
        "toc": {
            "field": "TOC \\\\o \"1-3\" \\\\h \\\\z \\\\u",
            "render_before_export": true
        },
        "citations": {
            "native_word_field": true,
            "field_instruction": "CITATION {tag} \\\\m {tag}",
            "visible_result": "inline_citation"
        },
        "bibliography": {
            "heading": "Works Cited",
            "field_instruction": "BIBLIOGRAPHY \\\\l 10250",
            "word_style": "MLA",
            "selected_style": "/MLA.XSL"
        }
    }'::jsonb
)
ON CONFLICT (uname) DO UPDATE
SET
    name = EXCLUDED.name,
    citation_type = EXCLUDED.citation_type,
    skeleton_json = EXCLUDED.skeleton_json,
    word_settings_json = EXCLUDED.word_settings_json,
    active = true,
    updated_at = now();

ALTER TABLE "AT".tesis
ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE "AT".tesis
ALTER COLUMN metadata SET DEFAULT '{
    "doc_thesis_format": "apa7",
    "citation_style": "apa7",
    "citation_mode": "author_year"
}'::jsonb;

ALTER TABLE "AT".tesis
ADD COLUMN IF NOT EXISTS doc_thesis_format_id uuid
REFERENCES "AT".doc_thesis_formats(id);

ALTER TABLE "AT".tipos_tesis
ADD COLUMN IF NOT EXISTS default_doc_thesis_format_id uuid
REFERENCES "AT".doc_thesis_formats(id);

UPDATE "AT".tipos_tesis AS tt
SET
    default_doc_thesis_format_id = f.id,
    actualizado_en = now()
FROM "AT".doc_thesis_formats AS f
WHERE f.uname = 'apa7'
  AND tt.default_doc_thesis_format_id IS NULL;

UPDATE "AT".tesis AS t
SET
    doc_thesis_format_id = COALESCE(
        (
            SELECT tf.id
            FROM "AT".tipos_tesis AS tt
            JOIN "AT".doc_thesis_formats AS tf
              ON tf.id = tt.default_doc_thesis_format_id
            WHERE tt.id = t.tipo_tesis_id
              AND tf.active = true
            LIMIT 1
        ),
        f.id
    ),
    metadata = COALESCE(t.metadata, '{}'::jsonb)
        || jsonb_build_object(
            'doc_thesis_format', COALESCE(
                (
                    SELECT tf.uname
                    FROM "AT".tipos_tesis AS tt
                    JOIN "AT".doc_thesis_formats AS tf
                      ON tf.id = tt.default_doc_thesis_format_id
                    WHERE tt.id = t.tipo_tesis_id
                      AND tf.active = true
                    LIMIT 1
                ),
                f.uname
            ),
            'citation_style', COALESCE(
                (
                    SELECT tf.uname
                    FROM "AT".tipos_tesis AS tt
                    JOIN "AT".doc_thesis_formats AS tf
                      ON tf.id = tt.default_doc_thesis_format_id
                    WHERE tt.id = t.tipo_tesis_id
                      AND tf.active = true
                    LIMIT 1
                ),
                f.uname
            ),
            'citation_mode', COALESCE(
                (
                    SELECT tf.citation_type
                    FROM "AT".tipos_tesis AS tt
                    JOIN "AT".doc_thesis_formats AS tf
                      ON tf.id = tt.default_doc_thesis_format_id
                    WHERE tt.id = t.tipo_tesis_id
                      AND tf.active = true
                    LIMIT 1
                ),
                f.citation_type
            )
        )
FROM "AT".doc_thesis_formats AS f
WHERE f.uname = COALESCE(t.metadata->>'doc_thesis_format', t.metadata->>'citation_style', 'apa7')
  AND (t.doc_thesis_format_id IS NULL OR (t.metadata ? 'doc_thesis_format') = false);

CREATE INDEX IF NOT EXISTS idx_doc_thesis_formats_uname_active
ON "AT".doc_thesis_formats (uname)
WHERE active = true;

CREATE INDEX IF NOT EXISTS idx_tesis_doc_thesis_format_id
ON "AT".tesis (doc_thesis_format_id);

CREATE INDEX IF NOT EXISTS idx_tipos_tesis_default_doc_thesis_format_id
ON "AT".tipos_tesis (default_doc_thesis_format_id);

CREATE OR REPLACE FUNCTION "AT".apply_tesis_doc_thesis_format()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    selected_format "AT".doc_thesis_formats%ROWTYPE;
    selected_uname text;
BEGIN
    NEW.metadata := COALESCE(NEW.metadata, '{}'::jsonb);
    selected_uname := COALESCE(
        NEW.metadata->>'doc_thesis_format',
        NEW.metadata->>'citation_style'
    );

    -- An explicit format selection (set by the app in metadata) always wins.
    IF selected_uname IS NOT NULL THEN
        SELECT *
        INTO selected_format
        FROM "AT".doc_thesis_formats
        WHERE uname = selected_uname
          AND active = true
        LIMIT 1;
    END IF;

    -- Otherwise fall back to the thesis type's default format.
    IF selected_format.id IS NULL AND NEW.tipo_tesis_id IS NOT NULL THEN
        SELECT f.*
        INTO selected_format
        FROM "AT".tipos_tesis AS tt
        JOIN "AT".doc_thesis_formats AS f
          ON f.id = tt.default_doc_thesis_format_id
        WHERE tt.id = NEW.tipo_tesis_id
          AND f.active = true
        LIMIT 1;
    END IF;

    IF selected_format.id IS NULL THEN
        SELECT *
        INTO selected_format
        FROM "AT".doc_thesis_formats
        WHERE uname = 'apa7'
          AND active = true
        LIMIT 1;
    END IF;

    IF selected_format.id IS NOT NULL THEN
        NEW.doc_thesis_format_id := selected_format.id;
        NEW.metadata := NEW.metadata || jsonb_build_object(
            'doc_thesis_format', selected_format.uname,
            'citation_style', selected_format.uname,
            'citation_mode', selected_format.citation_type
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_tesis_doc_thesis_format ON "AT".tesis;

CREATE TRIGGER trg_apply_tesis_doc_thesis_format
BEFORE INSERT OR UPDATE OF metadata, doc_thesis_format_id, tipo_tesis_id
ON "AT".tesis
FOR EACH ROW
EXECUTE FUNCTION "AT".apply_tesis_doc_thesis_format();
