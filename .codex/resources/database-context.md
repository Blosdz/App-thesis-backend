# Database Context

The project uses PostgreSQL as the main database.

Supabase is no longer the backend foundation.

Core tables:

- auth_usuarios
- usuarios
- perfil_estudiante
- perfil_publico_asesor
- tesis
- asesores_tesis
- relaciones_asesor_estudiante
- reuniones_asesor
- disponibilidad_asesor
- documentos_tesis
- estudiante_documentos
- observaciones_tesis
- modificaciones_tesis
- pagos
- pagos_asesor
- pagos_plan
- planes
- suscripciones_estudiante
- universidades
- programas
- especialidades
- modulos_lista
- modulos_tesis
- mensajes
- historial_ia
- historial_sugerencias_asesor
- actividad_log
- codigos_publicos_asesor
- tarifas_asesor

Naming:

- Spanish table and column names.
- uuid primary keys.
- timestamptz for dates.
- jsonb for metadata.
- creado_en and actualizado_en convention.
- eliminado_en for soft delete where needed.

Backend:

- NestJS
- pg Pool
- JWT
- DTO validation
