# Skill: NestJS PostgreSQL Function API

## Purpose

Use this skill when creating or modifying NestJS modules, controllers, services, DTOs, or routes that expose PostgreSQL functions as secure HTTP APIs.

## Architecture

React
→ NestJS Controller
→ NestJS Service
→ DatabaseService
→ PostgreSQL function
→ JSON response

NestJS must not duplicate complex SQL business logic.

## Required pattern

For every endpoint:

1. Create DTOs for request validation.
2. Create controller route.
3. In service, call a PostgreSQL function through DatabaseService.
4. Use parameterized SQL: $1, $2, $3.
5. Return clean JSON.
6. Throw NestJS exceptions for errors.
7. Protect private routes with JWT guard.
8. Use role guard when needed.

## DatabaseService pattern

Use:

this.databaseService.query(
'SELECT \* FROM function_name($1, $2)',
[param1, param2],
);

Never concatenate user input into SQL.

## Controller pattern

Example:

@Post('login')
login(@Body() dto: LoginDto) {
return this.authService.login(dto);
}

## Service pattern

Example:

async login(dto: LoginDto) {
const result = await this.databaseService.query(
'SELECT \* FROM fn_auth_login_usuario($1, $2)',
[dto.email, dto.contrasena],
);

if (result.rows.length === 0) {
throw new UnauthorizedException('Credenciales incorrectas');
}

return {
ok: true,
data: result.rows[0],
};
}

## Output format

When generating code, always provide:

1. File path.
2. Full file content.
3. Brief explanation.
4. Any SQL function dependency.
5. Any required module import.

## Do not

- Do not use Supabase.
- Do not connect React directly to PostgreSQL.
- Do not expose DB credentials.
- Do not return contrasena_hash.
- Do not hash passwords in NestJS unless explicitly requested.
- Do not use md5() for passwords.
