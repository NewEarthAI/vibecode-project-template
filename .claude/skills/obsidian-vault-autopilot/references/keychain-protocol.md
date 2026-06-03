# Keychain Protocol — Obsidian Vault Autopilot

Per council A8 + Q6 resolution: **option (a) only**. The service-role JWT is RLS-bypass authority — it must NEVER appear in a Claude transcript. The skill surfaces the exact `security add-generic-password` command; the operator runs it in their own Terminal; Claude never sees the raw value.

## The 4 NewEarth-Internal Keychain Entries

Source-of-truth: `agency/memory/reference_supabase-newearthai-credentials.md`.

| Service name | Account | What it is | Required by skill? |
|---|---|---|---|
| `claude-mcp-supabase-newearthai` | `api-key` | Personal Access Token (PAT, `sbp_*`) for MCP servers | Optional — forward-protection |
| `agency-supabase-newearthai-service-role-jwt` | `service_role` | Service-role JWT (RLS-bypass, used by vault-sync) | **REQUIRED** |
| `agency-supabase-newearthai-secret-key` | `secret` | Newer-format secret key (`sb_secret_*`) | Optional |
| `agency-supabase-newearthai-publishable-key` | `publishable` | Newer-format anon equivalent (`sb_publishable_*`) | Optional |

For dev/prod separation work, parallel `agency-supabase-newearthai-staging-*` slots exist (same accounts, staging Supabase ref).

## Adding an Entry (operator runs in Terminal)

```bash
security add-generic-password -U \
  -s "<service-name-from-table>" \
  -a "<account-from-table>" \
  -w
```

The `-w` flag without a value prompts hidden input. Paste the secret, press Return.

The `-U` flag updates the entry if it already exists (idempotent — safe to re-run on rotation).

## Reading an Entry (the skill does this, no operator action needed)

```bash
security find-generic-password \
  -s "<service-name>" \
  -a "<account>" \
  -w
```

Returns the secret to stdout. The skill captures it into an env var (e.g. `SERVICE_KEY=$(security ...)`) and pipes to consumers without echoing.

**Never** print the captured value to stdout. **Never** write it to disk. **Never** include in a tool-call argument string.

## Detection — Is the Entry Present?

```bash
security find-generic-password -s "<service-name>" >/dev/null 2>&1 && echo PRESENT || echo MISSING
```

The `>/dev/null 2>&1` discards both the secret value AND any error message — leaving only the exit code. Safe to log the result.

## Rotation Discipline

Per council A12 fact-correction: service-role JWTs have long-lived `exp` claims (typically 10+ years) but Supabase rotation is operator-driven via Dashboard → Project Settings → API Keys → "Roll keys" — NOT calendar-expiring.

After rotation, every Mac with cached keychain entries must independently re-run:

```bash
security add-generic-password -U -s "agency-supabase-newearthai-service-role-jwt" -a "service_role" -w
```

The `-U` flag updates in place. No additional commands needed.

The autopilot will continue using the OLD JWT until the next launchd-fired run (up to 10 min) — first run after rotation surfaces 401 in `vault-sync.log`. If F4 watchdog ever ships (council A5 deferred decision), it would alert here; for v1.0 the operator notices via Verify check #5 (DB row staleness, A11).

## What NOT To Do

| Wrong | Why | Right |
|---|---|---|
| Type JWT into a Claude chat message | Service-role JWT in transcript is permanent exposure | Operator types into their own Terminal via `security add-generic-password -w` |
| Echo `$SERVICE_KEY` to confirm read worked | Adds secret to terminal history + scrollback | Test by querying a real endpoint (the skill does this in step 5 post-verify) |
| Hardcode JWT in `.env` or config file | Not gitignored vs gitignored is a one-bit accident | Keychain is the only sanctioned storage |
| Skip the `-U` flag on add | First-add succeeds; second-add fails with "item already exists" | Always include `-U` (update if exists) |

## See Also

- `agency/memory/reference_supabase-newearthai-credentials.md` — full keychain map (canonical)
- `.claude/rules/symlink-discipline.md` — substrate doctrine (secrets stay machine-local)
- `bin/activate-vault-autopilot.sh` — uses `security find-generic-password` for the activation smoke
- `bin/vault-sync.sh` line 150 — uses the JWT for upserts
