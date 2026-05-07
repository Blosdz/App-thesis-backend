# Skill: Auth with PostgreSQL pgcrypto crypt()

## Purpose

Use this skill when implementing authentication without Supabase Auth.

The backend is NestJS.
Password hashing happens inside PostgreSQL using pgcrypto.

## Required extension

CREATE EXTENSION IF NOT EXISTS pgcrypto;

## Auth table

auth_usuarios:

- id uuid primary key default gen_random_uuid()
- email varchar(255) unique not null
- contrasena_hash text not null default crypt('app_theseis', gen_salt('bf', 12))
- activo boolean default true
- email_verificado boolean default false
- ultimo_login_en timestamptz null
- creado_en timestamptz default now()
- actualizado_en timestamptz default now()

## Password rules

Never store plain text passwords.
Never return contrasena_hash to the frontend.
Never use md5().

Create hash:

crypt(p_contrasena, gen_salt('bf', 12))

Validate:

au.contrasena_hash = crypt(p_contrasena, au.contrasena_hash)

Default initial password may be:

app_theseis

But it must be stored hashed.

## Required SQL functions

Create or maintain:

- fn_auth_crear_usuario
- fn_auth_login_usuario
- fn_auth_cambiar_contrasena
- fn_auth_desactivar_usuario

## fn_auth_crear_usuario should

- receive p_email, p_rol, p_contrasena default 'app_theseis'
- insert into auth_usuarios
- insert into usuarios
- return safe fields only
- not return contrasena_hash

## fn_auth_login_usuario should

- receive p_email, p_contrasena
- validate password using crypt
- update ultimo_login_en
- return safe fields only

## NestJS auth rules

NestJS:

- receives email and contrasena
- calls fn_auth_login_usuario($1, $2)
- if no rows, throws UnauthorizedException
- if row exists, generates JWT
- returns token and safe usuario data

JWT payload:

- usuario_id
- auth_usuario_id
- rol

Do not hash password in NestJS for this project.
