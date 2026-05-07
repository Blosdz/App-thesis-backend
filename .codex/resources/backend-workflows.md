# Backend Workflows

## Create new endpoint

1. Identify module.
2. Create DTO.
3. Add controller method.
4. Add service method.
5. Service calls PostgreSQL function.
6. Add guard if private.
7. Return clean JSON.

## Create new SQL-backed feature

1. Create/modify SQL function under sql/.
2. Add NestJS service call.
3. Add endpoint.
4. Add DTO.
5. Add JWT/role guard.
6. Test with curl or Postman.

## Auth login flow

React sends:

- email
- contrasena

NestJS calls:
SELECT \* FROM fn_auth_login_usuario($1, $2)

PostgreSQL:

- validates crypt()
- returns safe user row

NestJS:

- creates JWT
- returns token + user data
