# Skill: API Review and Security

## Purpose

Use this skill before finalizing backend API changes.

Review for security, consistency, and architecture compliance.

## Checklist

### Supabase

- No Supabase imports.
- No Supabase client.
- No Supabase Auth.
- No Supabase RPC.

### React/PostgreSQL separation

- React does not connect directly to PostgreSQL.
- React only calls NestJS endpoints.

### SQL safety

- All SQL calls use parameters: $1, $2, $3.
- No string concatenation with user input.
- No raw SQL errors exposed to frontend.

### Auth

- Password is never returned.
- contrasena_hash is never returned.
- JWT payload contains only safe fields.
- Private routes use JwtAuthGuard.
- Role routes use RolesGuard.

### DTOs

- Every POST/PUT/PATCH endpoint has DTO validation.
- class-validator decorators are present.
- ValidationPipe is enabled in main.ts.

### Database functions

- Business logic stays in PostgreSQL functions when appropriate.
- Function names follow project convention.
- Functions return safe data shapes for APIs.

### Error handling

- Uses NestJS exceptions.
- No console-only error handling in production paths.
- User-facing messages are clean.

### Build

- npm run build should pass.
- npm run lint should pass if configured.

## Output

When reviewing, return:

- Critical issues
- Recommended fixes
- Files to change
- Exact code patches if requested
