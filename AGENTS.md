# AGENTS.md — Thesis Assistant Backend

## Project context

This backend replaces the previous Supabase-dependent architecture.

Supabase is relegated. Do not assume Supabase Auth, Supabase RPC, Supabase Storage, Supabase Edge Functions, or automatic Supabase APIs unless explicitly requested.

Target architecture:

React frontend
→ NestJS secure backend API
→ PostgreSQL
→ SQL / PLpgSQL functions
→ tables

React must never connect directly to PostgreSQL.

## Main backend rule

NestJS is an API gateway and security layer.

NestJS must:

- expose REST endpoints
- validate DTOs
- verify JWT
- apply role guards
- call PostgreSQL functions using parameterized queries
- return clean JSON to React

NestJS must not:

- duplicate complex business logic already implemented in SQL functions
- concatenate SQL with user input
- expose database credentials
- return password hashes
- use Supabase unless explicitly requested

PostgreSQL owns:

- tables
- relations
- constraints
- triggers
- PLpgSQL business functions
- password hashing with pgcrypto
- core transactional logic

## Database conventions

The database uses:

- uuid
- jsonb
- timestamptz
- Spanish table and column names

Important tables:

- auth_usuarios
- usuarios
- perfil_estudiante
- perfil_publico_asesor
- datos_privados_estudiante
- datos_privados_asesor
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

## Auth rules

Do not use Supabase Auth.

Use a local table:

auth_usuarios:

- id uuid primary key default gen_random_uuid()
- email varchar(255) unique not null
- contrasena_hash text not null
- activo boolean default true
- email_verificado boolean default false
- ultimo_login_en timestamptz
- creado_en timestamptz default now()
- actualizado_en timestamptz default now()

Password hashing is done inside PostgreSQL, not in NestJS.

Required extension:

CREATE EXTENSION IF NOT EXISTS pgcrypto;

Create password hash:

crypt(p_contrasena, gen_salt('bf', 12))

Validate password:

contrasena_hash = crypt(p_contrasena, contrasena_hash)

Default initial password may be:

app_theseis

But it must always be stored hashed, never as plain text.

Never use md5() for passwords.

## NestJS structure

Use this structure:

src/
main.ts
app.module.ts

common/
guards/
jwt-auth.guard.ts
roles.guard.ts
decorators/
current-user.decorator.ts
roles.decorator.ts
interfaces/
current-user.interface.ts

database/
database.module.ts
database.service.ts

auth/
auth.module.ts
auth.controller.ts
auth.service.ts
dto/
login.dto.ts
register.dto.ts

usuarios/
tesis/
asesores/
reuniones/
documentos/
pagos/
modulos/
mensajes/
ia/

sql/
01_extensions.sql
02_tables.sql
03_functions_auth.sql
04_functions_tesis.sql
05_functions_reuniones.sql
06_functions_pagos.sql
07_functions_documentos.sql
08_functions_modulos.sql
99_seed.sql

## Function naming convention

Use clear function names:

Auth:

- fn_auth_crear_usuario
- fn_auth_login_usuario
- fn_auth_cambiar_contrasena
- fn_auth_refrescar_ultimo_login

Tesis:

- fn_tesis_listar_por_usuario
- fn_tesis_obtener_detalle
- fn_tesis_crear
- fn_tesis_actualizar
- fn_tesis_actualizar_estado
- fn_tesis_eliminar_logico

Reuniones:

- fn_reunion_listar_por_usuario
- fn_reunion_crear
- fn_reunion_cancelar
- fn_reunion_confirmar_pago

Pagos:

- fn_pago_listar_por_usuario
- fn_pago_registrar
- fn_pago_verificar
- fn_pago_rechazar

Documentos:

- fn_documento_listar_por_tesis
- fn_documento_registrar
- fn_documento_actualizar_revision

## SQL call pattern from NestJS

Always use parameterized queries:

this.databaseService.query(
'SELECT \* FROM fn_auth_login_usuario($1, $2)',
[dto.email, dto.contrasena],
);

Never do:

'SELECT \* FROM fn_auth_login_usuario(' + email + ', ' + password + ')'

## API response style

Prefer clean JSON:

{
"ok": true,
"message": "Operación realizada correctamente",
"data": {}
}

For login:

{
"ok": true,
"token": "...",
"usuario": {
"id": "...",
"auth_usuario_id": "...",
"email": "...",
"rol": "...",
"verificado": true
}
}

## Error handling

Use NestJS exceptions:

- BadRequestException
- UnauthorizedException
- ForbiddenException
- NotFoundException
- InternalServerErrorException

Do not leak raw SQL errors to the frontend.

## Verification

Before finishing a change, check:

- npm run build
- npm run lint if available
- DTO validation exists
- SQL calls are parameterized
- no Supabase imports were added
- no password hash is returned
- protected routes use guards
