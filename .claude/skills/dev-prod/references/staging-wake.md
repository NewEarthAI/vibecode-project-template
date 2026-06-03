# Waking an auto-paused Supabase staging project

Free/lightweight-tier Supabase projects auto-pause after ~1 week idle. A query against a paused
project returns `Connection terminated due to connection timeout`; the project status reads
`INACTIVE`.

## REQUIRED before running any command here

- Set the token from the shell environment — **never paste a token value into chat**:
  `export SUPABASE_ACCESS_TOKEN=$(cat ~/.supabase_pat)` (or use `supabase login`, browser-based).
  If a token value EVER appears in chat, rotation is **not optional** — rotate it immediately at
  https://supabase.com/dashboard/account/tokens before continuing.
- Substitute the real ref: replace `{{staging_ref}}` with the entity's staging project ref
  (see `entity-routing.md`) before running — the commands below are templates.

## Check status

```bash
curl -s -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  "https://api.supabase.com/v1/projects/{{staging_ref}}" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status'))"
```

`ACTIVE_HEALTHY` → ready. `INACTIVE` → wake it.

## Wake

```bash
curl -s -X POST -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
  "https://api.supabase.com/v1/projects/{{staging_ref}}/restore" -d '{}'
```

Then poll `GET /v1/projects/{{staging_ref}}` every 5s until `ACTIVE_HEALTHY`. Observed wake
sequence: `INACTIVE → COMING_UP → RESTORING → ACTIVE_HEALTHY`, ~110 seconds total.

## Operator-experience note

The ~2-minute wake is acceptable for occasional verification but painful for daily use. If the
staging cadence becomes more than weekly, add a scheduled keep-alive touch rather than absorbing
the wake each time.
