---
name: security
description: Security rules for authentication, data handling, secrets, and API boundaries
globs: []
---

# Security Rules

## Secrets and Credentials
- Never hardcode secrets, tokens, or API keys — use environment
  variables or a secret manager
- Never log sensitive data (passwords, tokens, API keys, user PII)
- Never commit `.env`, `*.pem`, `*.key`, or other credential files
  (the project's `protected-paths.conf` should list these)

## Database
- Use parameterized queries via the project's ORM or query builder —
  never construct raw SQL strings from user input
- When raw SQL is unavoidable, use the driver's bind-parameter API

## Authentication and Authorization
- Use a modern password KDF (bcrypt, argon2id, or scrypt) — never plain
  hashes, never home-rolled crypto
- Symmetric encryption for stored secrets (Fernet / AES-GCM with
  rotating keys) when the app persists third-party credentials
- Rate-limit authentication endpoints (login, register, password reset,
  MFA challenge)
- If cookies are used: set `httponly`, `secure`, and an appropriate
  `samesite` flag (usually `lax`)
- Authorize every request, not just authenticate it — check the user's
  permission on the specific resource

## Input Validation
- Validate all user input at API boundaries using the project's schema
  library (Pydantic, Zod, class-validator, struct-tag validators, etc.)
- Reject invalid data at the edge — never pass unsanitized input to
  downstream services or queries
- Sanitize user-provided content in any streaming or server-rendered
  output to prevent XSS / injection

## CORS
- Only allow configured origins in production — `*` is a bug
- Declare the exact allowed methods and headers; don't wildcard

## Dependencies
- Pin dependency versions in the project's lock file
- Review new dependencies for known vulnerabilities before adding
- Keep dependencies patched; prefer `Dependabot` / `Renovate` or
  equivalent

## Project-specific crypto choices

When this rule file is tuned for a specific project, document the
concrete libraries and patterns here — e.g., which password library,
which symmetric cipher, which JWT library, which secret manager — so
reviewers can flag deviations.
