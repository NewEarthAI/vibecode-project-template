---
name: no-backfill-without-permission
enabled: true
event: PreToolUse
tool_matcher: mcp__supabase-(a-logistics-app|the appai|your-org)__(apply_migration|execute_sql|deploy_edge_function)
action: warn
---

**[BLOCK — HARD RULE] Backfill pattern detected — explicit Justin approval required**

Triggered when the SQL / migration body / edge function body contains ANY of the following patterns suggesting LLM-billed work against historical data:

- `cron.schedule` with name containing `backfill` / `catch.?up` / `rehydrate` / `reprocess` / `reclassify` / `re.?extract` / `re.?ocr`
- `cron.alter_job(... active := true ...)` on a job whose existing name matches the above
- `net.http_post` whose URL ends in any edge function whose name matches the above
- `INSERT INTO` ... `(SELECT ... FROM <historical_table> WHERE created_at < NOW() - INTERVAL ...)` followed by an LLM-API call
- Loop / cursor / `unnest` over historical records that calls `pg_net.http_post` to api.openai.com / api.anthropic.com / api.mistral.ai / etc.
- `apply_migration` that creates or alters a function whose body calls OpenAI / Claude / Mistral on records older than today

## Why this fires

Justin's standing rule (2026-05-15): **"We never spend money on backfilling without my explicit permission."**

Origin: pod-ocr-backfill cron firing every 2 minutes for ~3-4 weeks on 4,500 stale PODs, burning ~$60-80/day silently before detection. R1,500+ ZAR lost before anyone noticed.

## Pre-execute checklist (ALL required before approving)

```
BACKFILL APPROVAL GATE:
[ ] 1. Estimate cost: count of historical records × per-call cost × expected retry multiplier
[ ] 2. Surface the dollar figure to Justin explicitly in the response BEFORE this SQL runs
[ ] 3. Wait for unambiguous OK that names the dollar figure (e.g., "yes, $50 is fine")
[ ] 4. The OK must be from THIS session — previously-approved backfills do NOT carry forward
[ ] 5. Job must have a daily budget cap OR a max-records-processed cap before activation
[ ] 6. Job must write to system_alerts on first activation (so it's not "deployed and forgotten")
[ ] 7. Job must include a kill switch (active flag, env var, or feature gate)
```

If ANY box unchecked → STOP and ask Justin. Do not proceed.

## Allowed without this gate

- Live-pipeline processing of TODAY's incoming records (the classifier handling new WhatsApp photos as they arrive)
- One-off LLM calls on a single record for diagnosis (cost < $0.10)
- `dry_run: true` invocations
- Reading from cached LLM responses

---
**Reference**: 📄 `~/.claude/projects/<this>/memory/feedback_no_backfilling_without_permission.md`
