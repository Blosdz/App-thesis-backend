# Skill: PostgreSQL Functions Workflow

## Purpose

Use this skill when creating, reviewing, or modifying PostgreSQL SQL/PLpgSQL functions, triggers, constraints, or transactional workflows.

## Project rules

PostgreSQL owns the core business logic.

Functions should:

- use Spanish naming when consistent with the DB
- use clear prefixes: fn*auth*, fn*tesis*, fn*reunion*, fn*pago*
- be transactional by default when multiple writes happen
- validate required inputs
- return clean TABLE results when consumed by NestJS
- avoid leaking sensitive data
- use timestamptz for created/updated dates
- use uuid for IDs
- use jsonb for flexible metadata

## Security

Always avoid dynamic SQL unless absolutely necessary.

If dynamic SQL is needed:

- explain why
- use format() safely
- use quote_ident / quote_literal where needed

For passwords:

- use pgcrypto
- use crypt(p_contrasena, gen_salt('bf', 12))
- validate using contrasena_hash = crypt(p_contrasena, contrasena_hash)
- never use md5()

## Function template

CREATE OR REPLACE FUNCTION fn_module_action(
p_usuario_id uuid,
p_param text
)
RETURNS TABLE (
id uuid,
message text
)
LANGUAGE plpgsql
AS $$
BEGIN
-- logic here

    RETURN QUERY
    SELECT
        some_id,
        'OK'::text;

END;

$$
;

## Auth function rules

fn_auth_login_usuario must:
- receive p_email and p_contrasena
- normalize email with lower(trim())
- validate active user
- compare password with crypt()
- update ultimo_login_en if login succeeds
- return only safe fields:
  - auth_usuario_id
  - usuario_id
  - email
  - rol
  - verificado
- never return contrasena_hash

## Output format

When generating SQL:
1. Include file path under sql/.
2. Include CREATE EXTENSION when needed.
3. Include CREATE OR REPLACE FUNCTION.
4. Include example SELECT usage.
5. Include expected return shape.
6. Mention related NestJS endpoint.
$$
