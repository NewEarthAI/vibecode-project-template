---
name: cost-spike-diagnostic
description: |
  Investigate a sudden billing spike on a per-call external API (OpenAI, Claude, Mistral, Twilio, payment gateways, geocoding, vision OCR). Seven-phase methodology — inventory → attribute → fingerprint → cross-reference → escalate-to-concrete-evidence → root-cause → fix-and-verify. Composes with /supabase-postgres-best-practices, /supabase-query-optimization, .claude/rules/sql-defensive-defaults.md, and the no-backfilling-without-permission memory rule.
classification: capability-uplift
version: "2.0.0"
created: 2026-05-14
updated: 2026-05-15
validated_on: 2026-05-15
metadata:
  origin: 2026-05-14 Nirvana fleet automation $435 silent loss investigation
  cost_class: cost-debugging
  trigger_phrases: ["cost spike", "openai bill", "api billing", "why is X so expensive", "where did all the tokens go", "$X yesterday", "billing audit", "still being charged", "tons of gpt-4o"]
  v2_changes: |
    - Phase 1 split into 1a (inventory callers) + 1b (enumerate cron/scheduler multipliers) + 1c (classify LIVE vs BACKFILL)
    - Phase 7 verification must include hour-by-hour rate comparison from billing data, not just DB state
    - Anti-pattern table extended with two attribution failures from 2026-05-15 audit
    - Backfill rule integration: any BACKFILL-class consumer must apply no-backfilling memory
    - 5 evals added including one should_trigger=false case
---

# Cost-Spike Diagnostic

Used when an external per-call API bill spikes and you need to find the cause + apply a permanent fix. The methodology came out of two real incidents (29 days of silent loss, then a follow-up audit that proved the first fix attributed wrong) — each phase is designed to catch a specific failure mode that hid the bug.

## When to Apply

- User reports a billing spike on OpenAI, Claude, Mistral, Twilio, vision OCR, or any per-call-billed API
- Daily/weekly bill is materially higher than the historical baseline
- A new line item appears on a billing dashboard with no obvious owner
- Suspected loop / retry / runaway workflow burning external calls
- Day-after follow-up: previous fix was claimed but bill is still high

## The Seven Phases

### Phase 1a — Inventory all CALLERS
List every place across all client repos that calls the billed API. Don't trust memory; grep the codebase.

```bash
# Edge functions (each Supabase project, all worktrees)
grep -rln "api.openai.com\|new OpenAI\|OpenAI(" <repo>/supabase/functions/

# n8n workflow JSON files in repo
grep -rln "openAiApi\|gpt-4o\|gpt-5\|gpt-4" <repo>/workflows/ <repo>/my-project/workflows/

# Scripts / utilities
grep -rln "OPENAI_API_KEY\|ANTHROPIC_API_KEY" <repo>/scripts/ <repo>/.claude/skills/
```

**Output**: a flat list of every file that calls the API, grouped by repo.

### Phase 1b — Enumerate FIRERS for each caller (cron-multiplier blindspot)

**This is the step most likely to be skipped — and the one most likely to find the leak.** A function that costs $0.02 per invocation looks fine; the same function fired 720 times per day by a 2-minute cron is a $14/day disaster. For each caller from Phase 1a, find every trigger that fires it:

```sql
-- All pg_cron jobs that could fire each caller
SELECT jobname, schedule, command
FROM cron.job
WHERE command ILIKE '%<edge_function_name>%'
   OR command ILIKE '%openai%';

-- n8n schedule triggers (in workflow JSON)
grep -A3 'scheduleTrigger\|cronExpression\|interval' <workflow.json>

-- Database triggers calling the function via pg_net
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE action_statement ILIKE '%<function_name>%';
```

For each (caller, firer) pair, compute the cost multiplier:
```
max_daily_cost = per_call_cost
               × records_per_invocation
               × invocations_per_hour
               × 24
               × retry_multiplier (typically 1.0-6.0)
```

Output: a table of `(caller, firer, schedule, max_daily_cost)`. The leak is almost always the highest-multiplier row.

### Phase 1c — Classify each caller: LIVE vs BACKFILL

For every consumer in Phase 1a, classify:

| Class | Definition | Default stance |
|-------|------------|----------------|
| LIVE | Processes today's incoming records (e.g., classifies a WhatsApp photo as it arrives) | Allowed |
| BACKFILL | Processes historical records (catch-up, rehydrate, reprocess, reclassify, re-extract) | **PROHIBITED without explicit user OK that names a dollar figure** |

If ANY consumer is BACKFILL-class:
1. Stop and surface to user: "this is backfill-class — costs ~$X for the historical pool; standing rule says no backfilling without explicit OK"
2. Apply the rule from 📄 `~/.claude/projects/<project>/memory/feedback_no_backfilling_without_permission.md`
3. Do not deploy / re-enable / activate without an unambiguous "yes, $X is fine" in the current session

### Phase 2 — Attribute calls to keys
The billing CSV has `project_id` + `api_key_id` columns. The OpenAI project name is NOT reliable (keys end up labelled inconsistently). The only authoritative trail:

1. From the billing CSV, identify which `api_key_id` is responsible for the spike
2. Find that key's human-readable name on the API dashboard
3. For EACH place that key could be plugged in — n8n credentials, Supabase Edge Function secrets, `.env` files — verify which one actually holds the key value
4. The single place that holds the value is the workload's home

**Decision rule**: if the key name suggests a project that doesn't match where the key is plugged in, you have cross-project leakage. Investigate the actual plug-in point, not the label.

### Phase 3 — Fingerprint the workload
Compute per-call shape from the billing CSV:

```
avg_input_tokens  = input_tokens  / num_model_requests
avg_output_tokens = output_tokens / num_model_requests
calls_per_hour    = num_model_requests / 24 (or matching duration)
shape_variance    = standard deviation across consecutive hours
```

| Shape | Likely workload class |
|-------|----------------------|
| input ~1,000–2,000, output ~150–300, low variance | Fixed-prompt classifier (image classification, intent detection) |
| input ~3,000–8,000, output ~500–2,000, moderate variance | Vision OCR (document extraction, photo analysis) |
| input ~500–2,000, output ~1,500–8,000, high variance | Report / commentary generation |
| input ~5,000+ cached, output ~200–500, low variance | RAG-with-context classifier |
| input wildly variable, output wildly variable | Free-form chat / agent loop |

Match against your Phase 1 inventory to narrow the candidate set.

### Phase 4 — Cross-reference activity with persistence
For each candidate consumer, query its primary database persistence target for matching activity volume.

```sql
-- For a media classifier
SELECT DATE(updated_at), COUNT(*) FROM whatsapp_media
WHERE final_classification_source = 'CANDIDATE_WORKFLOW_NAME'
  AND updated_at::date = '2026-05-13'
GROUP BY 1;

-- For a report generator
SELECT DATE(created_at), COUNT(*) FROM reports
WHERE generated_by = 'CANDIDATE_WORKFLOW_NAME'
  AND created_at::date = '2026-05-13'
GROUP BY 1;
```

**Decision rule**: if `OpenAI_calls_for_day >> persisted_records_for_day` (e.g. 6× or more), you have a retry loop or post-call write failure. BUT — see Phase 7 verification note — never claim victory on this metric alone.

### Phase 5 — STOP and escalate to concrete evidence (CRITICAL)
After Phase 4, you'll have 1-3 plausible hypotheses. Resist the urge to keep theorising. Ask the user (or another session) for ONE specific dashboard observation:

| Stuck on | Ask for |
|---|---|
| "Which workflow uses this key?" | The human-readable name of the API key from the dashboard |
| "Why is the call rate so high?" | Hourly call distribution (business-hours-shaped = partner-webhook driven; flat = retry loop or cron-driven) |
| "Why is persistence failing?" | An n8n execution screenshot of one failed run, including the error message |
| "Which project's Supabase has this in secrets?" | First 12 characters of `OPENAI_API_KEY` in each candidate Supabase Edge Functions Secrets page |
| "Did yesterday's fix actually work?" | Hour-by-hour billing CSV for the last 48h on the suspect key |

**Why this phase exists**: in the 2026-05-14 audit, three wrong hypothesis branches (Podio, BuyBox edge functions, n8n retry-config) cost ~45 minutes each before the user surfaced an n8n error-pane screenshot that named the actual bug. **One concrete dashboard fact beats five plausible models.**

### Phase 6 — Trace error to root cause
With the concrete error message in hand, trace upward through the calling code/SQL/workflow until you find the bug. Common patterns:

| Error class | Likely root cause |
|-------------|-------------------|
| `duplicate key value violates unique constraint X_pkey` | Column default uses string-truncation on a counter (lpad/rpad/substring on nextval) — see 📄 sql-defensive-defaults.md |
| `function rolled back, classification stayed NULL` | Secondary write inside plpgsql not wrapped in EXCEPTION block |
| `signed URL expired` / Wassenger 404 | Storage URL TTL shorter than the workflow's wall-clock latency between fetch and AI call |
| `rate_limit_exceeded` retried | Workflow has aggressive retry config (>3) with no exponential back-off |
| `429 too many requests` | Burst-spike from a parallel-execution pattern; needs concurrency cap |
| Silent NULL in persistence | Schedule trigger re-picks unclassified items every N minutes; idempotency check looks at wrong field |
| 5-second timeout on net.http_post | pg_cron firing edge function with default 5000ms; function actually runs longer and may double-fire next tick |
| No log entries for the function | Cron firing with timeout < function execution time; function may complete but log never written |

### Phase 7 — Apply minimal fix + verify AT THE BILLING-API LEVEL (CRITICAL v2 change)

1. **Fix** the root cause with the smallest possible change.
2. **Add defensive layer** so the same class of bug can't recur (EXCEPTION wrap, ON CONFLICT, ID generator change, retry-cap, etc.).
3. **For backfill jobs**: deploy MUST include a daily budget cap, a kill switch (active flag), and a system_alerts entry on first activation. Otherwise the fix is "deploy and forget" — back to square one.
4. **Verify AT TWO LEVELS — both required**:
   - **Database level**: query persistence target for new records with the correct shape AFTER the fix went live
   - **Billing/API level**: compare hour-by-hour API call rate from the billing CSV for the 24h BEFORE the fix versus the 24h AFTER — if the rate doesn't drop, **attribution was wrong**. Restart Phase 1.
5. **Encode** the lesson via /reflect so it lands in doctrine, hooks, or skill bodies before the next bug.

**The verification trap (added v2)**: a fix can move the database persistence rate (more rows saved) without moving the API call rate at all. That happens when the real burner is a DIFFERENT consumer sharing the same API key. The 2026-05-14 lpad fix improved database persistence by 6× but moved zero dollars at the OpenAI dashboard because the actual $80/day leak was a separate edge function (pod-ocr-backfill) firing on a 2-minute cron against a stale backlog. **Never declare a cost-spike victory on database evidence alone.** The billing dashboard is the only authoritative surface.

## Composes With

- 📄 `.claude/rules/sql-defensive-defaults.md` — when root cause is a Postgres column default or unguarded plpgsql write
- 📄 `.claude/rules/rpc-replacement-safety.md` — when fix requires CREATE OR REPLACE FUNCTION
- 📄 `~/.claude/projects/<project>/memory/feedback_no_backfilling_without_permission.md` — when Phase 1c classifies a consumer as BACKFILL
- 📄 `~/.claude/projects/<project>/memory/reference_openai_api_key_attribution.md` — when Phase 2 attribution is non-obvious
- 📄 `.claude/expertise/ai-generated-doc-verification.yaml` § skeleton_csv_detection — when user attaches a billing CSV that turns out to be empty
- 📁 `/supabase-postgres-best-practices` skill — Latent Timebomb Patterns section covers the lpad-truncation + unguarded-secondary-write classes
- 📄 `.claude/hookify.no-backfill-without-permission.local.md` — fires before any apply_migration / execute_sql / deploy_edge_function with backfill-shaped patterns

## Anti-patterns to Avoid

| Wrong | Why | Right |
|-------|-----|-------|
| Theorising past 2 hypotheses without a concrete observation | Each wrong branch costs ~15 min; the user often has dashboard access you don't | Ask for ONE specific fact (key name, error screenshot, secret prefix) |
| Trusting OpenAI project labels for cost attribution | Keys get labelled by who created them, not by what uses them | Always verify the actual plug-in point (n8n credential, Supabase secret, .env) |
| Applying "rotate the key" before diagnosis | Loses the audit trail; you lose 24h of billing data showing the pattern | Diagnose first, then rotate as part of the fix |
| Increasing retry count to "be safer" | Doubles the cost of every retry-loop bug | Cap retries at 2, add exponential back-off, fix the underlying error |
| Fixing only the most visible symptom | Bug class returns elsewhere | Apply BOTH the minimal fix AND the defensive layer that prevents the class |
| **Inventoring callers without inventoring schedulers** (Phase 1b skip) | A $0.02-per-call function fired 720× per day by a 2-min cron is a $14/day burner — invisible if you only inventoried the caller code | Always pair Phase 1a (callers) with Phase 1b (firers) — the multiplier is where the bill lives |
| **Trusting database persistence as proxy for API-call reduction** (Phase 7 short-circuit) | A fix can improve database write rate by 6× without moving API calls at all — if another consumer shares the same key | Verify at BOTH the database level AND the billing-dashboard hour-by-hour rate comparison |
| **Deploying a backfill job without daily cap + kill switch + alert** | Deploy-and-forget backfills accumulate silent cost for weeks before detection | All backfills require: daily budget cap, active-flag kill switch, system_alerts on first run, AND explicit user dollar-figure OK |

## Failure Precedents

### 2026-05-14 — Nirvana fleet `data_conflicts` cascade (the FIRST claimed fix)

- **Phase 1a inventory** revealed 11 OpenAI consumers across 3 repos (Nirvana edge functions, n8n workflows, BuyBox edge functions)
- **Phase 1b NOT performed in v1** — missed that pod-ocr-backfill cron fired every 2 minutes
- **Phase 1c NOT performed in v1** — missed the BACKFILL classification entirely
- **Phase 2 attribution** showed a key labelled "Nirvana Freight - AI Workbook" was the source
- **Phase 3 fingerprint** (1,407 input / 206 output) matched a fixed-prompt classifier
- **Phase 4 cross-reference** showed 508 saved classifications vs 3,104 API calls — 6:1 ratio, looked like a retry loop in the Visual AI Media Classifier
- **Phase 5 escalation** to user produced a screenshot of the n8n error pane → `duplicate key value violates unique constraint "data_conflicts_pkey"` → identified the lpad bug
- **Phase 7 fix in v1**: dropped lpad + wrapped INSERT in EXCEPTION block
- **Claimed savings**: $14.82/day. **Actual savings**: ~$1-2/day. **Attribution was wrong.**

### 2026-05-15 — The hour-by-hour CSV that revealed the real leak

- User reports cost still high day-after the lpad fix
- v1 Phase 7 verification ("database state looks good") was insufficient
- User shares hour-by-hour OpenAI usage CSV
- Rate was **flat at 130-150 calls/hour for 30 consecutive hours**, including the 12 hours after the lpad fix
- The lpad fix moved roughly zero dollars at the billing-API level
- Re-running Phase 1b discovered pod-ocr-backfill cron firing every 2 min on a 4,500-record stale POD backlog
- Real burner: ~$60-80/day for ~3-4 weeks before detection
- Total accumulated waste: ~R1,500+ ZAR

**The v2 lesson**: Phase 7 verification must include hour-by-hour billing-API rate comparison, not just database state. And Phase 1b (the cron-multiplier sub-step) must run for every consumer in Phase 1a.

## How to Invoke

Slash command: `/cost-spike-diagnostic`. Or invoke directly when you spot the trigger phrases listed in the frontmatter. The skill is self-contained — no prerequisites beyond Supabase read access + the API usage CSV (hourly granularity preferred for Phase 7).

<!-- AUDIT METADATA
source: self-authored (.claude/skills/cost-spike-diagnostic/SKILL.md v1.0)
audit_date: 2026-05-15
audit_grade_before: C (62.5/100)
audit_grade_after_v2: B+ (estimated; pending eval validation)
merge_actions: upgrade=2 absorb=1 supplement=2 add_evals=1
superior_patterns_absorbed: 3
v2_changes_summary: |
  - Phase 1 split into 1a/1b/1c (cron-multiplier blindspot + BACKFILL classification)
  - Phase 7 upgraded with two-level verification (DB + billing-API hourly rate)
  - 2 new anti-patterns from 2026-05-15 incident
  - 5 evals added (4 should_trigger=true, 1 should_trigger=false)
  - Frontmatter extended with version + classification + validated_on + v2_changes
-->
