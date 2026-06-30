-- Extends skeleton_json in AT.doc_thesis_formats with a document_structure section
-- that defines the canonical section titles for each format type.
-- These sections are used to pre-populate tesis_sections when a format is applied.

UPDATE "AT".doc_thesis_formats
SET
    skeleton_json = skeleton_json || '{
        "document_structure": {
            "sections": [
                { "title": "Introducción",          "level": 1, "required": true,  "order": 1 },
                { "title": "Marco Teórico",          "level": 1, "required": true,  "order": 2 },
                { "title": "Marco Metodológico",     "level": 1, "required": true,  "order": 3 },
                { "title": "Resultados",             "level": 1, "required": true,  "order": 4 },
                { "title": "Discusión",              "level": 1, "required": false, "order": 5 },
                { "title": "Conclusiones",           "level": 1, "required": true,  "order": 6 },
                { "title": "Referencias",            "level": 1, "required": true,  "order": 7 }
            ]
        }
    }'::jsonb,
    updated_at = now()
WHERE uname = 'apa7';

UPDATE "AT".doc_thesis_formats
SET
    skeleton_json = skeleton_json || '{
        "document_structure": {
            "sections": [
                { "title": "Introducción",           "level": 1, "required": true,  "order": 1 },
                { "title": "Marco Teórico",          "level": 1, "required": true,  "order": 2 },
                { "title": "Marco Metodológico",     "level": 1, "required": true,  "order": 3 },
                { "title": "Resultados",             "level": 1, "required": true,  "order": 4 },
                { "title": "Discusión",              "level": 1, "required": false, "order": 5 },
                { "title": "Conclusiones",           "level": 1, "required": true,  "order": 6 },
                { "title": "Referencias",            "level": 1, "required": true,  "order": 7 }
            ]
        }
    }'::jsonb,
    updated_at = now()
WHERE uname = 'vancouver';

UPDATE "AT".doc_thesis_formats
SET
    skeleton_json = skeleton_json || '{
        "document_structure": {
            "sections": [
                { "title": "Introduction",           "level": 1, "required": true,  "order": 1 },
                { "title": "Background",             "level": 1, "required": true,  "order": 2 },
                { "title": "Methodology",            "level": 1, "required": true,  "order": 3 },
                { "title": "Results",                "level": 1, "required": true,  "order": 4 },
                { "title": "Discussion",             "level": 1, "required": false, "order": 5 },
                { "title": "Conclusion",             "level": 1, "required": true,  "order": 6 },
                { "title": "References",             "level": 1, "required": true,  "order": 7 }
            ]
        }
    }'::jsonb,
    updated_at = now()
WHERE uname = 'ieee';

UPDATE "AT".doc_thesis_formats
SET
    skeleton_json = skeleton_json || '{
        "document_structure": {
            "sections": [
                { "title": "Introducción",           "level": 1, "required": true,  "order": 1 },
                { "title": "Marco Teórico",          "level": 1, "required": true,  "order": 2 },
                { "title": "Marco Metodológico",     "level": 1, "required": true,  "order": 3 },
                { "title": "Resultados",             "level": 1, "required": true,  "order": 4 },
                { "title": "Discusión",              "level": 1, "required": false, "order": 5 },
                { "title": "Conclusiones",           "level": 1, "required": true,  "order": 6 },
                { "title": "Referencias",            "level": 1, "required": true,  "order": 7 }
            ]
        }
    }'::jsonb,
    updated_at = now()
WHERE uname = 'iso690';
