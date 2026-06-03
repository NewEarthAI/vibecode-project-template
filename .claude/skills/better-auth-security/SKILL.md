---
name: better-auth-security
description: |
  Better Auth library-specific security hardening. Concrete rate limit numbers, secret entropy,
  CSRF multi-layer protection, OAuth token encryption, storage backend tradeoffs.
  Companion to master-security-review for projects using Better Auth.
  For general security review, use master-security-review instead.
version: 1.1
source: better-auth/skills (enhanced for the project)
classification: capability-uplift
triggers:
  - "Better Auth security"
  - "Better Auth config"
  - "rate limiting configuration"
do-not-trigger:
  - "security review" (general) → use master-security-review
  - "threat model" → use security-threat-model
paths:
  - "**/auth/**"
  - "**/better-auth/**"
---

# Better Auth Security Best Practices

> Library-specific companion to `master-security-review`. Provides concrete numbers, config patterns, and library behaviors the general review cannot cover.

## Secret Management
- Looks for secrets: options.secret → BETTER_AUTH_SECRET env → AUTH_SECRET env
- Rejects placeholder secrets in production
- Warns if shorter than 32 chars or entropy below 120 bits
- Generate: `openssl rand -base64 32`

## Rate Limiting
- Enabled in production by default, all endpoints
- Default: 100 requests per 10-second window
- Storage: "memory" (avoid serverless), "database" (persistent), "secondary-storage" (Redis)
- Sensitive endpoints: 3 req/10s for /sign-in, /sign-up, /change-password, /change-email

## CSRF Protection
Multi-layer: origin header validation, Fetch Metadata checks, first-login protection.

## Session Security
- Cookie settings (secure, httpOnly, sameSite)
- Session expiration and refresh token rotation
- Token encryption for OAuth providers

## Audit Logging
- Track authentication events
- IP address recording for security analysis
