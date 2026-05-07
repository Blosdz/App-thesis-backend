# MCP Plan for Thesis Backend

## Purpose

Use MCP to provide Codex with external and local context.

## Desired MCP servers

### 1. PostgreSQL Documentation MCP

Purpose:

- Consult official PostgreSQL docs.
- Check pgcrypto, crypt(), gen_salt(), PLpgSQL, triggers, constraints.

Usage:

- Before modifying SQL functions.
- Before designing authentication functions.
- Before using advanced PostgreSQL features.

### 2. NestJS Documentation MCP

Purpose:

- Consult NestJS docs.
- Check modules, guards, providers, decorators, pipes, exception filters.

Usage:

- Before creating modules.
- Before creating JWT auth.
- Before creating global validation.

### 3. Local Project Docs MCP

Purpose:

- Expose local docs and SQL files to Codex.
- Include:
  - sql/
  - AGENTS.md
  - .codex/resources/
  - database schema notes

Usage:

- Before generating any backend endpoint.
- Before changing function names.
- Before creating migrations/functions.

### 4. GitHub MCP optional

Purpose:

- Read issues/PRs.
- Link tasks to repo context.
- Review branches.

Use only when repo is hosted and connected.
