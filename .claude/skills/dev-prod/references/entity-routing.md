# Entity Routing Registry

> **Project config — fill in per project.** A fresh template ships with STUB rows only. As
> each entity's dev/prod separation is set up and proven, flip its `STATUS:` to `wired` and
> fill the real refs/hosts. Real identifiers (project refs, VPS IPs) are NOT secrets but are
> reconnaissance material — keep this file out of public repos and **never push it upstream
> with real values; the template version must stay all-stub with `{{placeholders}}`.**
>
> **The gate reads the `STATUS:` token, not any prose heading.** Anything other than exactly
> `wired` = treat as stub = hard stop. A `wired` entity MUST also have a non-empty staging ref.

## {{entity_1}}
`STATUS: stub` (not yet wired)

| Surface | Production | Staging / Dev | Access |
|---|---|---|---|
| Supabase | `{{prod_ref}}` | `{{staging_ref}}` | prod via `supabase-{{project}}` MCP; staging via Supabase Management API (token in `SUPABASE_ACCESS_TOKEN`) |
| n8n (if used) | container/instance `{{n8n_prod}}`, port `{{prod_port}}` | container/instance `{{n8n_dev}}`, port `{{dev_port}}` | dev via SSH tunnel `ssh -L {{dev_port}}:127.0.0.1:{{dev_port}} {{vps_user}}@{{vps_host}}` |

Notes (fill in when wiring):
- Confirm staging holds **zero** production credentials.
- **BLOCKING precondition before storing ANY real credential in dev n8n**: rotate the dev
  encryption key + admin password if they were ever exposed; record the rotation date here.
  Do not store a real credential first and rotate "later".

## {{entity_2}}
`STATUS: stub` (not yet wired)

(Some entities use Supabase **native branching** + per-PR preview deploys instead of a
separate staging project — the routing differs. Record the chosen model here when wiring.)

## Stub discipline

If an entity's `STATUS:` is `stub`, the skill **stops** — it must not invent a staging target.
A guessed target risks writing to production. Tell the operator the entity is not yet wired.
