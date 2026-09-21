# Bibliografía integrada v1

React → NestJS JWT → servicio Python privado → PostgreSQL y archivos locales.
Base pública `/tesis/:tesisId/bibliografia`; privada `/theses/{tesis_id}/bibliography`.
El estudiante propietario y admin pueden escribir; asesor asignado puede consultar. Todos los identificadores son UUID. No exponer Python directamente a Internet.

| Método | Sufijo | Contrato |
| --- | --- | --- |
| GET | workspace?document_id=UUID | references, bibliography, style, document {editable, revision, style, sync_label}, citation_count |
| POST | referencias | escritura estructurada |
| PATCH | referencias/:id | escritura + expected_version obligatorio |
| DELETE | referencias/:id | bloquea si existen citas nativas |
| POST | preview | {reference, style} → bibliography, parenthetical, narrative |
| POST | resolver-doi | {doi} → status, message, proposal (revisión explícita) |
| POST | importaciones | multipart `file`, DOCX ≤20 MB; devuelve operación |
| GET | importaciones/:id | operación de importación |
| GET | importaciones/:id/archivo | DOCX derivado |
| POST | documentos/:id/extraer | {expected_revision} → operación |
| POST | documentos/:id/sincronizar | {expected_revision} → operación |
| PUT | estilo | {style, document_id?, sync_document, expected_revision?} |
| POST | exportaciones | operación |
| GET | operaciones/:id | estado persistente |
| GET | operaciones/:id/archivo | exportación DOCX |
| GET | plantilla | plantilla DOCX explicativa |

Escritura: `{reference: {authors:[{first_name,last_name,corporate}], title,type,year?,publisher?,journal?,volume?,issue?,pages?,doi?,url?,accessed_at?,institution?,repository?,degree?,container_title?,editors?:string[],conference?,proceedings?,edition?},expected_version?,document_id?,sync_document:boolean,expected_revision?}`.
Tipos: article/book/chapter/thesis/web/report/conference. Normas: APA7, IEEE, VANCOUVER (paréntesis), ISO690 (autor-fecha), MLA (9).

Operaciones: HTTP 202, `{operation_id,status,stage,result?,warnings?,error?}`. Estados queued/running/succeeded/partial/failed. Sin porcentajes simulados. Worker PostgreSQL con SKIP LOCKED; operaciones interrumpidas se marcan fallidas para reintento. Revisión = SHA-256 del archivo, independiente de la versión visible en historial. Una escritura guardada en biblioteca puede devolver partial si falla Word. No se anuncian cambios sincronizados hasta validar el paquete resultante.

Errores: 401 JWT, 404 sin acceso o inexistente, 409 revisión/versión desactualizada o fuente citada, 413 tamaño, 415 extensión, 422 datos/paquete inválidos, 503 procesamiento no disponible. Descargas por JWT; avance utiliza `/ai/tesis/documentos/:id/download` tras sincronizar. Rutas anteriores conservadas.
