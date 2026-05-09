-- Prerrequisitos del esquema principal del backend.
-- Necesario para:
-- 1. Consultar tablas bajo el esquema "AT"
-- 2. Usar crypt(...) y gen_salt(...) en auth/register y auth/login

CREATE SCHEMA IF NOT EXISTS "AT";
CREATE EXTENSION IF NOT EXISTS pgcrypto;
