# Cost-Spike Diagnostic — Origin & Full Context

> **For anyone pulling this skill into another repo**: this document captures the two real incidents that birthed the skill, the doctrine that ships with it, and the wider operational picture. Read this before applying the skill in a new project — it explains WHY each phase exists, not just WHAT it does.

---

## The 48-Hour Investigation That Authored This Skill

### Day 0 — 2026-05-13 (Wednesday) — the bill that woke us up

the operator sees an OpenAI line item: ≈$21 in a single day on an API key labelled "a logistics app - AI Workbook". The previous baseline was $5/day max. Three days of accumulating spend ($17 → $18 → $21) suggested something was wrong but had been quietly running for a while.

### Day 1 — 2026-05-14 (Thursday) — three wrong hypothesis branches before the right one

Initial inventory grep'd every OpenAI consumer across three repos (a logistics app, a SaaS app, the agency Agency) and surfaced ~11 candidates. I burned ~45 minutes per hypothesis branch chasing the wrong leads:

1. **First wrong branch — Podio webhook**: pattern-matched on a HomePros partner integration that went live 2026-05-12 (matching the spike start date). Built a whole theory about cross-project key leakage from a SaaS app / your instance n8n workflow into the a logistics app OpenAI project namespace.
2. **Second wrong branch — a SaaS app edge functions**: hunted four a SaaS app extraction functions (`extract-deal-flyer`, `extract-mortgage-statement`, `extract-portfolio-tape`, `handle-deal-intake`) that all hard-code gpt-4o. Another parallel Claude session in the SaaS app repo cleared them by checking the audit log table.
3. **Third wrong branch — n8n retry config**: theorised the Visual AI Media Classifier had `retries: 6` configured in its OpenAI HTTP node, multiplying calls 6× per photo.

The actual root cause surfaced only after the operator pasted a **screenshot of the n8n execution error pane** showing:

```
duplicate key value violates unique constraint "data_conflicts_pkey"
```

That single concrete observation collapsed three days of attribution drift in 30 seconds.

**Root cause for Day 1**: a column default `lpad((nextval('conflict_seq'))::text, 4, '0')` on `data_conflicts.conflict_id`. PostgreSQL's `lpad` truncates from the right when input exceeds target length. Once the sequence crossed 9,999 (which happened 2026-04-15), every 10 consecutive values collapsed to the same 4-character suffix, producing primary-key collisions. The calling function `classify_media_final` had no `EXCEPTION` wrapper on its audit-log INSERT, so each collision rolled back the entire function. WhatsApp photos stayed unclassified. The schedule trigger re-picked them up every 10 minutes. gpt-4o was re-called.

**Day 1 fix shipped**: column default uses raw `nextval()::text` (no truncation), function's secondary INSERT wrapped in `BEGIN ... EXCEPTION WHEN OTHERS THEN NULL; END`.

**Day 1 victory claim**: "$15/day saved, retry loop eliminated."

### Day 2 — 2026-05-15 (Friday) — the attribution illusion is broken

the operator reports: *"Here I am a day later and I am still getting charged tons for gpt 4o!!!"*

The hourly OpenAI usage CSV broke the Day 1 victory claim in one glance:
- gpt-4o call rate on the suspect key was **flat at 130-150 calls/hour for 30 consecutive hours**
- That includes the 12 hours AFTER Day 1's fix landed at ~12:25 UTC
- The lpad fix moved approximately **zero dollars** at the billing-API level
- Sometime around 2026-05-15 06:00 UTC the rate collapsed to ~5 calls/hour
- An OpenAI hard-spend-cap had been hit; the cron was still firing, the API was rejecting

Re-running Phase 1 with a **cron-multiplier sub-step** found the real burner immediately: 📓 `pod-ocr-backfill` cron firing every 2 minutes, calling an edge function that pulls 5 proof-of-delivery photos at a time and runs them through gpt-4o vision with `detail: "high"`.

The math:
- 30 cron firings/hour × 5 photos/call = 150 OCR attempts/hour
- = 3,600 attempts per day worst case
- Per-call cost ≈ $0.0225 (input image + JSON output)
- = ~$80 per day worst case
- Actual rate held at 130-150 calls/hour ≈ $60-80/day
- Running for ~3-4 weeks before detection
- Total accumulated waste: **R1,500+ ZAR**

**Why the backlog was stale**: 4,593 photos in the "eligible for backfill" pool, only 274 with valid Wassenger media+device IDs in their raw payload. Wassenger storage URLs are short-lived; the older photos had long since expired. Each cron tick downloaded a record → OpenAI vision → JSON parse → tried to persist → failed because the upstream data was incomplete or the URL had timed out. The function's code explicitly said `// Transient — will retry` for OCR-parse and persist failures, with NO retry cap. The same records got picked up cycle after cycle.

**Day 2 fix shipped**:
- The pod-ocr-backfill cron job paused (`active = false`)
- A new project rule: **no backfilling against billed APIs without explicit user OK that names a dollar figure**
- A new hookify gate that fires on any future SQL / migration / edge-function deploy matching backfill-shaped patterns
- The skill itself upgraded to v2.0.0 with the cron-multiplier sub-step + hourly billing-rate verification gate

### What the Skill Now Encodes

| Phase | What v1 had | What v2 added | Why |
|-------|-------------|---------------|-----|
| 1a | Inventory callers | (unchanged) | Find every place the API is called from code |
| 1b | (MISSING in v1) | Enumerate cron / schedulers / webhooks that fire each caller, multiply per-call cost × max daily firings | A $0.02 function fired 720× per day is a $14/day burner — invisible to caller-only inventory |
| 1c | (MISSING in v1) | Classify each caller LIVE vs BACKFILL; apply the no-backfilling rule to BACKFILL class | Backfills are an opt-in cost, not a default |
| 2-6 | (unchanged) | (unchanged) | Attribution + fingerprint + cross-reference + concrete-evidence + root cause |
| 7 | Verify by querying database for new records | Verify at TWO levels — DB state AND hour-by-hour billing-API rate comparison | Day 1's mistake: DB persistence improved 6× while API call rate didn't budge — fix moved zero dollars but looked successful in DB |

---

## Companion Doctrine That Ships With This Skill

These three artefacts compose with the skill. Pulling the skill into another repo without them weakens the enforcement:

### 1. 📄 No-Backfilling Memory (`feedback_no_backfilling_without_permission.md`)

A user-instruction-class memory: **"We never spend money on backfilling without my explicit permission."** Lists banned phrases ("let me catch up the backlog", "reprocess the historical records", etc.) and the 7-item approval checklist for any backfill-shaped job. Lives in the project's memory folder, auto-loads every session.

### 2. 📄 No-Backfill Hookify Gate (`hookify.no-backfill-without-permission.local.md`)

Active enforcement at tool-call time. Fires PreToolUse on `apply_migration`, `execute_sql`, `deploy_edge_function` across all Supabase MCP servers. Detects backfill-shaped patterns:
- `cron.schedule` names containing `backfill` / `catch.?up` / `rehydrate` / `reprocess` / `reclassify` / `re.?extract` / `re.?ocr`
- `cron.alter_job(... active := true ...)` on a previously-paused backfill job
- `net.http_post` loops targeting LLM API URLs over historical records
- Edge function bodies calling OpenAI/Claude on records older than today

If matched, surfaces a 7-item checklist BEFORE the SQL runs. Approval requires the operator to name a dollar figure in the current session.

### 3. 📄 SQL Defensive Defaults Rule (`sql-defensive-defaults.md`)

The Day 1 lessons — never combine string-truncation functions (`lpad`/`rpad`/`substring`/`left`/`right`) with counter-derived defaults, always wrap non-essential plpgsql writes in `BEGIN ... EXCEPTION`, idempotency for expensive-API calls must check primary persistence target not in-memory flags. Composes with this skill's Phase 6 root-cause table.

---

## Intended Use In the agency Repo

The skill is being pushed to the the agency template repo for use across all client projects (a logistics app, a SaaS app, future clients). When pulled in:

1. **Cross-client cost attribution**: every the agency client project shares the same OpenAI account but should bill into separate projects. This skill's Phase 2 is the authoritative attribution methodology when keys leak across projects.

2. **LLM usage monitoring** (planned in agency repo): the operator has identified two candidate repos to build the per-workflow / per-edge-function dashboard against:
   - 🌐 `https://github.com/NewEarthAI/llm-performance-tracker.git` — performance + cost tracking
   - 🌐 `https://github.com/NewEarthAI/litellm.git` — LiteLLM gateway (proxies model calls, tags each request with metadata for attribution)
   
   The LiteLLM approach is structurally superior for the per-workflow attribution problem: it sits between every code path and the model provider, so each call is automatically tagged with `workflow_name` / `edge_function_name` regardless of which API key is used. This makes the Phase 2 attribution step nearly free.

3. **Doctrine for fresh keys per use case** (queued in deferred-todos): the operator's standing rule for the agency — whenever Claude touches anything API-key-related in a vibe-code session, a brand-new key fully customised for the exact use case must be created so cost attribution stays trivially clean. This skill's Phase 2 will compose with that doctrine once it lands.

---

## How To Apply In A New Project

When pulling this skill into a fresh client project:

1. **Verify companions are pulled together**: the no-backfilling memory + hookify gate + sql-defensive-defaults rule should travel as a bundle. The skill loses 50% of its safety value without them.
2. **Update Phase 1a grep patterns** to match the new project's repo structure (paths, MCP server names).
3. **Update Phase 2 attribution paths** with the new project's Supabase project ref + n8n instance URL.
4. **Re-run Phase 1 inventory on day 1** of adoption — every project has its own legacy edge functions and crons that need cataloguing before the skill can be applied to a real incident.
5. **Confirm the OpenAI project for the client is separate** — the whole skill assumes cost attribution by project ID and key ID. Cross-client key sharing breaks Phase 2 entirely.

---

## Deliberately NOT In The Skill (And Why)

- **Auto-rotation of API keys**: tempting but breaks the audit trail mid-investigation. Phase 5 explicitly says "diagnose first, rotate as part of fix" — do not let any future agent auto-rotate to "be safe".
- **Auto-pause of suspect crons**: the no-backfilling hookify gate handles the prevention side. Pausing an existing cron mid-audit is a destructive action that requires user approval.
- **Auto-creation of new API keys**: queued as a separate doctrine. Combining it into this skill would couple cost-debugging with security/operations concerns that need their own deliberation.
- **Spend forecasting / budgeting**: this skill diagnoses leaks; the planned agency-level LLM dashboard handles forecasting and budgeting.

---

## Failure-Mode Catalogue (From The Two Incidents)

For future audit reviewers — these are the specific traps the v2 skill prevents:

| Trap | Failure precedent | v2 mechanism that prevents it |
|------|-------------------|-------------------------------|
| Attribution by OpenAI project name | Day 1: key labelled "a logistics app - AI Workbook" was the WHOLE a logistics app OpenAI namespace, not a specific workload | Phase 2 mandates key-value verification at the plug-in point, not the label |
| Counting only callers, not multipliers | Day 1+2: pod-ocr-backfill is one caller × 720 cron firings/day = the real disaster | Phase 1b is mandatory; the caller × firer × multiplier table must be produced |
| Declaring victory on DB persistence | Day 1: lpad fix moved DB rate 6× while API rate moved 0% | Phase 7 mandates two-level verification (DB + billing-API hourly rate) |
| Backfill jobs deployed and forgotten | pod-ocr-backfill was deployed weeks ago; no one was watching | No-backfilling rule + hookify gate now block silent deploy |
| Theorising past 2 hypotheses without concrete evidence | Day 1: 3 wrong branches × ~45 min each = ~2.5h wasted | Phase 5 escalates to "ask for one concrete observation" automatically |
| Trusting "transient — will retry" comments in code | pod-ocr-backfill had explicit `// Transient — will retry` for OCR parse and persist failures, with no cap | Phase 6 root-cause table flags "5-second timeout on net.http_post" and "Silent NULL in persistence" |

---

## Companion Files Inventory

Located alongside this skill:
- 📄 `SKILL.md` — the skill body itself, v2.0.0
- 📄 `evals/evals.json` — 5 evaluation cases including 1 should_trigger=false guard
- 📄 `CONTEXT.md` — this file (rationale + history + intended use)

Located in the source project's `.claude/` tree (pull these together when adopting):
- 📄 `.claude/rules/sql-defensive-defaults.md` — composes with Phase 6
- 📄 `.claude/hookify.no-backfill-without-permission.local.md` — active enforcement gate
- 📄 `.claude/rules/operational-guardrails.md` — backfill activation in HARD STOP list
- 📄 (memory dir) `feedback_no_backfilling_without_permission.md` — user-instruction-class rule
- 📄 (memory dir) `reference_openai_api_key_attribution.md` — Phase 2 attribution methodology

---

## Version & Audit Trail

- **v1.0.0** (2026-05-14): initial 7-phase methodology shipped during Day 1 lpad incident
- **v2.0.0** (2026-05-15): self-audit found 3 critical gaps; Phase 1 split into 1a/1b/1c, Phase 7 upgraded to two-level verification, anti-patterns extended, evals added
- **Audit grade**: v1 was C (62.5/100), v2 is estimated B+ pending field validation

The next anticipated upgrade trigger: when the agency-level LLM dashboard ships (LiteLLM-based), Phase 2 attribution becomes near-automatic and this skill's Phase 2 should be simplified to "query the dashboard's attribution table". That change is queued.
